package com.wrait.app.di

import com.wrait.app.data.api.OkHttpTranscribeUploadClient
import com.wrait.app.data.api.TranscribeUploadClient
import com.wrait.app.data.api.TranscriptCleanupService
import com.wrait.app.data.api.TranscriptCleanupServiceImpl
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class ApiModule {
    @Suppress("unused")
    @Binds
    @Singleton
    abstract fun bindTranscriptCleanupService(impl: TranscriptCleanupServiceImpl): TranscriptCleanupService

    @Suppress("unused")
    @Binds
    @Singleton
    abstract fun bindTranscribeUploadClient(impl: OkHttpTranscribeUploadClient): TranscribeUploadClient
}
