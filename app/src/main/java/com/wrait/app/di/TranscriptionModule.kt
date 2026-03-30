package com.wrait.app.di

import com.wrait.app.BuildConfig
import com.wrait.app.data.speech.AndroidTranscriptionService
import com.wrait.app.data.speech.TranscriptionService
import com.wrait.app.data.speech.WhisperTranscriptionService
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
        androidService: AndroidTranscriptionService,
        whisperService: WhisperTranscriptionService
    ): TranscriptionService =
        if (BuildConfig.STT_BACKEND == "whisper") whisperService else androidService
}
