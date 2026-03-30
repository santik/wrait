package com.wrait.app.data.speech

interface TranscriptionService {
    /** Suspends until transcription is complete. */
    suspend fun transcribe(
        languageCode: String,
        onStatus: (TranscriptionStatus) -> Unit = {}
    ): TranscriptionResult

    /** Signals the service to stop recording (non-suspending). */
    fun stopRecording()
}

enum class TranscriptionStatus {
    /** Android backend: recording phase ended (after ListeningEnded). */
    RecordingEnded,
    /** Whisper backend: audio file is being uploaded. */
    Uploading
}

sealed class TranscriptionResult {
    data class Success(val transcript: String) : TranscriptionResult()
    data class Failure(val reason: TranscriptionFailureReason) : TranscriptionResult()
}

enum class TranscriptionFailureReason {
    TooShort, NothingCaught, MicBlocked, NetworkError, ApiError
}
