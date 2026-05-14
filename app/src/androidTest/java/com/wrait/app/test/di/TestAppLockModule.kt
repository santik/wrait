package com.wrait.app.test.di

import com.wrait.app.di.AppLockModule
import com.wrait.app.lock.AppLockAuthenticatorFactory
import com.wrait.app.test.fake.FakeAppLockAuthenticatorFactory
import dagger.Binds
import dagger.Module
import dagger.hilt.components.SingletonComponent
import dagger.hilt.testing.TestInstallIn
import javax.inject.Singleton

@Module
@TestInstallIn(
    components = [SingletonComponent::class],
    replaces = [AppLockModule::class],
)
@Suppress("unused")
abstract class TestAppLockModule {
    @Binds
    @Singleton
    @Suppress("unused")
    abstract fun bindAppLockAuthenticatorFactory(
        impl: FakeAppLockAuthenticatorFactory,
    ): AppLockAuthenticatorFactory
}
