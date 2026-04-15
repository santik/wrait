package com.wrait.app.data.speech

import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AndroidTranscriptionService @Inject constructor(
    private val speechRecognizerManager: SpeechRecognizerManager
) : TranscriptionService {

    override suspend fun transcribe(
        languageCode: String,
        onStatus: (TranscriptionStatus) -> Unit
    ): TranscriptionResult {
        var result: TranscriptionResult? = null

        speechRecognizerManager.listen(languageCode, preferOffline = true).collect { event ->
            when (event) {
                RecognitionResult.ListeningEnded -> onStatus(TranscriptionStatus.RecordingEnded)
                is RecognitionResult.Final       -> result = TranscriptionResult.Success(event.text)
                is RecognitionResult.Error       -> result = TranscriptionResult.Failure(event.error.toFailureReason())
                RecognitionResult.Restarted,
                is RecognitionResult.Partial     -> Unit
            }
        }

        return result ?: TranscriptionResult.Failure(TranscriptionFailureReason.NothingCaught)
    }

    override fun isOfflineModelAvailable(): Boolean =
        speechRecognizerManager.isOnDeviceRecognitionAvailable()

    override fun stopRecording() {
        speechRecognizerManager.stopListening()
    }
}

private fun RecognizerError.toFailureReason(): TranscriptionFailureReason = when (this) {
    RecognizerError.TooShort              -> TranscriptionFailureReason.TooShort
    RecognizerError.NoMatch               -> TranscriptionFailureReason.NothingCaught
    RecognizerError.InsufficientPermissions -> TranscriptionFailureReason.MicBlocked
    RecognizerError.NotAvailable          -> TranscriptionFailureReason.ModelNotAvailable
    RecognizerError.Network,
    RecognizerError.Timeout,
    RecognizerError.NoInternet            -> TranscriptionFailureReason.NetworkError
    else                                  -> TranscriptionFailureReason.ApiError
}
