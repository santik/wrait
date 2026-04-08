package com.wrait.app.test.di

import com.wrait.app.data.speech.TranscriptionService
import com.wrait.app.di.TranscriptionModule
import com.wrait.app.test.fake.FakeTranscriptionService
import dagger.Module
import dagger.Provides
import dagger.hilt.components.SingletonComponent
import dagger.hilt.testing.TestInstallIn
import javax.inject.Singleton

@Module
@TestInstallIn(
    components = [SingletonComponent::class],
    replaces = [TranscriptionModule::class]
)
object TestTranscriptionModule {

    @Provides
    @Singleton
    fun provideTranscriptionService(): TranscriptionService = FakeTranscriptionService()
}
