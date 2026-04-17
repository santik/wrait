package com.wrait.app.data.api

import android.util.Log
import com.wrait.app.BuildConfig
import com.wrait.app.data.device.DeviceIdProvider
import io.ktor.client.HttpClient
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.engine.android.Android
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.http.HttpHeaders
import io.ktor.http.isSuccess
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class WraitBackendClient private constructor(
    private val client: HttpClient,
    private val deviceIdProvider: DeviceIdProvider?,
) : DeviceRegistrationService {

    @Inject constructor(deviceIdProvider: DeviceIdProvider) : this(
        HttpClient(Android) {
            install(HttpTimeout) {
                requestTimeoutMillis = REQUEST_TIMEOUT_MS
                connectTimeoutMillis = CONNECT_TIMEOUT_MS
            }
        },
        deviceIdProvider,
    )

    // Secondary constructor for unit tests — injects a MockEngine; device ID is unused in tests.
    internal constructor(engine: HttpClientEngine) : this(
        HttpClient(engine) {
            install(HttpTimeout) {
                requestTimeoutMillis = REQUEST_TIMEOUT_MS
                connectTimeoutMillis = CONNECT_TIMEOUT_MS
            }
        },
        null,
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

    suspend fun transcribe(audioBytes: ByteArray, language: String): HttpResponse {
        val deviceId = withContext(Dispatchers.IO) {
            deviceIdProvider?.getOrStore() ?: error("DeviceIdProvider not available")
        }
        Log.d(TAG, "Transcribing ${audioBytes.size} bytes, language=$language")
        return try {
            client.post("${BuildConfig.BACKEND_URL}/api/transcribe") {
                addCommonHeaders(deviceId)
                header(HttpHeaders.ContentType, "audio/mp4")
                parameter("model", "nova-3")
                parameter("punctuate", "true")
                parameter("smart_format", "true")
                parameter("language", language)
                parameter("detect_language", "true")
                setBody(audioBytes)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Transcription request failed: ${e.javaClass.simpleName}: ${e.message}")
            throw e
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
    }
}
