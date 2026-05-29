package com.wrait.app

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wrait.app.analytics.AnalyticsDraftType
import com.wrait.app.analytics.AnalyticsRetryFailureStage
import com.wrait.app.analytics.AnalyticsSavePath
import com.wrait.app.analytics.AnalyticsTracker
import com.wrait.app.analytics.trackSafely
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.api.RecordQuotaState
import com.wrait.app.data.api.RegistrationResult
import com.wrait.app.data.device.NetworkAvailability
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
import com.wrait.app.analytics.cleanupReasonToAnalyticsErrorType
import com.wrait.app.analytics.toAnalyticsErrorType
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
    private val networkAvailability: NetworkAvailability,
    private val cleanupTranscriptUseCase: CleanupTranscriptUseCase,
    private val registerDeviceUseCase: RegisterDeviceUseCase,
    private val analyticsTracker: AnalyticsTracker,
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
        .stateIn(
            viewModelScope,
            SharingStarted.WhileSubscribed(STATE_SUBSCRIPTION_TIMEOUT_MS),
            PrivacyMode.MODE_BEST,
        )

    private val _showSettingsPanel = MutableStateFlow(false)
    val showSettingsPanel: StateFlow<Boolean> = _showSettingsPanel.asStateFlow()

    private val _userMessage = MutableSharedFlow<String>()
    val userMessage = _userMessage.asSharedFlow()

    private val _recordQuota = MutableStateFlow<RecordQuotaState?>(null)
    val recordQuota: StateFlow<RecordQuotaState?> = _recordQuota.asStateFlow()

    private val recordingController = MainRecordingController(
        selectedLanguageState = selectedLanguage,
        entryRepository = entryRepository,
        preferencesRepository = preferencesRepository,
        transcriptionService = transcriptionService,
        networkAvailability = networkAvailability,
        cleanupTranscriptUseCase = cleanupTranscriptUseCase,
        analyticsTracker = analyticsTracker,
        ioDispatcher = ioDispatcher,
        scope = viewModelScope,
        onQuotaUpdated = ::updateQuota,
    )

    val recordingState: StateFlow<RecordingState> = recordingController.recordingState
    val recordingCountdown: StateFlow<RecordingCountdownState?> = recordingController.recordingCountdown

    // Incremented on each NoMatch / TooShort error so ButtonArea can fire a shake
    // even when two identical error states are emitted in succession.
    val shakeErrorKey: StateFlow<Int> = recordingController.shakeErrorKey

    // Share one upstream entries flow for all derived main-screen state while the UI is observing it.
    private val allEntries: StateFlow<List<Entry>> = entryRepository.getAllEntries()
        .stateIn(
            viewModelScope,
            SharingStarted.WhileSubscribed(STATE_SUBSCRIPTION_TIMEOUT_MS),
            emptyList(),
        )

    val entryStats: StateFlow<EntryStats> = allEntries
        .map { list -> computeStats(list) }
        .stateIn(
            viewModelScope,
            SharingStarted.WhileSubscribed(STATE_SUBSCRIPTION_TIMEOUT_MS),
            EntryStats.Empty,
        )

    internal val initJob: Job = viewModelScope.launch {
        try {
            val registrationResult = registerDeviceUseCase()
            if (registrationResult is RegistrationResult.Success) {
                updateQuota(registrationResult.quota)
            }
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
        val currentPrivacyMode = preferencesRepository.privacyMode.first()
        if (currentPrivacyMode != PrivacyMode.MODE_OFFLINE) {
            retryPendingDrafts()
        }
        trackAppOpened(currentPrivacyMode)
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

    fun onMicrophonePermissionRequested() {
        analyticsTracker.trackSafely(TAG, "microphone permission requested") {
            trackMicrophonePermissionRequested()
        }
    }

    fun onMicrophonePermissionResult(granted: Boolean, permanentlyDenied: Boolean) {
        if (granted) return

        analyticsTracker.trackSafely(
            TAG,
            if (permanentlyDenied) {
                "microphone permission permanently denied"
            } else {
                "microphone permission denied"
            },
        ) {
            if (permanentlyDenied) {
                trackMicrophonePermissionPermanentlyDenied()
            } else {
                trackMicrophonePermissionDenied()
            }
        }
    }

    fun onOpenSettings() {
        if (recordingState.value.isActive) return
        _showSettingsPanel.value = true
    }

    fun onSwipeDown() {
        onOpenSettings()
    }

    fun onSettingsPanelDismiss() {
        _showSettingsPanel.value = false
    }

    fun onPrivacyModeToggle(enabled: Boolean) {
        viewModelScope.launch {
            val from = preferencesRepository.privacyMode.first()
            val to = if (enabled) PrivacyMode.MODE_OFFLINE else PrivacyMode.MODE_BEST
            if (from == to) return@launch

            preferencesRepository.savePrivacyMode(to)
            analyticsTracker.trackSafely(TAG, "privacy mode toggled") {
                trackPrivacyModeToggled(from, to)
            }
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

    // Quota is an in-memory cache of the last valid backend value we received.
    // We only replace it when a newer valid quota arrives; missing or invalid
    // quota leaves the previous value intact. Switching to Offline hides quota
    // in the UI but does not clear it, and we intentionally do not expire it
    // locally based on resetAt.
    private fun updateQuota(quota: RecordQuotaState?) {
        if (quota != null) {
            _recordQuota.value = quota
        }
    }

    private suspend fun trackAppOpened(privacyMode: PrivacyMode) {
        val entryCount = try {
            entryRepository.getAllEntries().first().size
        } catch (e: Exception) {
            Log.w(TAG, "Failed to compute app-opened entry count", e)
            0
        }

        analyticsTracker.trackSafely(TAG, "app opened") {
            trackAppOpened(privacyMode, entryCount)
        }
    }

    private suspend fun retryTextDraft(entry: Entry) {
        val privacyMode = preferencesRepository.privacyMode.first()
        analyticsTracker.trackSafely(TAG, "draft retry started (text)") {
            trackDraftRetryStarted(AnalyticsDraftType.Text)
        }
        when (val result = cleanupTranscriptUseCase(entry.rawTranscript, entry.language)) {
            is CleanupResult.Success -> {
                updateQuota(result.quota)
                val cleaned = result.cleanedText
                val wordCount = cleaned.trim().split(Regex("\\s+")).count { it.isNotEmpty() }
                entryRepository.updateWithCleanedText(entry.id, cleaned, wordCount)
                analyticsTracker.trackSafely(TAG, "cleanup succeeded (retry text draft)") {
                    trackCleanupSucceeded(privacyMode, AnalyticsSavePath.Retry)
                    trackEntrySaved(privacyMode, AnalyticsSavePath.Retry)
                    trackDraftRetrySucceeded(AnalyticsDraftType.Text)
                }
            }
            is CleanupResult.Failure -> {
                updateQuota(result.quota)
                analyticsTracker.trackSafely(TAG, "cleanup failed (retry text draft)") {
                    trackCleanupFailed(privacyMode, AnalyticsSavePath.Retry, result.reason)
                    trackDraftRetryFailed(
                        draftType = AnalyticsDraftType.Text,
                        failureStage = AnalyticsRetryFailureStage.Cleanup,
                        errorType = cleanupReasonToAnalyticsErrorType(result.reason),
                    )
                }
            }
        }
    }

    private suspend fun retryAudioDraft(entry: Entry) {
        val audioPath = entry.audioPath ?: return
        val privacyMode = preferencesRepository.privacyMode.first()
        analyticsTracker.trackSafely(TAG, "draft retry started (audio)") {
            trackDraftRetryStarted(AnalyticsDraftType.Audio)
        }
        val transcription = transcriptionService.transcribeAudioDraft(
            audioPath = audioPath,
        )

        when (transcription) {
            is com.wrait.app.data.speech.TranscriptionResult.Success -> {
                updateQuota(transcription.quota)
                analyticsTracker.trackSafely(TAG, "transcription succeeded (retry audio draft)") {
                    trackTranscriptionSucceeded(
                        privacyMode = privacyMode,
                        detectedLanguagePresent = transcription.detectedLanguage != null,
                        savePath = AnalyticsSavePath.Retry,
                    )
                }

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
                        updateQuota(cleanup.quota)
                        val cleaned = cleanup.cleanedText
                        val cleanedWordCount = cleaned.trim().split(Regex("\\s+")).count { it.isNotEmpty() }
                        entryRepository.finalizeDraftWithCleanedText(
                            id = entry.id,
                            rawTranscript = rawTranscript,
                            cleanedText = cleaned,
                            wordCount = cleanedWordCount,
                        )
                        analyticsTracker.trackSafely(TAG, "cleanup succeeded (retry audio draft)") {
                            trackCleanupSucceeded(privacyMode, AnalyticsSavePath.Retry)
                            trackEntrySaved(privacyMode, AnalyticsSavePath.Retry)
                            trackDraftRetrySucceeded(AnalyticsDraftType.Audio)
                        }
                    }
                    is CleanupResult.Failure -> {
                        updateQuota(cleanup.quota)
                        // Still valuable: convert audio-only draft into a text draft.
                        entryRepository.updateDraftTranscript(entry.id, rawTranscript, rawWordCount)
                        analyticsTracker.trackSafely(TAG, "cleanup failed (retry audio draft)") {
                            trackCleanupFailed(privacyMode, AnalyticsSavePath.Retry, cleanup.reason)
                            trackDraftRetryFailed(
                                draftType = AnalyticsDraftType.Audio,
                                failureStage = AnalyticsRetryFailureStage.Cleanup,
                                errorType = cleanupReasonToAnalyticsErrorType(cleanup.reason),
                            )
                        }
                    }
                }

                // Once we have text (cleaned or raw), the audio file is no longer needed.
                try {
                    File(audioPath).delete()
                } catch (_: Exception) {
                    // best-effort
                }
            }
            is com.wrait.app.data.speech.TranscriptionResult.Failure -> {
                updateQuota(transcription.quota)
                analyticsTracker.trackSafely(TAG, "transcription failed (retry audio draft)") {
                    trackDraftRetryFailed(
                        draftType = AnalyticsDraftType.Audio,
                        failureStage = AnalyticsRetryFailureStage.Transcription,
                        errorType = transcription.reason.toAnalyticsErrorType(),
                    )
                }
            }
        }
    }

    private companion object {
        private const val TAG = "MainViewModel"
        private const val STATE_SUBSCRIPTION_TIMEOUT_MS = 5_000L
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
