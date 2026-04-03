package com.wrait.app.di

import com.wrait.app.data.speech.ModeAwareTranscriptionService
import com.wrait.app.data.speech.TranscriptionService
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object TranscriptionModule {

    @Provides
    @Singleton
    fun provideTranscriptionService(
        service: ModeAwareTranscriptionService,
    ): TranscriptionService = service
}
