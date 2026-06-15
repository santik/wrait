package com.wrait.app.data.export

import com.wrait.app.domain.export.EntriesExportResult
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.util.TimeProvider
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class DownloadsCsvEntriesExporterTest {

    private val dispatcher = UnconfinedTestDispatcher()

    @Test
    fun exportFinalizedEntries_filtersDrafts() = runTest(dispatcher) {
        val writer = FakeDownloadsCsvWriter()
        val exporter = createExporter(
            entries = listOf(
                entry(id = 1, rawTranscript = "final one", isDraft = false),
                entry(id = 2, rawTranscript = "draft one", isDraft = true),
            ),
            writer = writer,
        )

        val result = exporter.exportFinalizedEntries()

        assertTrue(result is EntriesExportResult.Success)
        assertTrue(writer.lastCsv.orEmpty().contains("final one"))
        assertFalse(writer.lastCsv.orEmpty().contains("draft one"))
    }

    @Test
    fun entriesToCsv_excludesIdAndPreservesStoredNonIdentifierFields() {
        val csv = EntriesCsvExportFormat.entriesToCsv(
            listOf(
                entry(
                    id = 777,
                    rawTranscript = "raw text",
                    cleanedText = "clean text",
                    isDraft = false,
                    language = "en-US",
                    createdAt = 123456L,
                    wordCount = 2,
                    audioPath = null,
                ),
            ),
        )

        val lines = csv.trimEnd().lines()
        assertEquals("rawTranscript,cleanedText,isDraft,language,createdAt,wordCount,audioPath", lines[0])
        assertEquals("\"raw text\",\"clean text\",\"false\",\"en-US\",\"123456\",\"2\",\"\"", lines[1])
        assertFalse(csv.contains("777"))
    }

    @Test
    fun entriesToCsv_escapesCommasQuotesAndLineBreaks() {
        val csv = EntriesCsvExportFormat.entriesToCsv(
            listOf(
                entry(
                    rawTranscript = "hello, \"world\"\nnext line",
                    cleanedText = "clean, \"entry\"",
                ),
            ),
        )

        assertTrue(csv.contains("\"hello, \"\"world\"\"\nnext line\""))
        assertTrue(csv.contains("\"clean, \"\"entry\"\"\""))
    }

    @Test
    fun entriesToCsv_emptyEntries_createsHeaderOnlyCsv() {
        val csv = EntriesCsvExportFormat.entriesToCsv(emptyList())

        assertEquals("rawTranscript,cleanedText,isDraft,language,createdAt,wordCount,audioPath", csv.trim())
    }

    @Test
    fun exportFileName_includesTimestamp() {
        val fileName = EntriesCsvExportFormat.exportFileName(timestampMillis = 1_700_000_000_000L)

        assertTrue(Regex("""wrait-export-\d{8}-\d{6}\.csv""").matches(fileName))
    }

    @Test
    fun exportFinalizedEntries_returnsFailureWhenWriterFails() = runTest(dispatcher) {
        val writer = FakeDownloadsCsvWriter(shouldThrow = true)
        val exporter = createExporter(
            entries = listOf(entry(rawTranscript = "final one")),
            writer = writer,
        )

        val result = exporter.exportFinalizedEntries()

        assertTrue(result is EntriesExportResult.Failure)
        assertEquals(1, writer.writeCallCount)
        assertTrue(writer.lastFileName.orEmpty().startsWith("wrait-export-"))
        assertTrue(writer.lastCsv.orEmpty().contains("final one"))
    }

    private fun createExporter(
        entries: List<Entry>,
        writer: FakeDownloadsCsvWriter = FakeDownloadsCsvWriter(),
    ): DownloadsCsvEntriesExporter {
        return DownloadsCsvEntriesExporter(
            entryRepository = FakeEntryRepository(entries),
            timeProvider = object : TimeProvider {
                override fun currentTimeMillis(): Long = 1_700_000_000_000L
            },
            downloadsCsvWriter = writer,
            ioDispatcher = dispatcher,
        )
    }

    private fun entry(
        id: Long = 1L,
        rawTranscript: String = "raw",
        cleanedText: String? = "clean",
        isDraft: Boolean = false,
        language: String = "en-US",
        createdAt: Long = 100L,
        wordCount: Int = 1,
        audioPath: String? = null,
    ) = Entry(
        id = id,
        rawTranscript = rawTranscript,
        cleanedText = cleanedText,
        isDraft = isDraft,
        language = language,
        createdAt = createdAt,
        wordCount = wordCount,
        audioPath = audioPath,
    )

    private class FakeDownloadsCsvWriter(
        private val shouldThrow: Boolean = false,
    ) : DownloadsCsvWriter {
        var writeCallCount = 0
            private set
        var lastFileName: String? = null
            private set
        var lastCsv: String? = null
            private set

        override fun writeCsvToDownloads(fileName: String, csv: String) {
            writeCallCount += 1
            lastFileName = fileName
            lastCsv = csv
            if (shouldThrow) throw IllegalStateException("forced failure")
        }
    }

    private class FakeEntryRepository(
        private val entries: List<Entry>,
    ) : EntryRepository {
        override suspend fun saveDraft(transcript: String, language: String): Long = 0L
        override suspend fun saveEntry(transcript: String, language: String): Long = 0L
        override suspend fun saveAudioDraft(audioPath: String, language: String): Long = 0L
        override suspend fun updateWithCleanedText(id: Long, text: String, wordCount: Int) = Unit
        override suspend fun updateDraftTranscript(id: Long, rawTranscript: String, wordCount: Int) = Unit
        override suspend fun finalizeDraftWithCleanedText(
            id: Long,
            rawTranscript: String,
            cleanedText: String,
            wordCount: Int,
        ) = Unit
        override suspend fun updateEntryLanguage(id: Long, language: String) = Unit
        override fun getAllEntries(): Flow<List<Entry>> = flowOf(entries)
        override fun getEntryById(id: Long): Flow<Result<Entry?>> = flowOf(Result.success(null))
        override suspend fun getEntryByIdOnce(id: Long): Result<Entry?> = Result.success(null)
        override suspend fun getPendingDrafts(): List<Entry> = emptyList()
        override suspend fun deleteStaleDrafts(daysOld: Int) = Unit
        override suspend fun deleteStaleDrafts() = Unit
        override suspend fun deleteEntries(ids: List<Long>) = Unit
    }
}
