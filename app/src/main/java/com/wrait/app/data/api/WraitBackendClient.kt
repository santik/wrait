package com.wrait.app.data.api

import android.util.Log
import com.wrait.app.BuildConfig
import com.wrait.app.data.device.DeviceIdProvider
import com.wrait.app.di.IoDispatcher
import io.ktor.client.HttpClient
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.engine.android.Android
import io.ktor.client.plugins.HttpRequestTimeoutException
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.isSuccess
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class WraitBackendClient private constructor(
    private val client: HttpClient,
    private val deviceIdProvider: DeviceIdProvider?,
    private val overrideDeviceId: String? = null,
    private val ioDispatcher: CoroutineDispatcher,
) : DeviceRegistrationService {

    @Inject constructor(
        deviceIdProvider: DeviceIdProvider,
        @IoDispatcher ioDispatcher: CoroutineDispatcher,
    ) : this(
        HttpClient(Android) {
            install(HttpTimeout) {
                requestTimeoutMillis = REQUEST_TIMEOUT_MS
                connectTimeoutMillis = CONNECT_TIMEOUT_MS
            }
        },
        deviceIdProvider,
        null,
        ioDispatcher,
    )

    // Test constructor — injects a MockEngine and an optional fixed device ID.
    internal constructor(
        engine: HttpClientEngine,
        overrideDeviceId: String? = null,
        ioDispatcher: CoroutineDispatcher,
    ) : this(
        HttpClient(engine) {
            install(HttpTimeout) {
                requestTimeoutMillis = REQUEST_TIMEOUT_MS
                connectTimeoutMillis = CONNECT_TIMEOUT_MS
            }
        },
        null,
        overrideDeviceId,
        ioDispatcher,
    )

    // region — /api/register

    override suspend fun register(deviceId: String): RegistrationResult {
        return try {
            val response: HttpResponse = client.post("${BuildConfig.BACKEND_URL}/api/register") {
                addCommonHeaders(deviceId)
            }
            if (response.status.isSuccess()) {
                Log.d(TAG, "Device registration succeeded")
                RegistrationResult.Success
            } else {
                Log.w(TAG, "Device registration failed: HTTP ${response.status.value}")
                RegistrationResult.Failure("http ${response.status.value}")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Device registration request failed: ${e.javaClass.simpleName}: ${e.message}")
            RegistrationResult.Failure("network error")
        }
    }

    // endregion

    // region — /api/transcribe

    suspend fun transcribe(audioBytes: ByteArray): HttpResponse {
        val deviceId = withContext(ioDispatcher) {
            overrideDeviceId ?: deviceIdProvider?.getOrStore() ?: error("DeviceIdProvider not available")
        }
        Log.d(TAG, "Transcribing ${audioBytes.size} bytes with Deepgram auto-detect enabled")
        return try {
            client.post("${BuildConfig.BACKEND_URL}/api/transcribe") {
                addCommonHeaders(deviceId)
                header(HttpHeaders.ContentType, "audio/mp4")
                // Auto-detect strategy: do not pass a hard language constraint to Deepgram.
                DeepgramRequestParams.asPairs().forEach { (name, value) ->
                    parameter(name, value)
                }
                setBody(audioBytes)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Transcription request failed: ${e.javaClass.simpleName}: ${e.message}")
            throw e
        }
    }

    // endregion

    // region — /api/cleanup

    suspend fun cleanupTranscript(
        transcript: String,
        language: String,
        deviceId: String,
    ): CleanupResult {
        return try {
            val response: HttpResponse = client.post("${BuildConfig.BACKEND_URL}/api/cleanup") {
                addCommonHeaders(deviceId)
                header(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                setBody(
                    buildJsonObject {
                        put("transcript", transcript)
                        put("language", language)
                    }.toString()
                )
            }

            if (!response.status.isSuccess()) {
                Log.w(TAG, "Cleanup failed: HTTP ${response.status.value}")
                return CleanupResult.Failure("http ${response.status.value}")
            }

            val body = response.bodyAsText()
            val cleanedText = runCatching {
                jsonParser.parseToJsonElement(body)
                    .jsonObject["cleanedText"]
                    ?.jsonPrimitive
                    ?.contentOrNull
            }.getOrNull()

            if (cleanedText.isNullOrBlank()) {
                Log.w(TAG, "Cleanup succeeded but cleanedText was missing/blank")
                CleanupResult.Failure("invalid response")
            } else {
                CleanupResult.Success(cleanedText)
            }
        } catch (e: HttpRequestTimeoutException) {
            Log.w(TAG, "Cleanup request timed out")
            CleanupResult.Failure("timeout")
        } catch (e: Exception) {
            Log.w(TAG, "Cleanup request failed: ${e.javaClass.simpleName}: ${e.message}")
            CleanupResult.Failure("network error")
        }
    }

    // endregion

    private fun HttpRequestBuilder.addCommonHeaders(deviceId: String) {
        header("X-Device-Id", deviceId)
        header("X-Proxy-Secret", BuildConfig.PROXY_SECRET)
    }

    private companion object {
        const val TAG = "WraitBackendClient"
        const val REQUEST_TIMEOUT_MS = 60_000L
        const val CONNECT_TIMEOUT_MS = 10_000L
        val jsonParser = Json { ignoreUnknownKeys = true }
    }
}
