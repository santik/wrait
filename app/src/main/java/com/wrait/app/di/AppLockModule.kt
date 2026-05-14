package com.wrait.app.di

import com.wrait.app.lock.AndroidAppLockAuthenticatorFactory
import com.wrait.app.lock.AppLockAuthenticatorFactory
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
@Suppress("unused")
abstract class AppLockModule {
    @Binds
    @Singleton
    @Suppress("unused")
    abstract fun bindAppLockAuthenticatorFactory(
        impl: AndroidAppLockAuthenticatorFactory,
    ): AppLockAuthenticatorFactory
}
