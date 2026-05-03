package com.wrait.app.data.speech

import android.content.Context
import android.media.MediaRecorder
import android.util.Log
import com.wrait.app.BuildConfig
import com.wrait.app.data.api.DeepgramRequestParams
import com.wrait.app.data.api.WraitBackendClient
import com.wrait.app.domain.model.TranscriptionBackend
import com.wrait.app.domain.repository.PreferencesRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import io.ktor.client.HttpClient
import io.ktor.client.engine.android.Android
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.isSuccess
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DeepgramTranscriptionService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val wraitBackendClient: WraitBackendClient,
    private val preferencesRepository: PreferencesRepository,
) : TranscriptionService {

    private val client = HttpClient(Android) {
        install(HttpTimeout) {
            connectTimeoutMillis = 10_000
            requestTimeoutMillis = 300_000 // 5 min ceiling — 2-min cap bounds file size
        }
    }

    @Volatile private var stopSignal = CompletableDeferred<Unit>()

    override suspend fun transcribe(
        languageCode: String,
        onStatus: (TranscriptionStatus) -> Unit,
    ): TranscriptionResult {
        val backend = preferencesRepository.transcriptionBackend.first()
        if (backend == TranscriptionBackend.DIRECT && BuildConfig.DEEPGRAM_API_KEY.isBlank()) {
            Log.e(TAG, "Deepgram API key is not configured")
            return TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
        }
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
            when (val result = upload(tempFile, languageCode)) {
                is TranscriptionResult.Success -> result
                is TranscriptionResult.Failure -> {
                    keepFileAsDraft = result.reason == TranscriptionFailureReason.NetworkError ||
                        result.reason == TranscriptionFailureReason.ApiError
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
        languageCode: String,
        onStatus: (TranscriptionStatus) -> Unit,
    ): TranscriptionResult {
        val file = File(audioPath)
        if (!file.exists() || file.length() <= 0L) {
            Log.w(TAG, "Audio draft missing or empty: $audioPath")
            return TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
        }
        onStatus(TranscriptionStatus.Uploading)
        return upload(file, languageCode)
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

    private suspend fun upload(file: File, selectedLanguageCode: String): TranscriptionResult {
        repeat(MAX_UPLOAD_RETRIES) { attempt ->
            try {
                val bytes = withContext(Dispatchers.IO) { file.readBytes() }
                val backend = preferencesRepository.transcriptionBackend.first()
                Log.d(TAG, "Uploading ${bytes.size} bytes (attempt ${attempt + 1}/$MAX_UPLOAD_RETRIES, backend=$backend)")
                val response: HttpResponse = callTranscribeEndpoint(bytes, selectedLanguageCode, backend)
                return parseResponse(response)
            } catch (e: IOException) {
                Log.w(TAG, "Network error (attempt ${attempt + 1}/$MAX_UPLOAD_RETRIES): ${e.message}")
                if (attempt < MAX_UPLOAD_RETRIES - 1) {
                    delay(RETRY_BASE_DELAY_MS shl attempt) // 1 s, 2 s, 4 s
                }
            } catch (e: Exception) {
                Log.w(TAG, "Upload failed: ${e.javaClass.simpleName}: ${e.message}")
                return TranscriptionResult.Failure(TranscriptionFailureReason.NetworkError)
            }
        }
        return TranscriptionResult.Failure(TranscriptionFailureReason.NetworkError)
    }

    private suspend fun callTranscribeEndpoint(
        bytes: ByteArray,
        selectedLanguageCode: String,
        backend: TranscriptionBackend,
    ): HttpResponse {
        return if (backend == TranscriptionBackend.PROXY) {
            wraitBackendClient.transcribe(bytes, selectedLanguageCode)
        } else {
            client.post(BuildConfig.DEEPGRAM_LISTEN_URL) {
                header(HttpHeaders.Authorization, "Token ${BuildConfig.DEEPGRAM_API_KEY}")
                header(HttpHeaders.ContentType, "audio/mp4")
                // Auto-detect strategy: keep selected language for UX, not as API constraint.
                DeepgramRequestParams.asPairs().forEach { (name, value) ->
                    parameter(name, value)
                }
                setBody(bytes)
            }
        }
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
                    val detected = channel.detected_language?.takeIf { it.isNotBlank() }
                    Log.d(TAG, "Transcription received: ${transcript.length} chars, detected=$detected")
                    TranscriptionResult.Success(transcript, detectedLanguage = detected)
                }
            }
        } else {
            Log.w(TAG, "Transcription API error: ${response.status}")
            TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
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
        private const val TAG = "DeepgramTranscriptionService"
        private const val HARD_CAP_MS = 2 * 60 * 1_000L
        private const val MIN_FILE_SIZE_BYTES = 1_024L
        private const val MAX_FILE_SIZE_BYTES = 10 * 1_024 * 1_024L  // 10 MB
        private const val MAX_UPLOAD_RETRIES = 3
        private const val RETRY_BASE_DELAY_MS = 1_000L
        private val jsonParser = Json { ignoreUnknownKeys = true }
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
