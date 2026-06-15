package com.wrait.app.di

import com.wrait.app.data.config.BuildConfigDevModeProvider
import com.wrait.app.domain.config.DevModeProvider
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class ConfigModule {
    @Binds
    @Singleton
    abstract fun bindDevModeProvider(
        provider: BuildConfigDevModeProvider,
    ): DevModeProvider
}
