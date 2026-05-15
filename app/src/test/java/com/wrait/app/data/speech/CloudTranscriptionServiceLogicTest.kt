package com.wrait.app.data.speech

import android.media.MediaRecorder
import com.wrait.app.data.api.BackendAudioUploadConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class CloudTranscriptionServiceLogicTest {

    @Test
    fun recordedFileFailureReason_tooSmall_returnsTooShort() {
        assertEquals(
            TranscriptionFailureReason.TooShort,
            CloudTranscriptionFilePolicy.failureReasonForRecordedFileSize(1_023L),
        )
    }

    @Test
    fun recordedFileFailureReason_tooLarge_returnsApiError() {
        assertEquals(
            TranscriptionFailureReason.ApiError,
            CloudTranscriptionFilePolicy.failureReasonForRecordedFileSize(10 * 1_024 * 1_024L + 1L),
        )
    }

    @Test
    fun recordedFileFailureReason_inRange_returnsNull() {
        assertEquals(null, CloudTranscriptionFilePolicy.failureReasonForRecordedFileSize(2_048L))
    }

    @Test
    fun shouldPersistAudioDraftReason_onlyPersistsRetryableFailures() {
        assertTrue(CloudTranscriptionFilePolicy.shouldPersistAudioDraft(TranscriptionFailureReason.NetworkError))
        assertTrue(CloudTranscriptionFilePolicy.shouldPersistAudioDraft(TranscriptionFailureReason.ApiError))
        assertTrue(CloudTranscriptionFilePolicy.shouldPersistAudioDraft(TranscriptionFailureReason.BackendUnavailable))
        assertTrue(CloudTranscriptionFilePolicy.shouldPersistAudioDraft(TranscriptionFailureReason.ProxyAuthFailed))
        assertFalse(CloudTranscriptionFilePolicy.shouldPersistAudioDraft(TranscriptionFailureReason.TooShort))
        assertFalse(CloudTranscriptionFilePolicy.shouldPersistAudioDraft(TranscriptionFailureReason.NothingCaught))
        assertFalse(CloudTranscriptionFilePolicy.shouldPersistAudioDraft(TranscriptionFailureReason.MicBlocked))
    }

    @Test
    fun persistDraftAudio_movesFileIntoDraftDirectory() {
        val filesDir = createTempDir()
        val tempFile = File.createTempFile(
            "recording",
            ".${BackendAudioUploadConfig.RECORDED_AUDIO_FILE_EXTENSION}",
        ).apply {
            writeText("audio-bytes")
        }

        val draftPath = CloudTranscriptionFilePolicy.persistDraftAudio(
            tempFile = tempFile,
            filesDir = filesDir,
            timestampMs = 1234L,
        )

        assertNotNull(draftPath)
        val persistedFile = File(draftPath!!)
        assertTrue(persistedFile.exists())
        assertTrue(persistedFile.absolutePath.contains("audio_drafts"))
        assertTrue(
            persistedFile.name.endsWith(".${BackendAudioUploadConfig.RECORDED_AUDIO_FILE_EXTENSION}"),
        )
        assertEquals("audio-bytes", persistedFile.readText())

        persistedFile.delete()
        File(filesDir, "audio_drafts").delete()
        filesDir.delete()
    }

    @Test
    fun deleteTempTranscriptionFile_removesExistingTempFile() {
        val tempFile = File.createTempFile(
            "recording",
            ".${BackendAudioUploadConfig.RECORDED_AUDIO_FILE_EXTENSION}",
        ).apply {
            writeText("audio-bytes")
        }

        val deleted = CloudTranscriptionFilePolicy.deleteTempFile(tempFile)

        assertTrue(deleted)
        assertFalse(tempFile.exists())
    }

    @Test
    fun recorderConfiguration_remainsCompatibleWithRecordedExtension() {
        assertEquals(MediaRecorder.OutputFormat.MPEG_4, CloudTranscriptionFilePolicy.RECORDED_AUDIO_OUTPUT_FORMAT)
        assertEquals("m4a", BackendAudioUploadConfig.RECORDED_AUDIO_FILE_EXTENSION)
    }

    @Test
    fun createRecordingFile_usesConfiguredExtension() {
        val file = CloudTranscriptionFilePolicy.createRecordingFile(
            cacheDir = createTempDir(),
            timestampMs = 42L,
        )

        assertTrue(file.name.endsWith(".${BackendAudioUploadConfig.RECORDED_AUDIO_FILE_EXTENSION}"))
        file.parentFile?.delete()
    }

    private fun createTempDir(): File {
        return File.createTempFile("cloud-transcription", "").apply {
            delete()
            mkdirs()
        }
    }
}
