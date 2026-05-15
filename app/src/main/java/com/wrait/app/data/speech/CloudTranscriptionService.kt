package com.wrait.app.data.speech

import android.content.Context
import android.media.MediaRecorder
import android.util.Log
import com.wrait.app.data.api.DeviceIdUnavailableException
import com.wrait.app.data.api.TranscribeUploadClient
import com.wrait.app.data.api.TranscribeHttpResponse
import com.wrait.app.data.api.isNetworkTimeout
import com.wrait.app.data.api.generated.model.TranscribeResponse
import com.wrait.app.di.IoDispatcher
import com.wrait.app.domain.model.normalizeDetectedLanguageCode
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

/**
 * Cloud speech-to-text service for Best mode.
 *
 * Audio is recorded locally, then sent to the backend proxy at `/api/transcribe`.
 * The proxy returns the normalized OpenAPI contract shared with the backend.
 */
@Singleton
class CloudTranscriptionService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val transcribeUploadClient: TranscribeUploadClient,
    @param:IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : TranscriptionService {

    @Volatile private var stopSignal = CompletableDeferred<Unit>()

    override suspend fun transcribe(
        languageCode: String,
        onStatus: (TranscriptionStatus) -> Unit,
    ): TranscriptionResult {
        stopSignal = CompletableDeferred()
        val tempFile = File(context.cacheDir, "wrait_recording_${System.currentTimeMillis()}.m4a")
        var keepFileAsDraft = false
        var draftPath: String? = null
        return try {
            record(tempFile)
            if (tempFile.length() < MIN_FILE_SIZE_BYTES) {
                Log.w(TAG, "Recording too short: ${tempFile.length()} bytes")
                return TranscriptionResult.Failure(TranscriptionFailureReason.TooShort)
            }
            if (tempFile.length() > MAX_FILE_SIZE_BYTES) {
                Log.w(TAG, "Recording too large: ${tempFile.length()} bytes")
                return TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
            }
            onStatus(TranscriptionStatus.Uploading)
            when (val result = upload(tempFile)) {
                is TranscriptionResult.Success -> result
                is TranscriptionResult.Failure -> {
                    keepFileAsDraft = shouldPersistAudioDraft(result.reason)
                    if (keepFileAsDraft) {
                        draftPath = persistDraftAudio(tempFile)
                        keepFileAsDraft = draftPath != null
                    }
                    TranscriptionResult.Failure(result.reason, audioDraftPath = draftPath)
                }
            }
        } finally {
            if (!keepFileAsDraft) {
                if (!tempFile.delete()) {
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
        recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
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
        repeat(MAX_UPLOAD_RETRIES) { attempt ->
            try {
                Log.d(TAG, "Uploading ${file.length()} bytes via backend proxy (attempt ${attempt + 1}/$MAX_UPLOAD_RETRIES)")
                val response = callTranscribeEndpoint(file)
                return parseResponse(response)
            } catch (e: IOException) {
                if (e.isNetworkTimeout()) {
                    Log.w(TAG, "Backend proxy timed out (attempt ${attempt + 1}/$MAX_UPLOAD_RETRIES): ${e.message}")
                    if (attempt < MAX_UPLOAD_RETRIES - 1) {
                        delay(RETRY_BASE_DELAY_MS shl attempt)
                    } else {
                        return TranscriptionResult.Failure(TranscriptionFailureReason.BackendUnavailable)
                    }
                    return@repeat
                }

                Log.w(TAG, "Network error (attempt ${attempt + 1}/$MAX_UPLOAD_RETRIES): ${e.message}")
                if (attempt < MAX_UPLOAD_RETRIES - 1) {
                    delay(RETRY_BASE_DELAY_MS shl attempt) // 1 s, 2 s, 4 s
                }
            } catch (e: SerializationException) {
                Log.w(TAG, "Backend proxy returned an invalid transcript payload: ${e.message}")
                return TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
            } catch (e: DeviceIdUnavailableException) {
                Log.e(TAG, "Backend proxy upload could not resolve device id", e)
                return TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
            } catch (e: Exception) {
                Log.e(TAG, "Backend proxy request failed unexpectedly", e)
                return TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
            }
        }
        return TranscriptionResult.Failure(TranscriptionFailureReason.NetworkError)
    }

    private suspend fun callTranscribeEndpoint(file: File): TranscribeHttpResponse {
        return transcribeUploadClient.transcribe(file)
    }

    private fun parseResponse(response: TranscribeHttpResponse): TranscriptionResult {
        return if (response.statusCode in 200..299) {
            val responseBody = response.body
            if (responseBody.isNullOrBlank()) {
                Log.w(TAG, "Backend proxy returned HTTP ${response.statusCode} with an empty body")
                TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
            } else {
                val body = jsonParser.decodeFromString<TranscribeResponse>(responseBody)
                val transcript = body.transcript.trim()
                if (transcript.isBlank()) {
                    Log.w(TAG, "Backend proxy response contained empty transcript")
                    TranscriptionResult.Failure(TranscriptionFailureReason.NothingCaught)
                } else {
                    val rawDetected = body.detectedLanguage.takeIf { it.isNotBlank() }
                    val detected = normalizeDetectedLanguageCode(rawDetected)
                    if (rawDetected != null && detected == null) {
                        Log.w(TAG, "Ignoring invalid detected language from backend: $rawDetected")
                    }
                    Log.d(TAG, "Transcription received: ${transcript.length} chars, detected=$detected")
                    TranscriptionResult.Success(transcript, detectedLanguage = detected)
                }
            }
        } else {
            val reason = transcriptionFailureReasonForStatus(response.statusCode)
            when (reason) {
                TranscriptionFailureReason.ProxyAuthFailed ->
                    Log.w(TAG, "Backend proxy auth/config error: HTTP ${response.statusCode}")
                TranscriptionFailureReason.BackendUnavailable ->
                    Log.w(TAG, "Backend proxy unavailable: HTTP ${response.statusCode}")
                else ->
                    Log.w(TAG, "Backend proxy returned error: HTTP ${response.statusCode}")
            }
            TranscriptionResult.Failure(reason)
        }
    }

    private fun shouldPersistAudioDraft(reason: TranscriptionFailureReason): Boolean {
        return when (reason) {
            TranscriptionFailureReason.NetworkError,
            TranscriptionFailureReason.ApiError,
            TranscriptionFailureReason.BackendUnavailable,
            TranscriptionFailureReason.ProxyAuthFailed -> true
            else -> false
        }
    }

    private fun persistDraftAudio(tempFile: File): String? {
        return try {
            val dir = File(context.filesDir, "audio_drafts").apply { mkdirs() }
            val dst = File(dir, "draft_${System.currentTimeMillis()}.m4a")
            val moved = tempFile.renameTo(dst)
            if (!moved) {
                tempFile.copyTo(dst, overwrite = true)
            }
            Log.d(TAG, "Audio draft persisted: ${dst.absolutePath}")
            dst.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Failed to persist audio draft: ${e.message}")
            null
        }
    }

    private companion object {
        private const val TAG = "CloudTranscriptionService"
        // Keeps recording sessions aligned with the product's two-minute cap.
        private const val HARD_CAP_MS = 2 * 60 * 1_000L
        // Rejects near-empty recordings that only contain container metadata.
        private const val MIN_FILE_SIZE_BYTES = 1_024L
        // Caps uploads to a size that the backend and device memory budget can tolerate.
        private const val MAX_FILE_SIZE_BYTES = 10 * 1_024 * 1_024L  // 10 MB
        // Retries transient upload failures without stretching the happy path too long.
        private const val MAX_UPLOAD_RETRIES = 3
        // Exponential backoff base: 1 s, 2 s, then 4 s.
        private const val RETRY_BASE_DELAY_MS = 1_000L
        private val jsonParser = Json { ignoreUnknownKeys = true }
    }
}

internal fun transcriptionFailureReasonForStatus(statusCode: Int): TranscriptionFailureReason {
    return when {
        statusCode == 401 || statusCode == 403 ->
            TranscriptionFailureReason.ProxyAuthFailed
        statusCode >= 500 ->
            TranscriptionFailureReason.BackendUnavailable
        else ->
            TranscriptionFailureReason.ApiError
    }
}
