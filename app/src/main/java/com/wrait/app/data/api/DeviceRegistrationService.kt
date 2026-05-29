package com.wrait.app.data.api

interface DeviceRegistrationService {
    suspend fun register(deviceId: String): RegistrationResult
}

sealed class RegistrationResult {
    data class Success(
        val quota: RecordQuotaState? = null,
    ) : RegistrationResult()
    data class Failure(val reason: String) : RegistrationResult()
}
