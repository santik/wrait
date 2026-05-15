package com.wrait.app.data.api

import android.util.Log
import com.wrait.app.data.api.generated.api.DefaultApi
import com.wrait.app.data.api.generated.model.CleanupRequest
import com.wrait.app.data.api.generated.model.TranscribeResponse
import com.wrait.app.data.device.DeviceIdProvider
import com.wrait.app.di.IoDispatcher
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import retrofit2.Response
import java.io.File
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton
import com.wrait.app.data.speech.TranscriptionFailureReason
import com.wrait.app.data.speech.TranscriptionResult
import com.wrait.app.domain.model.normalizeDetectedLanguageCode
import kotlinx.serialization.SerializationException

@Singleton
class WraitBackendClient private constructor(
    private val api: DefaultApi,
    private val resolveDeviceId: suspend () -> String,
) : DeviceRegistrationService {

    @Inject constructor(
        api: DefaultApi,
        deviceIdProvider: DeviceIdProvider,
        @IoDispatcher ioDispatcher: CoroutineDispatcher,
    ) : this(
        api = api,
        resolveDeviceId = {
            withContext(ioDispatcher) { deviceIdProvider.getOrStore() }
        },
    )

    override suspend fun register(deviceId: String): RegistrationResult {
        repeat(MAX_REGISTER_RETRIES) { attempt ->
            try {
                val response = api.registerDevice(deviceId)
                if (response.isSuccessful) {
                    Log.d(TAG, "Device registration succeeded")
                    return RegistrationResult.Success
                }

                val backendError = BackendErrorParser.parseRaw(response.errorBody()?.string())
                Log.w(TAG, "Device registration failed: HTTP ${response.code()}${backendError?.let { ", error=$it" } ?: ""}")
                val result = RegistrationResult.Failure("http ${response.code()}")
                if (!shouldRetryRegisterHttp(response.code()) || attempt == MAX_REGISTER_RETRIES - 1) {
                    return result
                }
                Log.w(TAG, "Device registration failed transiently (${response.code()}), retrying in ${registerRetryDelayMs(attempt)}ms")
                delay(registerRetryDelayMs(attempt))
            } catch (e: IOException) {
                val result = if (e.isNetworkTimeout()) {
                    Log.w(TAG, "Device registration timed out")
                    RegistrationResult.Failure("timeout")
                } else {
                    Log.w(TAG, "Device registration request failed: ${e.javaClass.simpleName}: ${e.message}")
                    RegistrationResult.Failure("network error")
                }
                if (attempt == MAX_REGISTER_RETRIES - 1) {
                    return result
                }
                Log.w(TAG, "Device registration failed transiently (${result.reason}), retrying in ${registerRetryDelayMs(attempt)}ms")
                delay(registerRetryDelayMs(attempt))
            } catch (e: Exception) {
                Log.e(TAG, "Device registration failed unexpectedly", e)
                return RegistrationResult.Failure("unexpected error")
            }
        }
        return RegistrationResult.Failure("network error")
    }

    suspend fun cleanupTranscript(
        transcript: String,
        language: String,
        deviceId: String,
    ): CleanupResult {
        val cleanupLanguage = CleanupRequest.Language.entries.firstOrNull {
            it.value.equals(language, ignoreCase = true)
        }
        if (cleanupLanguage == null) {
            Log.w(TAG, "Cleanup requested with unsupported language: $language")
            return CleanupResult.Failure("unsupported language")
        }

        return try {
            val response = api.cleanupTranscript(
                xDeviceId = deviceId,
                cleanupRequest = CleanupRequest(
                    transcript = transcript,
                    language = cleanupLanguage,
                ),
            )

            if (!response.isSuccessful) {
                val backendError = BackendErrorParser.parseRaw(response.errorBody()?.string())
                Log.w(TAG, "Cleanup failed: HTTP ${response.code()}${backendError?.let { ", error=$it" } ?: ""}")
                return CleanupResult.Failure("http ${response.code()}")
            }

            val body = response.body()
            val cleanedText = body?.cleanedText?.trim()
            if (cleanedText.isNullOrEmpty()) {
                Log.w(TAG, "Cleanup succeeded but cleanedText was missing/blank")
                CleanupResult.Failure("invalid response")
            } else {
                if (body.wasTruncated) {
                    Log.i(TAG, "Cleanup response indicates the transcript was truncated server-side")
                }
                CleanupResult.Success(cleanedText)
            }
        } catch (e: IOException) {
            if (e.isNetworkTimeout()) {
                Log.w(TAG, "Cleanup request timed out")
                CleanupResult.Failure("timeout")
            } else {
                Log.w(TAG, "Cleanup request failed: ${e.javaClass.simpleName}: ${e.message}")
                CleanupResult.Failure("network error")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Cleanup request failed unexpectedly", e)
            CleanupResult.Failure("unexpected error")
        }
    }

    suspend fun transcribeAudio(
        audioFile: File,
    ): TranscriptionResult {
        val deviceId = try {
            resolveDeviceId.invoke()
        } catch (e: Exception) {
            Log.e(TAG, "Transcribe upload could not resolve device id", e)
            return TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
        }

        repeat(MAX_TRANSCRIBE_RETRIES) { attempt ->
            try {
                val response = api.transcribeAudio(
                    xDeviceId = deviceId,
                    audio = createAudioPart(audioFile),
                )
                return parseTranscribeResponse(response)
            } catch (e: IOException) {
                val isLastAttempt = attempt == MAX_TRANSCRIBE_RETRIES - 1
                // For transcription, a timeout means the backend never produced a usable
                // transcript response, so we surface it as backend unavailability rather than
                // a stringly transport detail like the registration path does.
                if (e.isNetworkTimeout()) {
                    Log.w(TAG, "Transcribe request timed out (attempt ${attempt + 1}/$MAX_TRANSCRIBE_RETRIES)")
                    if (isLastAttempt) {
                        return TranscriptionResult.Failure(TranscriptionFailureReason.BackendUnavailable)
                    }
                } else {
                    Log.w(TAG, "Transcribe request failed: ${e.javaClass.simpleName}: ${e.message}")
                    if (isLastAttempt) {
                        return TranscriptionResult.Failure(TranscriptionFailureReason.NetworkError)
                    }
                }
                val delayMs = transcribeRetryDelayMs(attempt)
                Log.w(TAG, "Transcribe failed transiently, retrying in ${delayMs}ms")
                delay(delayMs)
            } catch (e: SerializationException) {
                Log.w(TAG, "Transcribe response could not be parsed: ${e.message}")
                return TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
            } catch (e: Exception) {
                Log.e(TAG, "Transcribe request failed unexpectedly", e)
                return TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
            }
        }

        return TranscriptionResult.Failure(TranscriptionFailureReason.NetworkError)
    }

    private fun shouldRetryRegisterHttp(code: Int): Boolean = code >= 500

    private fun registerRetryDelayMs(attempt: Int): Long = BASE_REGISTER_RETRY_DELAY_MS * (1L shl attempt)

    private fun transcribeRetryDelayMs(attempt: Int): Long = BASE_TRANSCRIBE_RETRY_DELAY_MS * (1L shl attempt)

    private fun transcribeFailureReasonForStatus(statusCode: Int): TranscriptionFailureReason {
        return when {
            statusCode == 401 || statusCode == 403 -> TranscriptionFailureReason.ProxyAuthFailed
            statusCode >= 500 -> TranscriptionFailureReason.BackendUnavailable
            else -> TranscriptionFailureReason.ApiError
        }
    }

    private fun createAudioPart(audioFile: File): MultipartBody.Part {
        val mediaType = BackendAudioUploadConfig.mediaTypeFor(audioFile)
        return MultipartBody.Part.createFormData(
            name = "audio",
            filename = audioFile.name,
            body = audioFile.asRequestBody(mediaType),
        )
    }

    private fun parseTranscribeResponse(response: Response<TranscribeResponse>): TranscriptionResult {
        if (!response.isSuccessful) {
            val backendError = BackendErrorParser.parseRaw(response.errorBody()?.string())
            val reason = transcribeFailureReasonForStatus(response.code())
            when (reason) {
                TranscriptionFailureReason.ProxyAuthFailed ->
                    Log.w(TAG, "Transcribe auth/config error: HTTP ${response.code()}${backendError?.let { ", error=$it" } ?: ""}")
                TranscriptionFailureReason.BackendUnavailable ->
                    Log.w(TAG, "Transcribe backend unavailable: HTTP ${response.code()}${backendError?.let { ", error=$it" } ?: ""}")
                else ->
                    Log.w(TAG, "Transcribe failed: HTTP ${response.code()}${backendError?.let { ", error=$it" } ?: ""}")
            }
            return TranscriptionResult.Failure(reason)
        }

        val body = response.body()
        if (body == null) {
            Log.w(TAG, "Transcribe succeeded but body was missing")
            return TranscriptionResult.Failure(TranscriptionFailureReason.ApiError)
        }

        val transcript = body.transcript.trim()
        if (transcript.isBlank()) {
            Log.w(TAG, "Transcribe succeeded but transcript was blank")
            return TranscriptionResult.Failure(TranscriptionFailureReason.NothingCaught)
        }

        val detected = body.detectedLanguage.takeIf { it.isNotBlank() }?.let { rawDetected ->
            val normalized = normalizeDetectedLanguageCode(rawDetected)
            if (normalized == null) {
                Log.w(TAG, "Ignoring invalid detected language from backend: $rawDetected")
            }
            normalized
        }

        return TranscriptionResult.Success(
            transcript = transcript,
            detectedLanguage = detected,
        )
    }

    internal companion object {
        private const val TAG = "WraitBackendClient"
        // Three attempts keeps transient failures recoverable without stretching the
        // happy-path UX too far for a single tap-to-record flow.
        private const val MAX_REGISTER_RETRIES = 3
        private const val BASE_REGISTER_RETRY_DELAY_MS = 1_000L
        private const val MAX_TRANSCRIBE_RETRIES = 3
        private const val BASE_TRANSCRIBE_RETRY_DELAY_MS = 1_000L
    }
}
