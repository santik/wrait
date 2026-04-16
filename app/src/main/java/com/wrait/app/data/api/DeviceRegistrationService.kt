package com.wrait.app.data.api

interface DeviceRegistrationService {
    suspend fun register(deviceId: String): RegistrationResult
}

sealed class RegistrationResult {
    data object Success : RegistrationResult()
    data class Failure(val reason: String) : RegistrationResult()
}
