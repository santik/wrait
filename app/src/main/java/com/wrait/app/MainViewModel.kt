package com.wrait.app

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.speech.TranscriptionService
import com.wrait.app.di.IoDispatcher
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.model.EntryStats
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.model.defaultSupportedLanguageCode
import com.wrait.app.domain.model.normalizeDetectedLanguageCode
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.repository.PreferencesRepository
import com.wrait.app.domain.usecase.CleanupTranscriptUseCase
import com.wrait.app.domain.usecase.RegisterDeviceUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import javax.inject.Inject
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Job
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@HiltViewModel
class MainViewModel @Inject constructor(
    private val preferencesRepository: PreferencesRepository,
    private val entryRepository: EntryRepository,
    private val transcriptionService: TranscriptionService,
    private val cleanupTranscriptUseCase: CleanupTranscriptUseCase,
    private val registerDeviceUseCase: RegisterDeviceUseCase,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : ViewModel() {

    val selectedLanguage: StateFlow<String> = preferencesRepository.selectedLanguage.stateIn(
        scope = viewModelScope,
        started = SharingStarted.Eagerly,
        initialValue = defaultSupportedLanguageCode(),
    )

    val hasEverRecorded: StateFlow<Boolean> = preferencesRepository.hasEverRecorded
        .stateIn(viewModelScope, SharingStarted.Eagerly, false)

    val privacyMode: StateFlow<PrivacyMode> = preferencesRepository.privacyMode
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), PrivacyMode.MODE_BEST)

    private val _showSettingsPanel = MutableStateFlow(false)
    val showSettingsPanel: StateFlow<Boolean> = _showSettingsPanel.asStateFlow()

    private val _userMessage = MutableSharedFlow<String>()
    val userMessage = _userMessage.asSharedFlow()

    private val recordingController = MainRecordingController(
        selectedLanguageState = selectedLanguage,
        entryRepository = entryRepository,
        preferencesRepository = preferencesRepository,
        transcriptionService = transcriptionService,
        cleanupTranscriptUseCase = cleanupTranscriptUseCase,
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
        try {
            registerDeviceUseCase()
        } catch (e: Exception) {
            Log.w(TAG, "Device registration skipped: ${e.javaClass.simpleName}: ${e.message}")
        }
        preferencesRepository.seedPrivacyModeOnce(
            default = if (BuildConfig.PRIVACY_MODE == PrivacyMode.MODE_OFFLINE.name) {
                PrivacyMode.MODE_OFFLINE
            } else {
                PrivacyMode.MODE_BEST
            },
        )
        entryRepository.deleteStaleDrafts()
        if (preferencesRepository.privacyMode.first() != PrivacyMode.MODE_OFFLINE) {
            retryPendingDrafts()
        }
    }

    // region — button handling

    fun onMainButtonTapped() {
        recordingController.onMainButtonTapped()
    }

    /** Resets to idle without starting a new recording session. */
    fun resetToIdle() {
        recordingController.resetToIdle()
    }

    fun setLanguage(code: String) {
        viewModelScope.launch {
            try {
                preferencesRepository.setLanguage(code)
                Log.d(TAG, "Selected language saved: $code")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save selected language: $code", e)
                _userMessage.emit("Couldn't save language settings")
            }
        }
    }

    fun onPermissionRevoked() {
        recordingController.onPermissionRevoked()
    }

    fun onSwipeDown() {
        if (recordingState.value.isActive) return
        _showSettingsPanel.value = true
    }

    fun onSettingsPanelDismiss() {
        _showSettingsPanel.value = false
    }

    fun onPrivacyModeToggle(enabled: Boolean) {
        viewModelScope.launch {
            preferencesRepository.savePrivacyMode(
                if (enabled) PrivacyMode.MODE_OFFLINE else PrivacyMode.MODE_BEST,
            )
        }
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
        when (val result = cleanupTranscriptUseCase(entry.rawTranscript, entry.language)) {
            is CleanupResult.Success -> {
                val cleaned = result.cleanedText
                val wordCount = cleaned.trim().split(Regex("\\s+")).count { it.isNotEmpty() }
                entryRepository.updateWithCleanedText(entry.id, cleaned, wordCount)
            }
            is CleanupResult.Failure -> Unit
        }
    }

    private suspend fun retryAudioDraft(entry: Entry) {
        val audioPath = entry.audioPath ?: return
        val transcription = transcriptionService.transcribeAudioDraft(
            audioPath = audioPath,
        )

        when (transcription) {
            is com.wrait.app.data.speech.TranscriptionResult.Success -> {
                val rawTranscript = transcription.transcript
                val rawWordCount = rawTranscript.trim().split(Regex("\\s+")).count { it.isNotEmpty() }
                val detectedLanguage = normalizeDetectedLanguageCode(transcription.detectedLanguage)
                val effectiveLanguage = detectedLanguage ?: entry.language

                if (transcription.detectedLanguage != null && detectedLanguage == null) {
                    Log.w(
                        TAG,
                        "Draft retry: ignoring invalid detected language '${transcription.detectedLanguage}' for entry ${entry.id}.",
                    )
                }

                if (effectiveLanguage != entry.language) {
                    Log.i(
                        TAG,
                        "Draft retry: updating entry ${entry.id} language from ${entry.language} to $effectiveLanguage.",
                    )
                    entryRepository.updateEntryLanguage(entry.id, effectiveLanguage)
                }

                when (val cleanup = cleanupTranscriptUseCase(rawTranscript, effectiveLanguage)) {
                    is CleanupResult.Success -> {
                        val cleaned = cleanup.cleanedText
                        val cleanedWordCount = cleaned.trim().split(Regex("\\s+")).count { it.isNotEmpty() }
                        entryRepository.finalizeDraftWithCleanedText(
                            id = entry.id,
                            rawTranscript = rawTranscript,
                            cleanedText = cleaned,
                            wordCount = cleanedWordCount,
                        )
                    }
                    is CleanupResult.Failure -> {
                        // Still valuable: convert audio-only draft into a text draft.
                        entryRepository.updateDraftTranscript(entry.id, rawTranscript, rawWordCount)
                    }
                }

                // Once we have text (cleaned or raw), the audio file is no longer needed.
                try {
                    File(audioPath).delete()
                } catch (_: Exception) {
                    // best-effort
                }
            }
            is com.wrait.app.data.speech.TranscriptionResult.Failure -> Unit
        }
    }

    private companion object {
        private const val TAG = "MainViewModel"
    }
}

sealed class RecordingState {
    data object Idle : RecordingState()
    data object Listening : RecordingState()
    data object Uploading : RecordingState()
    data object Processing : RecordingState()
    data class Saved(
        val entryId: Long,
        val detectedLanguage: String? = null,
    ) : RecordingState()
    data class Error(val error: com.wrait.app.data.speech.RecognizerError) : RecordingState()
    data class Deleted(val count: Int) : RecordingState()

    val isActive: Boolean
        get() = this is Listening || this is Uploading || this is Processing
}

data class EntrySummary(
    val id: Long,
    val transcript: String,
    val createdAt: Long,
)
