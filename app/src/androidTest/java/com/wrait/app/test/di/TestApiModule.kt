package com.wrait.app.test.di

import com.wrait.app.data.api.DeviceRegistrationService
import com.wrait.app.data.api.TranscriptCleanupService
import com.wrait.app.di.ApiModule
import com.wrait.app.di.RegistrationModule
import com.wrait.app.test.fake.FakeDeviceRegistrationService
import com.wrait.app.test.fake.FakeTranscriptCleanupService
import dagger.Module
import dagger.Provides
import dagger.hilt.components.SingletonComponent
import dagger.hilt.testing.TestInstallIn
import javax.inject.Singleton

@Module
@TestInstallIn(
    components = [SingletonComponent::class],
    replaces = [ApiModule::class, RegistrationModule::class]
)
object TestApiModule {

    @Provides
    @Singleton
    fun provideTranscriptCleanupService(): TranscriptCleanupService = FakeTranscriptCleanupService()

    @Provides
    @Singleton
    fun provideDeviceRegistrationService(): DeviceRegistrationService =
        FakeDeviceRegistrationService()
}
