package com.wrait.app.di

import com.wrait.app.BuildConfig
import com.wrait.app.data.speech.AndroidTranscriptionService
import com.wrait.app.data.speech.DeepgramTranscriptionService
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
    @Suppress("UNREACHABLE_CODE")
    fun provideTranscriptionService(
        androidService: AndroidTranscriptionService,
        whisperService: WhisperTranscriptionService,
        deepgramService: DeepgramTranscriptionService,
    ): TranscriptionService = when (BuildConfig.STT_BACKEND) {
        "whisper" -> whisperService
        "deepgram" -> deepgramService
        else -> androidService
    }
}
