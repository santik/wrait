package com.wrait.app.data.api

import android.util.Log
import com.wrait.app.data.api.generated.api.DefaultApi
import com.wrait.app.data.api.generated.model.CleanupRequest
import kotlinx.coroutines.delay
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class WraitBackendClient @Inject constructor(
    private val api: DefaultApi,
) : DeviceRegistrationService {

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

    private fun shouldRetryRegisterHttp(code: Int): Boolean = code >= 500

    private fun registerRetryDelayMs(attempt: Int): Long = BASE_REGISTER_RETRY_DELAY_MS * (1L shl attempt)

    private companion object {
        const val TAG = "WraitBackendClient"
        const val MAX_REGISTER_RETRIES = 3
        const val BASE_REGISTER_RETRY_DELAY_MS = 1_000L
    }
}
