package com.wrait.app.data.speech

interface TranscriptionService {
    /** Suspends until transcription is complete. */
    suspend fun transcribe(
        languageCode: String,
        onStatus: (TranscriptionStatus) -> Unit = {}
    ): TranscriptionResult

    /**
     * Returns `true` when the device has an offline speech recognition model
     * installed. Always returns `true` for cloud-backed services.
     */
    fun isOfflineModelAvailable(): Boolean = true

    /**
     * Optional: transcribe an existing audio file on disk (used for retrying audio drafts).
     * Default implementation returns ApiError so implementations don't have to support it.
     */
    suspend fun transcribeAudioDraft(
        audioPath: String,
        languageCode: String,
        onStatus: (TranscriptionStatus) -> Unit = {},
    ): TranscriptionResult = TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)

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
    data class Success(
        val transcript: String,
        /** Language code detected by the backend (e.g. "fr"), or null if not available. */
        val detectedLanguage: String? = null,
    ) : TranscriptionResult()
    data class Failure(
        val reason: TranscriptionFailureReason,
        /** Non-null when an audio file was persisted as a draft (Whisper backend). */
        val audioDraftPath: String? = null,
    ) : TranscriptionResult()
}

enum class TranscriptionFailureReason {
    TooShort, NothingCaught, MicBlocked, NetworkError, ApiError
}
