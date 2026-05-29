package com.wrait.app.domain.usecase

import com.wrait.app.data.api.DeviceRegistrationService
import com.wrait.app.data.api.RegistrationResult
import com.wrait.app.data.device.DeviceIdProvider
import com.wrait.app.di.IoDispatcher
import com.wrait.app.domain.repository.PreferencesRepository
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import javax.inject.Inject

class RegisterDeviceUseCase @Inject constructor(
    private val preferencesRepository: PreferencesRepository,
    private val deviceIdProvider: DeviceIdProvider,
    private val registrationService: DeviceRegistrationService,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) {
    suspend operator fun invoke(): RegistrationResult {
        if (preferencesRepository.deviceRegistered.first()) return RegistrationResult.Success()
        val deviceId = withContext(ioDispatcher) { deviceIdProvider.getOrStore() }
        val result = registrationService.register(deviceId)
        if (result is RegistrationResult.Success) {
            //TODO enable marking device as registered and enable test
//            preferencesRepository.setDeviceRegistered(true)
        }
        return result
    }
}
