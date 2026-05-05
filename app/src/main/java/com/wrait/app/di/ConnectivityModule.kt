package com.wrait.app.di

import com.wrait.app.data.device.AndroidNetworkAvailability
import com.wrait.app.data.device.NetworkAvailability
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class ConnectivityModule {

    @Binds
    @Singleton
    abstract fun bindNetworkAvailability(
        impl: AndroidNetworkAvailability,
    ): NetworkAvailability
}
