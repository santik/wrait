package com.wrait.app.test.fake

import com.wrait.app.data.api.DeviceRegistrationService
import com.wrait.app.data.api.RegistrationResult

class FakeDeviceRegistrationService : DeviceRegistrationService {
    var result: RegistrationResult = RegistrationResult.Success
    var callCount: Int = 0
    var lastDeviceId: String? = null
    var shouldThrow: Boolean = false

    override suspend fun register(deviceId: String): RegistrationResult {
        callCount++
        lastDeviceId = deviceId
        if (shouldThrow) throw RuntimeException("FakeDeviceRegistrationService: forced exception")
        return result
    }
}
