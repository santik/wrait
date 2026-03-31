package com.wrait.app.test.fake

import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.data.speech.TranscriptionFailureReason
import com.wrait.app.data.speech.TranscriptionResult
import com.wrait.app.data.speech.TranscriptionService
import com.wrait.app.data.speech.TranscriptionStatus

class FakeTranscriptionService : TranscriptionService {

    sealed class FakeResult {
        data class FinalTranscript(val text: String) : FakeResult()
        data class SpeechError(val error: RecognizerError) : FakeResult()
    }

    var nextResult: FakeResult = FakeResult.FinalTranscript("one two three four five")

    override suspend fun transcribe(
        languageCode: String,
        onStatus: (TranscriptionStatus) -> Unit
    ): TranscriptionResult {
        onStatus(TranscriptionStatus.RecordingEnded)
        return when (val r = nextResult) {
            is FakeResult.FinalTranscript -> TranscriptionResult.Success(r.text)
            is FakeResult.SpeechError     -> TranscriptionResult.Failure(r.error.toFailureReason())
        }
    }

    override fun stopRecording() { /* no-op */ }
}

private fun RecognizerError.toFailureReason(): TranscriptionFailureReason = when (this) {
    RecognizerError.TooShort                -> TranscriptionFailureReason.TooShort
    RecognizerError.NoMatch                 -> TranscriptionFailureReason.NothingCaught
    RecognizerError.InsufficientPermissions -> TranscriptionFailureReason.MicBlocked
    RecognizerError.Network,
    RecognizerError.Timeout,
    RecognizerError.NoInternet              -> TranscriptionFailureReason.NetworkError
    RecognizerError.Audio,
    RecognizerError.Client,
    RecognizerError.Server,
    RecognizerError.NotAvailable,
    RecognizerError.ApiFailed,
    is RecognizerError.Unknown              -> TranscriptionFailureReason.ApiError
}
