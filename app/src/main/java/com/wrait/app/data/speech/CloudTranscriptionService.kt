package com.wrait.app.data.speech

import android.content.Context
import android.media.MediaRecorder
import android.util.Log
import com.wrait.app.data.api.WraitBackendClient
import com.wrait.app.di.IoDispatcher
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Cloud speech-to-text service for Best mode.
 *
 * Audio is recorded locally, then sent to the backend proxy at `/api/transcribe`.
 * The proxy returns the normalized OpenAPI contract shared with the backend.
 */
@Singleton
class CloudTranscriptionService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val wraitBackendClient: WraitBackendClient,
    @param:IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : TranscriptionService {

    @Volatile private var stopSignal = CompletableDeferred<Unit>()

    override suspend fun transcribe(
        languageCode: String,
        onStatus: (TranscriptionStatus) -> Unit,
    ): TranscriptionResult {
        stopSignal = CompletableDeferred()
        val tempFile = CloudTranscriptionFilePolicy.createRecordingFile(context.cacheDir)
        var keepFileAsDraft = false
        var draftPath: String? = null
        return try {
            record(tempFile)
            val sizeFailure = CloudTranscriptionFilePolicy.failureReasonForRecordedFileSize(tempFile.length())
            if (sizeFailure != null) {
                Log.w(TAG, "Recording rejected after capture: size=${tempFile.length()} bytes, reason=$sizeFailure")
                return TranscriptionResult.Failure(sizeFailure)
            }
            onStatus(TranscriptionStatus.Uploading)
            when (val result = upload(tempFile)) {
                is TranscriptionResult.Success -> result
                is TranscriptionResult.Failure -> {
                    keepFileAsDraft = CloudTranscriptionFilePolicy.shouldPersistAudioDraft(result.reason)
                    if (keepFileAsDraft) {
                        draftPath = CloudTranscriptionFilePolicy.persistDraftAudio(
                            tempFile = tempFile,
                            filesDir = context.filesDir,
                        )
                        keepFileAsDraft = draftPath != null
                    }
                    TranscriptionResult.Failure(result.reason, audioDraftPath = draftPath)
                }
            }
        } finally {
            if (!keepFileAsDraft) {
                if (!CloudTranscriptionFilePolicy.deleteTempFile(tempFile)) {
                    Log.w(TAG, "Failed to delete temp file: ${tempFile.absolutePath}")
                    try {
                        tempFile.deleteOnExit()
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to schedule file deletion: ${e.message}")
                    }
                } else {
                    Log.d(TAG, "Temp file deleted: ${tempFile.name}")
                }
            }
        }
    }

    override fun stopRecording() {
        stopSignal.complete(Unit)
    }

    override suspend fun transcribeAudioDraft(
        audioPath: String,
        onStatus: (TranscriptionStatus) -> Unit,
    ): TranscriptionResult {
        val file = File(audioPath)
        if (!file.exists() || file.length() <= 0L) {
            Log.w(TAG, "Audio draft missing or empty: $audioPath")
            return TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
        }
        onStatus(TranscriptionStatus.Uploading)
        return upload(file)
    }

    private suspend fun record(file: File) = withContext(ioDispatcher) {
        @Suppress("DEPRECATION")
        val recorder = MediaRecorder()
        recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
        recorder.setOutputFormat(CloudTranscriptionFilePolicy.RECORDED_AUDIO_OUTPUT_FORMAT)
        recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        recorder.setAudioSamplingRate(16_000)
        recorder.setAudioChannels(1)
        recorder.setAudioEncodingBitRate(128_000)
        recorder.setOutputFile(file.absolutePath)

        try {
            recorder.prepare()
            recorder.start()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recorder: ${e.message}")
            recorder.release()
            throw e
        }

        Log.d(TAG, "Recording started: ${file.name}")

        withTimeoutOrNull(HARD_CAP_MS) {
            stopSignal.await()
        }

        try {
            recorder.stop()
        } catch (e: Exception) {
            Log.w(TAG, "recorder.stop() threw: ${e.message}")
        } finally {
            recorder.release()
        }
        Log.d(TAG, "Recording stopped: ${file.length()} bytes")
    }

    private suspend fun upload(file: File): TranscriptionResult {
        Log.d(TAG, "Uploading ${file.length()} bytes via backend proxy")
        return wraitBackendClient.transcribeAudio(file)
    }

    private companion object {
        private const val TAG = "CloudTranscriptionService"
        // Keeps recording sessions aligned with the product's two-minute cap.
        private const val HARD_CAP_MS = 2 * 60 * 1_000L
    }
}
