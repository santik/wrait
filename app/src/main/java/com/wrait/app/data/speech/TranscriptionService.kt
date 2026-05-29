package com.wrait.app.data.speech

import com.wrait.app.data.api.RecordQuotaState

interface TranscriptionService {
    /**
     * Suspends until transcription is complete.
     *
     * [languageCode] is always provided by callers as the user's selected language.
     * Implementations may either:
     * 1) send it as a hard constraint (e.g. Whisper/Android), or
     * 2) use backend auto-detection and treat [languageCode] as contextual metadata only.
     */
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
        onStatus: (TranscriptionStatus) -> Unit = {},
    ): TranscriptionResult = TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)

    /** Signals the service to stop recording (non-suspending). */
    fun stopRecording()
}

sealed interface TranscriptionStatus {
    /** Recording has actually started and will hard-stop at the provided deadline. */
    data class RecordingStarted(
        val hardCapDeadlineElapsedRealtime: Long,
    ) : TranscriptionStatus

    /** Android backend: recording phase ended (after ListeningEnded). */
    data object RecordingEnded : TranscriptionStatus

    /** Whisper/backend mode: audio file is being uploaded. */
    data object Uploading : TranscriptionStatus
}

sealed class TranscriptionResult {
    data class Success(
        val transcript: String,
        /** Language code detected by the backend (e.g. "fr"), or null if not available. */
        val detectedLanguage: String? = null,
        val quota: RecordQuotaState? = null,
    ) : TranscriptionResult()
    data class Failure(
        val reason: TranscriptionFailureReason,
        /** Non-null when an audio file was persisted as a draft (Whisper backend). */
        val audioDraftPath: String? = null,
        val quota: RecordQuotaState? = null,
    ) : TranscriptionResult()
}

enum class TranscriptionFailureReason {
    TooShort,
    NothingCaught,
    MicBlocked,
    NetworkError,
    ApiError,
    ModelNotAvailable,
    BackendUnavailable,
    ProxyAuthFailed,
}
