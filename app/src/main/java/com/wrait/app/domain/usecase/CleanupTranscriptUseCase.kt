package com.wrait.app.domain.usecase

import android.util.Log
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.api.OpenAiApiService
import com.wrait.app.data.api.WraitBackendClient
import com.wrait.app.data.device.DeviceIdProvider
import com.wrait.app.di.IoDispatcher
import com.wrait.app.domain.model.CleanupBackend
import com.wrait.app.domain.repository.PreferencesRepository
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import javax.inject.Inject

class CleanupTranscriptUseCase @Inject constructor(
    private val preferencesRepository: PreferencesRepository,
    private val openAiApiService: OpenAiApiService,
    private val wraitBackendClient: WraitBackendClient,
    private val deviceIdProvider: DeviceIdProvider,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) {
    suspend operator fun invoke(rawText: String, language: String): CleanupResult {
        val backend = preferencesRepository.cleanupBackend.first()
        return when (backend) {
            CleanupBackend.ANDROID -> openAiApiService.cleanupTranscript(rawText)
            CleanupBackend.BACKEND -> {
                val deviceId = try {
                    withContext(ioDispatcher) { deviceIdProvider.getOrStore() }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to read device id for cleanup routing", e)
                    return CleanupResult.Failure("device id error")
                }
                wraitBackendClient.cleanupTranscript(
                    transcript = rawText,
                    language = language,
                    deviceId = deviceId,
                )
            }
        }
    }

    private companion object {
        const val TAG = "CleanupTranscriptUseCase"
    }
}
