package com.wrait.app.test.di

import com.wrait.app.data.device.NetworkAvailability
import com.wrait.app.di.ConnectivityModule
import com.wrait.app.test.fake.FakeNetworkAvailability
import dagger.Module
import dagger.Provides
import dagger.hilt.components.SingletonComponent
import dagger.hilt.testing.TestInstallIn
import javax.inject.Singleton

@Module
@TestInstallIn(
    components = [SingletonComponent::class],
    replaces = [ConnectivityModule::class],
)
object TestConnectivityModule {

    @Provides
    @Singleton
    fun provideNetworkAvailability(): NetworkAvailability = FakeNetworkAvailability(isAvailable = true)
}
