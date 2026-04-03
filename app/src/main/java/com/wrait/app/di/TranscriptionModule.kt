package com.wrait.app.di

import com.wrait.app.BuildConfig
import com.wrait.app.data.speech.AndroidTranscriptionService
import com.wrait.app.data.speech.DeepgramTranscriptionService
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
    @Suppress("UNREACHABLE_CODE")
    fun provideTranscriptionService(
        deepgramService: DeepgramTranscriptionService,
        androidService: AndroidTranscriptionService,
    ): TranscriptionService = when (BuildConfig.PRIVACY_MODE) {
        "MODE_PRIVATE" -> androidService
        else -> deepgramService
    }
}
