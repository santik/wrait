package com.wrait.app.data.speech

import android.content.Context
import android.media.MediaRecorder
import android.util.Log
import com.wrait.app.data.api.WraitBackendClient
import com.wrait.app.domain.model.normalizeDetectedLanguageCode
import dagger.hilt.android.qualifiers.ApplicationContext
import io.ktor.client.plugins.HttpRequestTimeoutException
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpStatusCode
import io.ktor.http.isSuccess
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Cloud speech-to-text service for Best mode.
 *
 * Audio is recorded locally, then sent to the backend proxy at `/api/transcribe`.
 * The proxy is expected to return a Deepgram-compatible response body so the app can
 * preserve its existing transcript and detected-language parsing behavior.
 */
@Singleton
class CloudTranscriptionService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val wraitBackendClient: WraitBackendClient,
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

    private suspend fun record(file: File) = withContext(Dispatchers.IO) {
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
                val bytes = withContext(Dispatchers.IO) { file.readBytes() }
                Log.d(TAG, "Uploading ${bytes.size} bytes via backend proxy (attempt ${attempt + 1}/$MAX_UPLOAD_RETRIES)")
                val response: HttpResponse = callTranscribeEndpoint(bytes)
                return parseResponse(response)
            } catch (e: HttpRequestTimeoutException) {
                Log.w(TAG, "Backend proxy timed out (attempt ${attempt + 1}/$MAX_UPLOAD_RETRIES): ${e.message}")
                if (attempt < MAX_UPLOAD_RETRIES - 1) {
                    delay(RETRY_BASE_DELAY_MS shl attempt)
                } else {
                    return TranscriptionResult.Failure(TranscriptionFailureReason.BackendUnavailable)
                }
            } catch (e: IOException) {
                Log.w(TAG, "Network error (attempt ${attempt + 1}/$MAX_UPLOAD_RETRIES): ${e.message}")
                if (attempt < MAX_UPLOAD_RETRIES - 1) {
                    delay(RETRY_BASE_DELAY_MS shl attempt) // 1 s, 2 s, 4 s
                }
            } catch (e: Exception) {
                Log.w(TAG, "Backend proxy request failed: ${e.javaClass.simpleName}: ${e.message}")
                return TranscriptionResult.Failure(TranscriptionFailureReason.NetworkError)
            }
        }
        return TranscriptionResult.Failure(TranscriptionFailureReason.NetworkError)
    }

    private suspend fun callTranscribeEndpoint(bytes: ByteArray): HttpResponse {
        return wraitBackendClient.transcribe(bytes)
    }

    private suspend fun parseResponse(response: HttpResponse): TranscriptionResult {
        return if (response.status.isSuccess()) {
            val body = jsonParser.decodeFromString<DeepgramResponse>(response.bodyAsText())
            if (body.results.channels.isEmpty()) {
                Log.w(TAG, "Deepgram response has no channels")
                TranscriptionResult.Failure(TranscriptionFailureReason.NothingCaught)
            } else {
                val channel = body.results.channels[0]
                val transcript = channel.alternatives.firstOrNull()?.transcript.orEmpty()
                if (transcript.isBlank()) {
                    Log.w(TAG, "Deepgram response contained empty transcript")
                    TranscriptionResult.Failure(TranscriptionFailureReason.NothingCaught)
                } else {
                    val rawDetected = channel.detected_language?.takeIf { it.isNotBlank() }
                    val detected = normalizeDetectedLanguageCode(rawDetected)
                    if (rawDetected != null && detected == null) {
                        Log.w(TAG, "Ignoring invalid detected language from backend: $rawDetected")
                    }
                    Log.d(TAG, "Transcription received: ${transcript.length} chars, detected=$detected")
                    TranscriptionResult.Success(transcript, detectedLanguage = detected)
                }
            }
        } else {
            val reason = transcriptionFailureReasonForStatus(response.status)
            when (reason) {
                TranscriptionFailureReason.ProxyAuthFailed ->
                    Log.w(TAG, "Backend proxy auth/config error: HTTP ${response.status.value}")
                TranscriptionFailureReason.BackendUnavailable ->
                    Log.w(TAG, "Backend proxy unavailable: HTTP ${response.status.value}")
                else ->
                    Log.w(TAG, "Backend proxy returned error: HTTP ${response.status.value}")
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
        private const val HARD_CAP_MS = 2 * 60 * 1_000L
        private const val MIN_FILE_SIZE_BYTES = 1_024L
        private const val MAX_FILE_SIZE_BYTES = 10 * 1_024 * 1_024L  // 10 MB
        private const val MAX_UPLOAD_RETRIES = 3
        private const val RETRY_BASE_DELAY_MS = 1_000L
        private val jsonParser = Json { ignoreUnknownKeys = true }
    }
}

internal fun transcriptionFailureReasonForStatus(status: HttpStatusCode): TranscriptionFailureReason {
    return when {
        status == HttpStatusCode.Unauthorized || status == HttpStatusCode.Forbidden ->
            TranscriptionFailureReason.ProxyAuthFailed
        status.value >= 500 ->
            TranscriptionFailureReason.BackendUnavailable
        else ->
            TranscriptionFailureReason.ApiError
    }
}

@Serializable
private data class DeepgramResponse(val results: DeepgramResults)

@Serializable
private data class DeepgramResults(val channels: List<DeepgramChannel>)

@Serializable
private data class DeepgramChannel(
    val alternatives: List<DeepgramAlternative>,
    val detected_language: String? = null,
)

@Serializable
private data class DeepgramAlternative(val transcript: String)
