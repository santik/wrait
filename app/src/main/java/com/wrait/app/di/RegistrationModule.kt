package com.wrait.app.di

import com.wrait.app.data.api.DeviceRegistrationService
import com.wrait.app.data.api.WraitBackendClient
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RegistrationModule {
    @Binds
    @Singleton
    @Suppress("unused") // Hilt resolves this binding at compile time via KSP
    abstract fun bindDeviceRegistrationService(
        client: WraitBackendClient
    ): DeviceRegistrationService
}
