package com.wrait.app

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wrait.app.data.api.OpenAiApiService
import com.wrait.app.di.IoDispatcher
import com.wrait.app.data.speech.TranscriptionService
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.model.EntryStats
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.repository.PreferencesRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Job
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale
import javax.inject.Inject
import java.io.File

@HiltViewModel
class MainViewModel @Inject constructor(
    private val preferencesRepository: PreferencesRepository,
    private val entryRepository: EntryRepository,
    private val transcriptionService: TranscriptionService,
    private val openAiApiService: OpenAiApiService,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher
) : ViewModel() {

    private val languageState = preferencesRepository.selectedLanguage.stateIn(
        scope = viewModelScope,
        started = SharingStarted.Eagerly,
        initialValue = Locale.getDefault().toLanguageTag()
    )

    val selectedLanguage: StateFlow<String> = languageState

    val hasEverRecorded: StateFlow<Boolean> = preferencesRepository.hasEverRecorded
        .stateIn(viewModelScope, SharingStarted.Eagerly, false)

    private val recordingController = MainRecordingController(
        languageState = languageState,
        entryRepository = entryRepository,
        preferencesRepository = preferencesRepository,
        transcriptionService = transcriptionService,
        openAiApiService = openAiApiService,
        ioDispatcher = ioDispatcher,
        scope = viewModelScope,
    )

    val recordingState: StateFlow<RecordingState> = recordingController.recordingState

    // Incremented on each NoMatch / TooShort error so ButtonArea can fire a shake
    // even when two identical error states are emitted in succession.
    val shakeErrorKey: StateFlow<Int> = recordingController.shakeErrorKey

    val entries: StateFlow<List<EntrySummary>> = entryRepository.getAllEntries()
        .map { list ->
            list.map { EntrySummary(it.id, it.rawTranscript, it.createdAt) }
        }
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    val entryStats: StateFlow<EntryStats> = entryRepository.getAllEntries()
        .map { list -> computeStats(list) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), EntryStats.Empty)

    internal val initJob: Job = viewModelScope.launch {
        entryRepository.deleteStaleDrafts()
        if (BuildConfig.PRIVACY_MODE != "MODE_PRIVATE") {
            retryPendingDrafts()
        }
    }

    // region — button handling

    fun onMainButtonTapped() {
        recordingController.onMainButtonTapped()
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
        recordingController.onPermissionRevoked()
    }

    fun onEntriesDeleted(count: Int) {
        recordingController.onEntriesDeleted(count)
    }

    // endregion

    // region — stats computation

    private fun computeStats(entries: List<Entry>): EntryStats {
        if (entries.isEmpty()) return EntryStats.Empty

        val zone = ZoneId.systemDefault()

        val entryDates: Set<LocalDate> = entries.mapTo(HashSet()) { entry ->
            Instant.ofEpochMilli(entry.createdAt).atZone(zone).toLocalDate()
        }

        return EntryStats(
            entryCount = entries.size,
            activeDays = entryDates.size,
        )
    }

    // endregion

    private companion object {
        private const val TAG = "MainViewModel"
    }

    private suspend fun retryPendingDrafts() = withContext(ioDispatcher) {
        val drafts = try {
            entryRepository.getPendingDrafts()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load pending drafts for retry: ${e.message}")
            return@withContext
        }

        if (drafts.isEmpty()) return@withContext

        drafts.sortedByDescending { it.createdAt }.forEach { entry ->
            currentCoroutineContext().ensureActive()
            try {
                when {
                    entry.audioPath != null -> retryAudioDraft(entry)
                    entry.rawTranscript.isNotBlank() -> retryTextDraft(entry)
                    else -> Unit
                }
            } catch (e: Exception) {
                Log.w(TAG, "Draft retry failed for entry ${entry.id}: ${e.message}")
            }
        }
    }

    private suspend fun retryTextDraft(entry: Entry) {
        when (val result = openAiApiService.cleanupTranscript(entry.rawTranscript)) {
            is com.wrait.app.data.api.CleanupResult.Success -> {
                val cleaned = result.cleanedText
                val wordCount = cleaned.trim().split(Regex("\\s+")).count { it.isNotEmpty() }
                entryRepository.updateWithCleanedText(entry.id, cleaned, wordCount)
            }
            is com.wrait.app.data.api.CleanupResult.Failure -> Unit
        }
    }

    private suspend fun retryAudioDraft(entry: Entry) {
        val audioPath = entry.audioPath ?: return
        val transcription = transcriptionService.transcribeAudioDraft(
            audioPath = audioPath,
            languageCode = entry.language,
        )

        when (transcription) {
            is com.wrait.app.data.speech.TranscriptionResult.Success -> {
                val rawTranscript = transcription.transcript
                val rawWordCount = rawTranscript.trim().split(Regex("\\s+")).count { it.isNotEmpty() }

                when (val cleanup = openAiApiService.cleanupTranscript(rawTranscript)) {
                    is com.wrait.app.data.api.CleanupResult.Success -> {
                        val cleaned = cleanup.cleanedText
                        val cleanedWordCount = cleaned.trim().split(Regex("\\s+")).count { it.isNotEmpty() }
                        entryRepository.finalizeDraftWithCleanedText(
                            id = entry.id,
                            rawTranscript = rawTranscript,
                            cleanedText = cleaned,
                            wordCount = cleanedWordCount,
                        )
                    }
                    is com.wrait.app.data.api.CleanupResult.Failure -> {
                        // Still valuable: convert audio-only draft into a text draft.
                        entryRepository.updateDraftTranscript(entry.id, rawTranscript, rawWordCount)
                    }
                }

                // Once we have text (cleaned or raw), the audio file is no longer needed.
                try { File(audioPath).delete() } catch (_: Exception) { /* best-effort */ }
            }
            is com.wrait.app.data.speech.TranscriptionResult.Failure -> Unit
        }
    }
}

sealed class RecordingState {
    data object Idle       : RecordingState()
    data object Listening  : RecordingState()
    data object Uploading  : RecordingState()
    data object Processing : RecordingState()
    data class Saved(val entryId: Long) : RecordingState()
    data class Error(val error: com.wrait.app.data.speech.RecognizerError) : RecordingState()
    data class Deleted(val count: Int) : RecordingState()
}

data class EntrySummary(
    val id: Long,
    val transcript: String,
    val createdAt: Long
)
