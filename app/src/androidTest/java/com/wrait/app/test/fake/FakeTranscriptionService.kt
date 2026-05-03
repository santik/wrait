package com.wrait.app.test.fake

import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.data.speech.TranscriptionFailureReason
import com.wrait.app.data.speech.TranscriptionResult
import com.wrait.app.data.speech.TranscriptionService
import com.wrait.app.data.speech.TranscriptionStatus

class FakeTranscriptionService : TranscriptionService {

    sealed class FakeResult {
        data class FinalTranscript(
            val text: String,
            val detectedLanguage: String? = null,
        ) : FakeResult()
        data class SpeechError(val error: RecognizerError) : FakeResult()
        data class FailureWithAudioDraft(
            val reason: TranscriptionFailureReason,
            val audioPath: String,
        ) : FakeResult()
    }

    var nextResult: FakeResult = FakeResult.FinalTranscript("one two three four five")
    var nextAudioDraftResult: TranscriptionResult =
        TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)

    fun reset() {
        nextResult = FakeResult.FinalTranscript("one two three four five")
        nextAudioDraftResult = TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
    }

    override suspend fun transcribe(
        languageCode: String,
        onStatus: (TranscriptionStatus) -> Unit
    ): TranscriptionResult {
        onStatus(TranscriptionStatus.RecordingEnded)
        return when (val r = nextResult) {
            is FakeResult.FinalTranscript -> TranscriptionResult.Success(r.text, r.detectedLanguage)
            is FakeResult.SpeechError -> TranscriptionResult.Failure(r.error.toFailureReason())
            is FakeResult.FailureWithAudioDraft ->
                TranscriptionResult.Failure(r.reason, r.audioPath)
        }
    }

    override suspend fun transcribeAudioDraft(
        audioPath: String,
        languageCode: String,
        onStatus: (TranscriptionStatus) -> Unit,
    ): TranscriptionResult = nextAudioDraftResult

    override fun stopRecording() { /* no-op */ }
}

private fun RecognizerError.toFailureReason(): TranscriptionFailureReason = when (this) {
    RecognizerError.TooShort                -> TranscriptionFailureReason.TooShort
    RecognizerError.NoMatch                 -> TranscriptionFailureReason.NothingCaught
    RecognizerError.InsufficientPermissions -> TranscriptionFailureReason.MicBlocked
    is RecognizerError.NotAvailable        -> TranscriptionFailureReason.ModelNotAvailable
    RecognizerError.Network,
    RecognizerError.Timeout,
    RecognizerError.NoInternet              -> TranscriptionFailureReason.NetworkError
    RecognizerError.BackendUnavailable      -> TranscriptionFailureReason.BackendUnavailable
    RecognizerError.ProxyAuthFailed         -> TranscriptionFailureReason.ProxyAuthFailed
    RecognizerError.Audio,
    RecognizerError.Client,
    RecognizerError.Server,
    RecognizerError.ApiFailed,
    is RecognizerError.Unknown              -> TranscriptionFailureReason.ApiError
}
