package com.wrait.app.data.speech

import android.content.Context
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
class SpeechRecognizerManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val lock = Any()
    private var recognizer: SpeechRecognizer? = null
    private var timer: CountDownTimer? = null

    fun listen(languageCode: String): Flow<RecognitionResult> = callbackFlow {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            trySend(RecognitionResult.Error(RecognizerError.NotAvailable))
            close()
            return@callbackFlow
        }

        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasPermission) {
            trySend(RecognitionResult.Error(RecognizerError.InsufficientPermissions))
            close()
            return@callbackFlow
        }

        launch(Dispatchers.Main) {
            val speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
            synchronized(lock) {
                recognizer = speechRecognizer
            }

            speechRecognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: android.os.Bundle?) = Unit

                override fun onBeginningOfSpeech() = Unit

                override fun onRmsChanged(rmsdB: Float) = Unit

                override fun onBufferReceived(buffer: ByteArray?) = Unit

                override fun onEndOfSpeech() {
                    trySend(RecognitionResult.ListeningEnded)
                }

                override fun onError(error: Int) {
                    val mapped = mapError(error)
                    trySend(RecognitionResult.Error(mapped))
                    close()
                }

                override fun onResults(results: android.os.Bundle?) {
                    val matches = results
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        .orEmpty()
                    val transcript = matches.firstOrNull().orEmpty().trim()
                    val wordCount = transcript.split(Regex("\\s+")).filter { it.isNotEmpty() }.count()
                    if (wordCount < 5) {
                        trySend(RecognitionResult.Error(RecognizerError.TooShort))
                    } else {
                        trySend(RecognitionResult.Final(transcript))
                    }
                    close()
                }

                override fun onPartialResults(partialResults: android.os.Bundle?) {
                    val matches = partialResults
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        .orEmpty()
                    val transcript = matches.firstOrNull()?.trim().orEmpty()
                    if (transcript.isNotEmpty()) {
                        trySend(RecognitionResult.Partial(transcript))
                    }
                }

                override fun onEvent(eventType: Int, params: android.os.Bundle?) = Unit
            })

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, languageCode)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            }

            synchronized(lock) {
                timer?.cancel()
                timer = object : CountDownTimer(LISTENING_CAP_MS, 1000) {
                override fun onTick(millisUntilFinished: Long) = Unit
                override fun onFinish() {
                    stopListening()
                }
                }.start()
            }

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

    fun stopListening() {
        synchronized(lock) {
            val currentRecognizer = recognizer
            if (currentRecognizer != null) {
                currentRecognizer.stopListening()
            }
            timer?.cancel()
            timer = null
        }
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

    private companion object {
        private const val LISTENING_CAP_MS = 120_000L
    }
}

sealed class RecognitionResult {
    data class Partial(val text: String) : RecognitionResult()
    data class Final(val text: String) : RecognitionResult()
    data class Error(val error: RecognizerError) : RecognitionResult()
    data object ListeningEnded : RecognitionResult()
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
    data class Unknown(val code: Int) : RecognizerError()
}
