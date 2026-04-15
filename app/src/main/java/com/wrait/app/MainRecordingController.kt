package com.wrait.app

import android.util.Log
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.api.OpenAiApiService
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.data.speech.TranscriptionFailureReason
import com.wrait.app.data.speech.TranscriptionResult
import com.wrait.app.data.speech.TranscriptionService
import com.wrait.app.data.speech.TranscriptionStatus
import com.wrait.app.di.IoDispatcher
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.repository.PreferencesRepository
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
import javax.inject.Inject

class MainRecordingController @Inject constructor(
    private val languageState: StateFlow<String>,
    private val entryRepository: EntryRepository,
    private val preferencesRepository: PreferencesRepository,
    private val transcriptionService: TranscriptionService,
    private val openAiApiService: OpenAiApiService,
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
            RecordingState.Idle        -> startListening()
            RecordingState.Listening   -> stopListening()
            RecordingState.Uploading,
            RecordingState.Processing  -> Unit
//            is RecordingState.Saved    -> _recordingState.value = RecordingState.Idle
            is RecordingState.Saved    -> startListening()
            is RecordingState.Deleted  -> startListening()
            is RecordingState.Error    -> {
                // Any non-permission error should immediately restart recording.
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

        // Pre-flight: in offline mode, verify that an on-device speech model
        // is available before the recognizer is created.
        scope.launch {
            val isOffline =
                preferencesRepository.privacyMode.first() == PrivacyMode.MODE_OFFLINE
            if (isOffline && !transcriptionService.isOfflineModelAvailable()) {
                emitError(RecognizerError.NotAvailable)
                return@launch
            }

            listeningStartedAt = System.currentTimeMillis()
            _recordingState.value = RecordingState.Listening
            listenJob = scope.launch {
                val language = languageState.value
                val result = transcriptionService.transcribe(language) { status ->
                    when (status) {
                        TranscriptionStatus.RecordingEnded ->
                            _recordingState.value = RecordingState.Processing
                        TranscriptionStatus.Uploading ->
                            _recordingState.value = RecordingState.Uploading
                    }
                }
                // Ensure Processing before cleanup (no-op for Android which set it via callback)
                _recordingState.value = RecordingState.Processing
                when (result) {
                    is TranscriptionResult.Success ->
                        saveTranscript(result.transcript, result.detectedLanguage)
                    is TranscriptionResult.Failure -> {
                        if (result.audioDraftPath != null) {
                            withContext(ioDispatcher) {
                                entryRepository.saveAudioDraft(
                                    audioPath = result.audioDraftPath,
                                    language = language,
                                )
                            }
                        }
                        emitError(result.reason.toRecognizerError())
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
        // Otherwise the status update comes via the onStatus callback inside transcribe()
    }

    /**
     * Full pipeline:
     * 1. Validate input — blank or overlong text is rejected before touching the DB.
     * 2. Save raw transcript as draft (on IO) — user's words are safe before any network call.
     * 3. Call OpenAI cleanup.
     * 4a. Success → update entry with cleaned text → Saved(entryId).
     * 4b. Failure → leave draft in DB → Error(NoInternet | ApiFailed).
     *
     * [detectedLanguage] is non-null when the backend detected a different language than selected.
     * The entry is tagged with the detected language; the selector preference is unchanged.
     */
    private suspend fun saveTranscript(text: String, detectedLanguage: String? = null) {
        val selectedLanguage = languageState.value
        val mismatch = isLanguageMismatch(detectedLanguage, selectedLanguage)
        // Use detected language only when there is a genuine mismatch; otherwise keep the user's selection.
        val language = if (mismatch) detectedLanguage!! else selectedLanguage

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

        // MODE_OFFLINE: save final entry immediately, skip cleanup
        val mode = preferencesRepository.privacyMode.first()
        if (mode == PrivacyMode.MODE_OFFLINE) {
            val entryId = withContext(ioDispatcher) {
                entryRepository.saveEntry(text, language)
            }
            Log.d(TAG, "MODE_OFFLINE: entry saved, id=$entryId")
            withContext(ioDispatcher) {
                try {
                    preferencesRepository.setHasEverRecorded(true)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to persist hasEverRecorded flag", e)
                }
            }
            _recordingState.value = RecordingState.Saved(
                entryId,
                detectedLanguage = if (mismatch) detectedLanguage else null,
            )
            delayAndReset()
            return
        }

        // Step 2 — draft save (must complete before cleanup call begins)
        val entryId = withContext(ioDispatcher) {
            entryRepository.saveDraft(text, language)
        }
        Log.d(TAG, "Draft saved, id=$entryId")

        // Trip the "has ever recorded" flag — fires even if API cleanup later fails.
        withContext(ioDispatcher) {
            try {
                preferencesRepository.setHasEverRecorded(true)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to persist hasEverRecorded flag", e)
            }
        }

        // Step 3 — cleanup
        when (val result = openAiApiService.cleanupTranscript(text)) {
            is CleanupResult.Success -> {
                val wordCount = result.cleanedText.trim()
                    .split(Regex("\\s+")).count { it.isNotEmpty() }
                withContext(ioDispatcher) {
                    entryRepository.updateWithCleanedText(entryId, result.cleanedText, wordCount)
                }
                Log.d(TAG, "Entry $entryId cleaned (${wordCount}w)")
                _recordingState.value = RecordingState.Saved(
                    entryId,
                    detectedLanguage = if (mismatch) detectedLanguage else null,
                )
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
        private const val MAX_TRANSCRIPT_LENGTH = 10_000
        private const val MIN_RECORDING_MS = 5_000L
        private const val AUTO_CLEAR_DELAY_MS = 3_000L
    }
}

private fun TranscriptionFailureReason.toRecognizerError(): RecognizerError = when (this) {
    TranscriptionFailureReason.TooShort           -> RecognizerError.TooShort
    TranscriptionFailureReason.NothingCaught      -> RecognizerError.NoMatch
    TranscriptionFailureReason.MicBlocked         -> RecognizerError.InsufficientPermissions
    TranscriptionFailureReason.NetworkError       -> RecognizerError.NoInternet
    TranscriptionFailureReason.ModelNotAvailable  -> RecognizerError.NotAvailable
    TranscriptionFailureReason.ApiError           -> RecognizerError.ApiFailed
}
