package com.wrait.app.data.api

import android.util.Log
import com.wrait.app.data.device.DeviceIdProvider
import com.wrait.app.di.IoDispatcher
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import javax.inject.Inject

/**
 * Proxy-only transcript cleanup service.
 */
class TranscriptCleanupServiceImpl @Inject constructor(
    private val wraitBackendClient: WraitBackendClient,
    private val deviceIdProvider: DeviceIdProvider,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : TranscriptCleanupService {

    override suspend fun cleanupTranscript(rawText: String, language: String): CleanupResult {
        val normalized = rawText.trim()
        if (normalized.isEmpty()) return CleanupResult.Failure("empty transcript")
        val boundedTranscript = if (normalized.length > MAX_TRANSCRIPT_LENGTH) {
            Log.i(TAG, "Truncating transcript from ${normalized.length} to $MAX_TRANSCRIPT_LENGTH chars")
            normalized.take(MAX_TRANSCRIPT_LENGTH)
        } else {
            normalized
        }

        val deviceId = try {
            withContext(ioDispatcher) { deviceIdProvider.getOrStore() }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read device id for cleanup routing", e)
            return CleanupResult.Failure("device id error")
        }

        repeat(MAX_RETRIES) { attempt ->
            val result = wraitBackendClient.cleanupTranscript(
                transcript = boundedTranscript,
                language = language,
                deviceId = deviceId,
            )
            if (result is CleanupResult.Success) return result

            val reason = (result as CleanupResult.Failure).reason
            val isLastAttempt = attempt == MAX_RETRIES - 1
            if (!shouldRetry(reason) || isLastAttempt) return result

            val delayMs = BASE_RETRY_DELAY_MS shl attempt
            Log.w(TAG, "Cleanup failed transiently ($reason), retrying in ${delayMs}ms")
            delay(delayMs.toLong())
        }

        return CleanupResult.Failure("network error")
    }

    private fun shouldRetry(reason: String): Boolean {
        if (reason == "timeout" || reason == "network error") return true
        if (!reason.startsWith("http ")) return false
        val code = reason.removePrefix("http ").toIntOrNull() ?: return false
        return code >= 500
    }

    private companion object {
        const val TAG = "TranscriptCleanupService"
        const val MAX_TRANSCRIPT_LENGTH = 3_000
        const val MAX_RETRIES = 3
        const val BASE_RETRY_DELAY_MS = 500
    }
}
