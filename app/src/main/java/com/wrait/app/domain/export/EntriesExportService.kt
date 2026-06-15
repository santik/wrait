package com.wrait.app.domain.export

interface EntriesExportService {
    suspend fun exportFinalizedEntries(): EntriesExportResult
}

sealed interface EntriesExportResult {
    data class Success(val fileName: String) : EntriesExportResult
    data class Failure(val message: String? = null) : EntriesExportResult
}
