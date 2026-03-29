package com.wrait.app

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.api.OpenAiApiService
import com.wrait.app.di.IoDispatcher
import com.wrait.app.data.speech.RecognitionResult
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.data.speech.SpeechRecognizerManager
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.model.EntryStats
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.repository.PreferencesRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale
import javax.inject.Inject

@HiltViewModel
class MainViewModel @Inject constructor(
    private val preferencesRepository: PreferencesRepository,
    private val entryRepository: EntryRepository,
    private val speechRecognizerManager: SpeechRecognizerManager,
    private val openAiApiService: OpenAiApiService,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher
) : ViewModel() {

    private val languageState = preferencesRepository.selectedLanguage.stateIn(
        scope = viewModelScope,
        started = SharingStarted.Eagerly,
        initialValue = Locale.getDefault().toLanguageTag()
    )

    val selectedLanguage: StateFlow<String> = languageState

    private val _recordingState = MutableStateFlow<RecordingState>(RecordingState.Idle)
    val recordingState: StateFlow<RecordingState> = _recordingState.asStateFlow()

    // Incremented on each NoMatch / TooShort error so ButtonArea can fire a shake
    // even when two identical error states are emitted in succession.
    private val _shakeErrorKey = MutableStateFlow(0)
    val shakeErrorKey: StateFlow<Int> = _shakeErrorKey.asStateFlow()

    val entries: StateFlow<List<EntrySummary>> = entryRepository.getAllEntries()
        .map { list ->
            list.map { EntrySummary(it.id, it.rawTranscript, it.createdAt) }
        }
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    val entryStats: StateFlow<EntryStats> = entryRepository.getAllEntries()
        .map { list -> computeStats(list) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), EntryStats.Empty)

    private var listenJob: Job? = null

    internal val initJob: Job = viewModelScope.launch {
        entryRepository.deleteStaleDrafts()
        retryPendingDrafts()
    }

    // region — button handling

    fun onMainButtonTapped() {
        val current = recordingState.value
        when (current) {
            RecordingState.Idle        -> startListening()
            RecordingState.Listening   -> stopListening()
            RecordingState.Processing  -> Unit
            is RecordingState.Saved    -> _recordingState.value = RecordingState.Idle
            is RecordingState.Deleted  -> _recordingState.value = RecordingState.Idle
            is RecordingState.Error    -> {
                // TooShort / NoMatch are transient feedback states — tapping should
                // restart recording immediately rather than requiring a second tap.
                // startListening() cancels the stuck listenJob (self-cancelled delay)
                // and begins a fresh session.
                if (current.error == RecognizerError.TooShort ||
                    current.error == RecognizerError.NoMatch) {
                    startListening()
                } else {
                    _recordingState.value = RecordingState.Idle
                }
            }
        }
    }

    fun saveLanguage(code: String) {
        viewModelScope.launch {
            try {
                preferencesRepository.setLanguage(code)
                Log.d(TAG, "Language saved: $code")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save language: $code", e)
            }
        }
    }

    fun onPermissionRevoked() {
        stopListening(forceIdle = true)
    }

    fun onEntriesDeleted(count: Int) {
        if (count <= 0) return
        viewModelScope.launch {
            _recordingState.value = RecordingState.Deleted(count)
            delay(3_000)
            if (_recordingState.value is RecordingState.Deleted) {
                _recordingState.value = RecordingState.Idle
            }
        }
    }

    // endregion

    // region — recording pipeline

    private fun startListening() {
        listenJob?.cancel()
        _recordingState.value = RecordingState.Listening
        listenJob = viewModelScope.launch {
            val language = languageState.value
            speechRecognizerManager.listen(language).collect { result ->
                when (result) {
                    RecognitionResult.ListeningEnded -> {
                        if (_recordingState.value == RecordingState.Listening) {
                            _recordingState.value = RecordingState.Processing
                        }
                    }
                    RecognitionResult.Restarted -> Unit
                    is RecognitionResult.Final  -> saveTranscript(result.text)
                    is RecognitionResult.Error  -> emitError(result.error)
                    is RecognitionResult.Partial -> Unit
                }
            }
        }
    }

    private fun stopListening(forceIdle: Boolean = false) {
        speechRecognizerManager.stopListening()
        if (forceIdle) {
            listenJob?.cancel()
            _recordingState.value = RecordingState.Idle
        } else {
            _recordingState.value = RecordingState.Processing
        }
    }

    /**
     * Full pipeline:
     * 1. Validate input — blank or overlong text is rejected before touching the DB.
     * 2. Save raw transcript as draft (on IO) — user's words are safe before any network call.
     * 3. Call OpenAI cleanup.
     * 4a. Success → update entry with cleaned text → Saved(entryId).
     * 4b. Failure → leave draft in DB → Error(NoInternet | ApiFailed).
     */
    private suspend fun saveTranscript(text: String) {
        val language = languageState.value

        // Step 1 — input guard (should not normally be reached; belt-and-braces)
        if (text.isBlank()) {
            _shakeErrorKey.update { it + 1 }
            _recordingState.value = RecordingState.Error(RecognizerError.TooShort)
            delayAndReset()
            return
        }
        if (text.length > MAX_TRANSCRIPT_LENGTH) {
            Log.w(TAG, "Transcript exceeds max length (${text.length} chars), truncating")
        }

        // Step 2 — draft save (must complete before cleanup call begins)
        val entryId = withContext(ioDispatcher) {
            entryRepository.saveDraft(text, language)
        }
        Log.d(TAG, "Draft saved, id=$entryId")

        // Step 3 — cleanup
        when (val result = openAiApiService.cleanupTranscript(text)) {
            is CleanupResult.Success -> {
                val wordCount = result.cleanedText.trim()
                    .split(Regex("\\s+")).count { it.isNotEmpty() }
                withContext(ioDispatcher) {
                    entryRepository.updateWithCleanedText(entryId, result.cleanedText, wordCount)
                }
                Log.d(TAG, "Entry $entryId cleaned (${wordCount}w)")
                _recordingState.value = RecordingState.Saved(entryId)
            }
            is CleanupResult.Failure -> {
                val isNetworkFailure = result.reason == "network error"
                                    || result.reason == "timeout"
                Log.w(TAG, "Cleanup failed for entry $entryId: ${result.reason} (draft kept)")
                val error = if (isNetworkFailure) RecognizerError.NoInternet
                            else RecognizerError.ApiFailed
                _recordingState.value = RecordingState.Error(error)
            }
        }

        delayAndReset()
    }

    private suspend fun emitError(error: RecognizerError) {
        if (error == RecognizerError.NoMatch || error == RecognizerError.TooShort) {
            _shakeErrorKey.update { it + 1 }
        }
        _recordingState.value = RecordingState.Error(error)
        delayAndReset()
    }

    private suspend fun delayAndReset() {
        listenJob?.cancel()
        delay(1_500)
        _recordingState.value = RecordingState.Idle
    }

    // endregion

    // region — draft retry on init

    private suspend fun retryPendingDrafts() {
        val drafts = entryRepository.getPendingDrafts()
        if (drafts.isEmpty()) return
        Log.d(TAG, "Retrying ${drafts.size} pending draft(s)")
        drafts.forEach { entry ->
            // Abort the entire retry loop if the ViewModel has been destroyed
            currentCoroutineContext().ensureActive()
            try {
                when (val result = openAiApiService.cleanupTranscript(entry.rawTranscript)) {
                    is CleanupResult.Success -> {
                        val wordCount = result.cleanedText.trim()
                            .split(Regex("\\s+")).count { it.isNotEmpty() }
                        withContext(ioDispatcher) {
                            entryRepository.updateWithCleanedText(entry.id, result.cleanedText, wordCount)
                        }
                        Log.d(TAG, "Draft ${entry.id} upgraded to clean entry")
                    }
                    is CleanupResult.Failure -> {
                        // Leave as draft — S-017 handles surfacing this to the user via messages panel
                        Log.w(TAG, "Draft ${entry.id} retry failed: ${result.reason}")
                    }
                }
            } catch (e: Exception) {
                // One draft failing must not abort the rest of the retry loop
                Log.e(TAG, "Unexpected error retrying draft ${entry.id}", e)
            }
        }
    }

    // endregion

    // region — stats computation

    private fun computeStats(entries: List<Entry>): EntryStats {
        if (entries.isEmpty()) return EntryStats.Empty

        val zone   = ZoneId.systemDefault()
        val today  = LocalDate.now(zone)
        val monday = today.with(DayOfWeek.MONDAY)

        // Build a Set once — O(n) — so the 7 streak lookups are O(1) each instead of O(n) each
        val entryDates: Set<LocalDate> = entries.mapTo(HashSet()) { entry ->
            Instant.ofEpochMilli(entry.createdAt).atZone(zone).toLocalDate()
        }

        val streakDays = (0..6).map { offset ->
            monday.plusDays(offset.toLong()) in entryDates
        }

        return EntryStats(
            entryCount = entries.size,
            activeDays = entryDates.size,
            streakDays = streakDays
        )
    }

    // endregion

    private companion object {
        private const val TAG = "MainViewModel"
        private const val MAX_TRANSCRIPT_LENGTH = 10_000
    }
}

sealed class RecordingState {
    data object Idle       : RecordingState()
    data object Listening  : RecordingState()
    data object Processing : RecordingState()
    data class Saved(val entryId: Long) : RecordingState()
    data class Error(val error: RecognizerError) : RecordingState()
    data class Deleted(val count: Int) : RecordingState()
}

data class EntrySummary(
    val id: Long,
    val transcript: String,
    val createdAt: Long
)
