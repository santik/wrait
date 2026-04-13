package com.wrait.app.data.speech

import android.content.Context
import android.media.MediaRecorder
import android.util.Log
import com.wrait.app.BuildConfig
import dagger.hilt.android.qualifiers.ApplicationContext
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.engine.android.Android
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.HttpHeaders
import io.ktor.serialization.kotlinx.json.json
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

@Singleton
class DeepgramTranscriptionService @Inject constructor(
    @ApplicationContext private val context: Context,
) : TranscriptionService {

    private val client = HttpClient(Android) {
        install(ContentNegotiation) {
            json(Json { ignoreUnknownKeys = true })
        }
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
        if (BuildConfig.DEEPGRAM_API_KEY.isBlank()) {
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

    private suspend fun upload(file: File, languageCode: String): TranscriptionResult {
        val language = languageCode.substringBefore("-")
        val url =
            "https://api.deepgram.com/v1/listen?model=nova-3&punctuate=true&smart_format=true&language=$language&detect_language=true"

        repeat(MAX_UPLOAD_RETRIES) { attempt ->
            try {
                val bytes = withContext(Dispatchers.IO) { file.readBytes() }
                Log.d(TAG, "Uploading ${bytes.size} bytes to Deepgram (attempt ${attempt + 1}/$MAX_UPLOAD_RETRIES)")
                val response = client.post(url) {
                    header(HttpHeaders.Authorization, "Token ${BuildConfig.DEEPGRAM_API_KEY}")
                    header(HttpHeaders.ContentType, "audio/mp4")
                    setBody(bytes)
                }
                return if (response.status.value == 200) {
                    val body = response.body<DeepgramResponse>()
                    if (body.results.channels.isEmpty()) {
                        Log.w(TAG, "Deepgram response has no channels")
                        TranscriptionResult.Failure(TranscriptionFailureReason.NothingCaught)
                    } else {
                        val channel = body.results.channels[0]
                        val transcript = channel.alternatives
                            .firstOrNull()
                            ?.transcript
                            .orEmpty()
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
                    Log.w(TAG, "Deepgram API error: ${response.status}")
                    TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
                }
            } catch (e: IOException) {
                Log.w(TAG, "Deepgram network error (attempt ${attempt + 1}/$MAX_UPLOAD_RETRIES): ${e.message}")
                if (attempt < MAX_UPLOAD_RETRIES - 1) {
                    delay(RETRY_BASE_DELAY_MS shl attempt) // 1 s, 2 s, 4 s
                }
            } catch (e: Exception) {
                Log.w(TAG, "Deepgram upload failed: ${e.javaClass.simpleName}: ${e.message}")
                return TranscriptionResult.Failure(TranscriptionFailureReason.NetworkError)
            }
        }
        return TranscriptionResult.Failure(TranscriptionFailureReason.NetworkError)
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

