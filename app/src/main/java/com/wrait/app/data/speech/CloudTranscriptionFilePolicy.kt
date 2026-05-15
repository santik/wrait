package com.wrait.app.data.speech

import android.media.MediaRecorder
import com.wrait.app.data.api.BackendAudioUploadConfig
import java.io.File

/**
 * Keeps the cloud transcription file lifecycle rules in one place:
 * recording file naming, size limits, draft persistence, and deletion.
 *
 * The recorder currently produces an audio-only MPEG-4 container, so the
 * temporary filename uses the `.m4a` extension configured in
 * [BackendAudioUploadConfig].
 */
internal object CloudTranscriptionFilePolicy {
    const val RECORDED_AUDIO_OUTPUT_FORMAT: Int = MediaRecorder.OutputFormat.MPEG_4

    private const val MIN_RECORDING_FILE_SIZE_BYTES = 1_024L
    private const val MAX_UPLOAD_FILE_SIZE_BYTES = 10 * 1_024 * 1_024L

    fun createRecordingFile(
        cacheDir: File,
        timestampMs: Long = System.currentTimeMillis(),
    ): File {
        return File(
            cacheDir,
            "wrait_recording_${timestampMs}.${BackendAudioUploadConfig.RECORDED_AUDIO_FILE_EXTENSION}",
        )
    }

    fun failureReasonForRecordedFileSize(fileSizeBytes: Long): TranscriptionFailureReason? {
        return when {
            fileSizeBytes < MIN_RECORDING_FILE_SIZE_BYTES -> TranscriptionFailureReason.TooShort
            fileSizeBytes > MAX_UPLOAD_FILE_SIZE_BYTES -> TranscriptionFailureReason.ApiError
            else -> null
        }
    }

    fun shouldPersistAudioDraft(reason: TranscriptionFailureReason): Boolean {
        return when (reason) {
            TranscriptionFailureReason.NetworkError,
            TranscriptionFailureReason.ApiError,
            TranscriptionFailureReason.BackendUnavailable,
            TranscriptionFailureReason.ProxyAuthFailed -> true
            else -> false
        }
    }

    fun persistDraftAudio(
        tempFile: File,
        filesDir: File,
        timestampMs: Long = System.currentTimeMillis(),
    ): String? {
        return try {
            val dir = File(filesDir, "audio_drafts").apply { mkdirs() }
            val dst = File(
                dir,
                "draft_${timestampMs}.${BackendAudioUploadConfig.RECORDED_AUDIO_FILE_EXTENSION}",
            )
            val moved = tempFile.renameTo(dst)
            if (!moved) {
                tempFile.copyTo(dst, overwrite = true)
            }
            dst.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    fun deleteTempFile(tempFile: File): Boolean = tempFile.delete()
}
