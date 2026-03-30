package com.wrait.app

import android.util.Log
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.api.OpenAiApiService
import com.wrait.app.data.speech.RecognitionResult
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.data.speech.SpeechRecognizerManager
import com.wrait.app.di.IoDispatcher
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.model.MessageType
import com.wrait.app.domain.repository.EntryRepository
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

class MainRecordingController @Inject constructor(
    private val languageState: StateFlow<String>,
    private val entryRepository: EntryRepository,
    private val speechRecognizerManager: SpeechRecognizerManager,
    private val openAiApiService: OpenAiApiService,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
    private val scope: CoroutineScope,
    private val onMessage: (MessageType, Entry) -> Unit
) {
    private val _recordingState = MutableStateFlow<RecordingState>(RecordingState.Idle)
    val recordingState: StateFlow<RecordingState> = _recordingState.asStateFlow()

    private val _shakeErrorKey = MutableStateFlow(0)
    val shakeErrorKey: StateFlow<Int> = _shakeErrorKey.asStateFlow()

    private var listenJob: Job? = null

    fun onMainButtonTapped() {
        val current = recordingState.value
        when (current) {
            RecordingState.Idle        -> startListening()
            RecordingState.Listening   -> stopListening()
            RecordingState.Processing  -> Unit
            is RecordingState.Saved    -> _recordingState.value = RecordingState.Idle
            is RecordingState.Deleted  -> _recordingState.value = RecordingState.Idle
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
        listenJob?.cancel()
        _recordingState.value = RecordingState.Listening
        listenJob = scope.launch {
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
                if (isNetworkFailure) {
                    val draftEntry = Entry(
                        id            = entryId,
                        rawTranscript = text,
                        isDraft       = true,
                        language      = language,
                        createdAt     = System.currentTimeMillis(),
                        wordCount     = 0,
                    )
                    onMessage(MessageType.NetworkError, draftEntry)
                }
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

    private companion object {
        private const val TAG = "MainRecordingController"
        private const val MAX_TRANSCRIPT_LENGTH = 10_000
    }
}
