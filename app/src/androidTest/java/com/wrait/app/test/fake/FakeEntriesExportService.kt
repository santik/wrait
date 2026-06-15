package com.wrait.app.test.fake

import com.wrait.app.domain.export.EntriesExportResult
import com.wrait.app.domain.export.EntriesExportService

class FakeEntriesExportService : EntriesExportService {
    var result: EntriesExportResult = EntriesExportResult.Success("wrait-export-test.csv")
    var exportCallCount: Int = 0
        private set

    override suspend fun exportFinalizedEntries(): EntriesExportResult {
        exportCallCount += 1
        return result
    }

    fun reset() {
        result = EntriesExportResult.Success("wrait-export-test.csv")
        exportCallCount = 0
    }
}
