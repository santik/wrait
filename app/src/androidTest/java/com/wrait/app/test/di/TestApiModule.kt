package com.wrait.app.test.di

import com.wrait.app.data.api.OpenAiApiService
import com.wrait.app.di.ApiModule
import com.wrait.app.test.fake.FakeOpenAiApiService
import dagger.Module
import dagger.Provides
import dagger.hilt.components.SingletonComponent
import dagger.hilt.testing.TestInstallIn
import javax.inject.Singleton

@Module
@TestInstallIn(
    components = [SingletonComponent::class],
    replaces = [ApiModule::class]
)
object TestApiModule {

    @Provides
    @Singleton
    fun provideOpenAiApiService(): OpenAiApiService = FakeOpenAiApiService()
}
