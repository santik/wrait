package com.wrait.app.data.api

import android.util.Log
import com.wrait.app.BuildConfig
import io.ktor.client.HttpClient
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.engine.android.Android
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.statement.HttpResponse
import io.ktor.http.isSuccess
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class WraitBackendClient private constructor(
    private val client: HttpClient
) : DeviceRegistrationService {

    @Inject constructor() : this(HttpClient(Android) {
        install(HttpTimeout) {
            requestTimeoutMillis = 15_000
            connectTimeoutMillis = 10_000
        }
    })

    // Secondary constructor used in tests to inject a MockEngine.
    internal constructor(engine: HttpClientEngine) : this(HttpClient(engine) {
        install(HttpTimeout) {
            requestTimeoutMillis = 15_000
            connectTimeoutMillis = 10_000
        }
    })

    // region — /api/register

    override suspend fun register(deviceId: String): RegistrationResult {
        return try {
            val response: HttpResponse = client.post("${BuildConfig.BACKEND_URL}/api/register") {
                header("X-Device-Id", deviceId)
                header("X-Proxy-Secret", BuildConfig.PROXY_SECRET)
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

    private companion object {
        const val TAG = "WraitBackendClient"
    }
}
