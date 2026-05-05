package com.wrait.app

import android.util.Log
import com.wrait.app.data.device.NetworkAvailability
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.data.speech.TranscriptionFailureReason
import com.wrait.app.data.speech.TranscriptionResult
import com.wrait.app.data.speech.TranscriptionService
import com.wrait.app.data.speech.TranscriptionStatus
import com.wrait.app.di.IoDispatcher
import com.wrait.app.domain.model.normalizeDetectedLanguageCode
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.repository.PreferencesRepository
import com.wrait.app.domain.usecase.CleanupTranscriptUseCase
import javax.inject.Inject
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainRecordingController @Inject constructor(
    private val selectedLanguageState: StateFlow<String>,
    private val entryRepository: EntryRepository,
    private val preferencesRepository: PreferencesRepository,
    private val transcriptionService: TranscriptionService,
    private val networkAvailability: NetworkAvailability,
    private val cleanupTranscriptUseCase: CleanupTranscriptUseCase,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
    private val scope: CoroutineScope,
) {
    private val _recordingState = MutableStateFlow<RecordingState>(RecordingState.Idle)
    val recordingState: StateFlow<RecordingState> = _recordingState.asStateFlow()

    private val _shakeErrorKey = MutableStateFlow(0)
    val shakeErrorKey: StateFlow<Int> = _shakeErrorKey.asStateFlow()

    private var listenJob: Job? = null
    private var resetJob: Job? = null
    private var listeningStartedAt = 0L

    fun onMainButtonTapped() {
        val current = recordingState.value
        when (current) {
            RecordingState.Idle -> startListening()
            RecordingState.Listening -> stopListening()
            RecordingState.Uploading,
            RecordingState.Processing -> Unit
            is RecordingState.Saved -> startListening()
            is RecordingState.Deleted -> startListening()
            is RecordingState.Error -> {
                if (current.error == RecognizerError.InsufficientPermissions) {
                    _recordingState.value = RecordingState.Idle
                } else {
                    startListening()
                }
            }
        }
    }

    /** Resets the state to [RecordingState.Idle] without starting a new recording. */
    fun resetToIdle() {
        _recordingState.value = RecordingState.Idle
    }

    fun onPermissionRevoked() {
        stopListening(forceIdle = true)
    }

    fun onEntriesDeleted(count: Int) {
        if (count <= 0) return
        scope.launch {
            _recordingState.value = RecordingState.Deleted(count)
            delay(3_000)
            if (_recordingState.value is RecordingState.Deleted) {
                _recordingState.value = RecordingState.Idle
            }
        }
    }

    private fun startListening() {
        resetJob?.cancel()
        listenJob?.cancel()

        scope.launch {
            when (preferencesRepository.privacyMode.first()) {
                PrivacyMode.MODE_BEST -> {
                    if (!networkAvailability.canAttemptCloudUpload()) {
                        emitError(RecognizerError.ConnectionRequired)
                        return@launch
                    }
                }

                PrivacyMode.MODE_OFFLINE -> {
                    if (!transcriptionService.isOfflineModelAvailable()) {
                        emitError(RecognizerError.NotAvailable(selectedLanguageState.value))
                        return@launch
                    }
                }
            }

            listeningStartedAt = System.currentTimeMillis()
            _recordingState.value = RecordingState.Listening
            listenJob = scope.launch {
                val selectedLanguage = selectedLanguageState.value
                val result = transcriptionService.transcribe(selectedLanguage) { status ->
                    when (status) {
                        TranscriptionStatus.RecordingEnded ->
                            _recordingState.value = RecordingState.Processing
                        TranscriptionStatus.Uploading ->
                            _recordingState.value = RecordingState.Uploading
                    }
                }
                _recordingState.value = RecordingState.Processing
                when (result) {
                    is TranscriptionResult.Success ->
                        saveTranscript(result.transcript, result.detectedLanguage)
                    is TranscriptionResult.Failure -> {
                        if (result.audioDraftPath != null) {
                            withContext(ioDispatcher) {
                                entryRepository.saveAudioDraft(
                                    audioPath = result.audioDraftPath,
                                    language = selectedLanguage,
                                )
                            }
                        }
                        emitError(result.reason.toRecognizerError(selectedLanguage))
                    }
                }
            }
        }
    }

    private fun stopListening(forceIdle: Boolean = false) {
        if (!forceIdle) {
            val elapsed = System.currentTimeMillis() - listeningStartedAt
            if (elapsed < MIN_RECORDING_MS) {
                transcriptionService.stopRecording()
                listenJob?.cancel()
                scope.launch { emitError(RecognizerError.TooShort) }
                return
            }
        }
        transcriptionService.stopRecording()
        if (forceIdle) {
            listenJob?.cancel()
            _recordingState.value = RecordingState.Idle
        }
    }

    private suspend fun saveTranscript(text: String, detectedLanguage: String? = null) {
        val selectedLanguage = selectedLanguageState.value
        val mode = preferencesRepository.privacyMode.first()
        val normalizedDetectedLanguage = normalizeDetectedLanguageCode(detectedLanguage)
        val effectiveLanguage = if (mode == PrivacyMode.MODE_OFFLINE) {
            selectedLanguage
        } else {
            normalizedDetectedLanguage ?: selectedLanguage
        }

        if (detectedLanguage != null && normalizedDetectedLanguage == null) {
            Log.w(TAG, "Ignoring invalid detected language during save: $detectedLanguage")
        }

        if (text.isBlank()) {
            _shakeErrorKey.update { it + 1 }
            _recordingState.value = RecordingState.Error(RecognizerError.TooShort)
            delayAndReset()
            return
        }
        val safeText = if (text.length > MAX_TRANSCRIPT_LENGTH) {
            Log.w(
                TAG,
                "Truncating transcript from ${text.length} to $MAX_TRANSCRIPT_LENGTH chars before persistence",
            )
            text.take(MAX_TRANSCRIPT_LENGTH)
        } else {
            text
        }

        if (mode == PrivacyMode.MODE_OFFLINE) {
            val entryId = withContext(ioDispatcher) {
                entryRepository.saveEntry(safeText, selectedLanguage)
            }
            Log.d(TAG, "MODE_OFFLINE: entry saved, id=$entryId")
            withContext(ioDispatcher) {
                try {
                    preferencesRepository.setHasEverRecorded(true)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to persist hasEverRecorded flag", e)
                }
            }
            _recordingState.value = RecordingState.Saved(entryId)
            delayAndReset()
            return
        }

        val entryId = withContext(ioDispatcher) {
            entryRepository.saveDraft(safeText, effectiveLanguage)
        }
        Log.d(TAG, "Draft saved, id=$entryId")

        withContext(ioDispatcher) {
            try {
                preferencesRepository.setHasEverRecorded(true)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to persist hasEverRecorded flag", e)
            }
        }

        when (val result = cleanupTranscriptUseCase(safeText, effectiveLanguage)) {
            is CleanupResult.Success -> {
                val wordCount = result.cleanedText.trim()
                    .split(Regex("\\s+")).count { it.isNotEmpty() }
                withContext(ioDispatcher) {
                    entryRepository.updateWithCleanedText(entryId, result.cleanedText, wordCount)
                }
                Log.d(TAG, "Entry $entryId cleaned (${wordCount}w)")
                _recordingState.value = RecordingState.Saved(
                    entryId,
                    detectedLanguage = normalizedDetectedLanguage,
                )
            }
            is CleanupResult.Failure -> {
                val isNetworkFailure = result.reason == "network error" ||
                    result.reason == "timeout"
                Log.w(TAG, "Cleanup failed for entry $entryId: ${result.reason} (draft kept)")
                val error = if (isNetworkFailure) {
                    RecognizerError.NoInternet
                } else {
                    RecognizerError.ApiFailed
                }
                _recordingState.value = RecordingState.Error(error)
            }
        }

        delayAndReset()
    }

    private fun emitError(error: RecognizerError) {
        if (error == RecognizerError.NoMatch || error == RecognizerError.TooShort) {
            _shakeErrorKey.update { it + 1 }
        }
        _recordingState.value = RecordingState.Error(error)
        delayAndReset()
    }

    private fun delayAndReset() {
        resetJob?.cancel()
        resetJob = scope.launch {
            delay(AUTO_CLEAR_DELAY_MS)
            val current = _recordingState.value
            if (!current.isActive) {
                _recordingState.value = RecordingState.Idle
            }
        }
    }

    private companion object {
        private const val TAG = "MainRecordingController"
        // Caps what we persist locally for a single transcript. Cleanup applies its own
        // smaller request-size limit before calling the backend.
        private const val MAX_TRANSCRIPT_LENGTH = 10_000
        private const val MIN_RECORDING_MS = 5_000L
        private const val AUTO_CLEAR_DELAY_MS = 3_000L
    }
}

private fun TranscriptionFailureReason.toRecognizerError(
    language: String = "",
): RecognizerError = when (this) {
    TranscriptionFailureReason.TooShort -> RecognizerError.TooShort
    TranscriptionFailureReason.NothingCaught -> RecognizerError.NoMatch
    TranscriptionFailureReason.MicBlocked -> RecognizerError.InsufficientPermissions
    TranscriptionFailureReason.NetworkError -> RecognizerError.NoInternet
    TranscriptionFailureReason.ModelNotAvailable -> RecognizerError.NotAvailable(language)
    TranscriptionFailureReason.BackendUnavailable -> RecognizerError.BackendUnavailable
    TranscriptionFailureReason.ProxyAuthFailed -> RecognizerError.ProxyAuthFailed
    TranscriptionFailureReason.ApiError -> RecognizerError.ApiFailed
}
