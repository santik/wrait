package com.wrait.app.di

import com.wrait.app.data.api.OpenAiApiService
import com.wrait.app.data.api.OpenAiApiServiceImpl
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class ApiModule {
    @Binds
    @Singleton
    abstract fun bindOpenAiApiService(impl: OpenAiApiServiceImpl): OpenAiApiService
}
