package com.wrait.app.di

import com.wrait.app.data.repository.EntryRepositoryImpl
import com.wrait.app.data.util.SystemTimeProvider
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.util.TimeProvider
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindEntryRepository(
        entryRepositoryImpl: EntryRepositoryImpl
    ): EntryRepository

    @Binds
    @Singleton
    abstract fun bindTimeProvider(
        systemTimeProvider: SystemTimeProvider
    ): TimeProvider
}
