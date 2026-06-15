package com.wrait.app.di

import com.wrait.app.data.export.AndroidDownloadsCsvWriter
import com.wrait.app.data.export.DownloadsCsvEntriesExporter
import com.wrait.app.data.export.DownloadsCsvWriter
import com.wrait.app.domain.export.EntriesExportService
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class ExportModule {
    @Binds
    @Singleton
    abstract fun bindEntriesExportService(
        exporter: DownloadsCsvEntriesExporter,
    ): EntriesExportService

    @Binds
    @Singleton
    abstract fun bindDownloadsCsvWriter(
        writer: AndroidDownloadsCsvWriter,
    ): DownloadsCsvWriter
}
