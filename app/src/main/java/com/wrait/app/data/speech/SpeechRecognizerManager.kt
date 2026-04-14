package com.wrait.app.data.speech

import android.content.Context
import android.util.Log
import android.content.Intent
import android.os.CountDownTimer
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.content.ContextCompat
import android.Manifest
import android.content.pm.PackageManager
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
open class SpeechRecognizerManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val lock = Any()
    private var recognizer: SpeechRecognizer? = null
    private var timer: CountDownTimer? = null
    @Volatile private var userStoppedManually = false

    /**
     * Starts speech recognition and emits [RecognitionResult] events.
     *
     * @param languageCode BCP-47 language code (e.g. "en-US").
     * @param preferOffline When `true`, uses on-device recognition so no
     *     internet connection is required. On API 31+ this creates a
     *     dedicated on-device recognizer; on older devices the
     *     [RecognizerIntent.EXTRA_PREFER_OFFLINE] hint is set.
     */
    open fun listen(
        languageCode: String,
        preferOffline: Boolean = false,
    ): Flow<RecognitionResult> = callbackFlow {
        if (preferOffline && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                trySend(RecognitionResult.Error(RecognizerError.NotAvailable))
                close()
                return@callbackFlow
            }
        } else if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            trySend(RecognitionResult.Error(RecognizerError.NotAvailable))
            close()
            return@callbackFlow
        }

        val hasPermission = ContextCompat.checkSelfPermission(
            context, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasPermission) {
            trySend(RecognitionResult.Error(RecognizerError.InsufficientPermissions))
            close()
            return@callbackFlow
        }

        launch(Dispatchers.Main) {
            userStoppedManually = false

            val speechRecognizer = if (
                preferOffline &&
                android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S
            ) {
                SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            } else {
                SpeechRecognizer.createSpeechRecognizer(context)
            }
            synchronized(lock) { recognizer = speechRecognizer }

            // Session-scoped state — lives inside this coroutine, closed over by the listener
            var sessionStartTime = 0L
            var restartCount     = 0
            var timerStarted     = false
            var lastPartialText  = ""
            var accumulatedText  = ""

            // Emits ListeningEnded then Final or TooShort based on accumulated text.
            // Captured by the recognition listener — must only be called from the Main thread.
            fun emitFinalOrTooShort() {
                val wordCount = accumulatedText.split(Regex("\\s+")).filter { it.isNotEmpty() }.count()
                trySend(RecognitionResult.ListeningEnded)
                if (wordCount < 5) {
                    trySend(RecognitionResult.Error(RecognizerError.TooShort))
                } else {
                    trySend(RecognitionResult.Final(accumulatedText))
                }
            }

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                         RecognizerIntent.LANGUAGE_MODEL_WEB_SEARCH)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, languageCode)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                         RecognitionConfig.SilenceTimeoutMs)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                         RecognitionConfig.SilenceTimeoutMs)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS,
                         RecognitionConfig.MinimumUtteranceMs)
                if (preferOffline) {
                    putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                }
            }

            speechRecognizer.setRecognitionListener(object : RecognitionListener {

                override fun onReadyForSpeech(params: android.os.Bundle?) {
                    synchronized(lock) {
                        if (!timerStarted) {
                            timerStarted = true
                            sessionStartTime = System.currentTimeMillis()
                            timer?.cancel()
                            timer = object : CountDownTimer(RecognitionConfig.HardCapMs, 1000) {
                                override fun onTick(millisUntilFinished: Long) = Unit
                                override fun onFinish() { stopListening() }
                            }.start()
                        }
                    }
                }

                override fun onBeginningOfSpeech() = Unit

                override fun onRmsChanged(rmsdB: Float) = Unit

                override fun onBufferReceived(buffer: ByteArray?) = Unit

                override fun onEndOfSpeech() = Unit
                // ListeningEnded is emitted only when we know it is a genuine stop
                // (in onResults and the genuine-stop branch of onError).
                // Emitting it here — before onError decides whether to restart —
                // caused a Processing flash on every silence pause.

                override fun onError(error: Int) {
                    val elapsed = System.currentTimeMillis() - sessionStartTime
                    val isOemTimeout = error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT
                                    || error == SpeechRecognizer.ERROR_NO_MATCH

                    if (isOemTimeout
                        && !userStoppedManually
                        && restartCount < RecognitionConfig.MaxRestartAttempts
                    ) {
                        restartCount++
                        if (lastPartialText.isNotEmpty()) {
                            accumulatedText = if (accumulatedText.isEmpty()) lastPartialText
                                              else "$accumulatedText $lastPartialText"
                            lastPartialText = ""
                        }
                        Log.d(TAG, "Restarting recognizer (attempt $restartCount/${RecognitionConfig.MaxRestartAttempts}, elapsed=${elapsed}ms)")
                        try {
                            speechRecognizer.cancel()
                            speechRecognizer.startListening(intent)
                            // No emission — ViewModel state stays Listening throughout restart cycles
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to restart recognizer", e)
                            trySend(RecognitionResult.Error(RecognizerError.Client))
                            close()
                        }
                    } else {
                        // Genuine stop — emit accumulated text if we have enough, else error
                        if (accumulatedText.isNotEmpty()) {
                            emitFinalOrTooShort()
                        } else {
                            trySend(RecognitionResult.ListeningEnded)
                            trySend(RecognitionResult.Error(mapError(error)))
                        }
                        close()
                    }
                }

                override fun onResults(results: android.os.Bundle?) {
                    val matches = results
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        .orEmpty()
                    val segment = matches.firstOrNull().orEmpty().trim()

                    // Append recognised speech to the running transcript
                    if (segment.isNotEmpty()) {
                        accumulatedText = if (accumulatedText.isEmpty()) segment
                                          else "$accumulatedText $segment"
                    }
                    lastPartialText = ""

                    if (userStoppedManually) {
                        // User tapped Stop or 2-min cap fired — finalise everything collected
                        emitFinalOrTooShort()
                        close()
                    } else {
                        // Intermediate result — restart and keep listening.
                        // Do NOT call cancel() here: recognition has already completed normally,
                        // the recognizer is idle. cancel() on a completed recognizer can trigger
                        // a spurious onError(ERROR_CLIENT) that closes the flow prematurely.
                        restartCount = 0  // successful recognition resets the error cap
                        Log.d(TAG, "Restarting after onResults (accumulated: \"$accumulatedText\")")
                        try {
                            speechRecognizer.startListening(intent)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to restart after onResults", e)
                            emitFinalOrTooShort()
                            close()
                        }
                    }
                }

                override fun onPartialResults(partialResults: android.os.Bundle?) {
                    val matches = partialResults
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        .orEmpty()
                    val transcript = matches.firstOrNull()?.trim().orEmpty()
                    if (transcript.isNotEmpty()) {
                        lastPartialText = transcript
                        trySend(RecognitionResult.Partial(transcript))
                    }
                }

                override fun onEvent(eventType: Int, params: android.os.Bundle?) = Unit
            })

            speechRecognizer.startListening(intent)
        }

        awaitClose {
            launch(Dispatchers.Main) {
                synchronized(lock) {
                    timer?.cancel()
                    timer = null
                    recognizer?.apply {
                        stopListening()
                        cancel()
                        destroy()
                    }
                    recognizer = null
                }
            }
        }
    }

    open fun stopListening() {
        userStoppedManually = true
        synchronized(lock) {
            val currentRecognizer = recognizer
            if (currentRecognizer != null) {
                currentRecognizer.stopListening()
            }
            timer?.cancel()
            timer = null
        }
    }

    private companion object {
        private const val TAG = "SpeechRecognizerManager"
    }

    private fun mapError(error: Int): RecognizerError {
        return when (error) {
            SpeechRecognizer.ERROR_NO_MATCH -> RecognizerError.NoMatch
            SpeechRecognizer.ERROR_NETWORK,
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> RecognizerError.Network
            SpeechRecognizer.ERROR_AUDIO -> RecognizerError.Audio
            SpeechRecognizer.ERROR_CLIENT -> RecognizerError.Client
            SpeechRecognizer.ERROR_SERVER -> RecognizerError.Server
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> RecognizerError.Timeout
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> RecognizerError.InsufficientPermissions
            else -> RecognizerError.Unknown(error)
        }
    }
}

sealed class RecognitionResult {
    data class Partial(val text: String) : RecognitionResult()
    data class Final(val text: String) : RecognitionResult()
    data class Error(val error: RecognizerError) : RecognitionResult()
    data object ListeningEnded : RecognitionResult()
    data object Restarted : RecognitionResult()
}

sealed class RecognizerError {
    data object NoMatch : RecognizerError()
    data object TooShort : RecognizerError()
    data object Network : RecognizerError()
    data object Audio : RecognizerError()
    data object Client : RecognizerError()
    data object Server : RecognizerError()
    data object Timeout : RecognizerError()
    data object NotAvailable : RecognizerError()
    data object InsufficientPermissions : RecognizerError()
    /** OpenAI cleanup call failed due to missing / slow network. Entry saved as draft. */
    data object NoInternet : RecognizerError()
    /** OpenAI cleanup call returned a non-network failure. Entry saved as draft. */
    data object ApiFailed : RecognizerError()
    data class Unknown(val code: Int) : RecognizerError()
}
