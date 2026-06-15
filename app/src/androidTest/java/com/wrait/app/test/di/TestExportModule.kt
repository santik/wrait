package com.wrait.app.test.di

import com.wrait.app.di.ExportModule
import com.wrait.app.domain.export.EntriesExportService
import com.wrait.app.test.fake.FakeEntriesExportService
import dagger.Module
import dagger.Provides
import dagger.hilt.components.SingletonComponent
import dagger.hilt.testing.TestInstallIn
import javax.inject.Singleton

@Module
@TestInstallIn(
    components = [SingletonComponent::class],
    replaces = [ExportModule::class],
)
object TestExportModule {

    @Provides
    @Singleton
    fun provideEntriesExportService(): EntriesExportService = FakeEntriesExportService()
}
