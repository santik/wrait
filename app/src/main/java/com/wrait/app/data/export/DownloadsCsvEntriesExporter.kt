package com.wrait.app.data.export

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import com.wrait.app.di.IoDispatcher
import com.wrait.app.domain.export.EntriesExportResult
import com.wrait.app.domain.export.EntriesExportService
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.util.TimeProvider
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import java.io.OutputStream
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext

@Singleton
class DownloadsCsvEntriesExporter @Inject constructor(
    private val entryRepository: EntryRepository,
    private val timeProvider: TimeProvider,
    private val downloadsCsvWriter: DownloadsCsvWriter,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : EntriesExportService {

    override suspend fun exportFinalizedEntries(): EntriesExportResult = withContext(ioDispatcher) {
        try {
            val fileName = EntriesCsvExportFormat.exportFileName(timeProvider.currentTimeMillis())
            val finalizedEntries = entryRepository.getAllEntries()
                .first()
                .filter { entry -> !entry.isDraft }
            val csv = EntriesCsvExportFormat.entriesToCsv(finalizedEntries)

            downloadsCsvWriter.writeCsvToDownloads(
                fileName = fileName,
                csv = csv,
            )

            EntriesExportResult.Success(fileName)
        } catch (e: Exception) {
            EntriesExportResult.Failure(e.message)
        }
    }
}

interface DownloadsCsvWriter {
    fun writeCsvToDownloads(fileName: String, csv: String)
}

@Singleton
class AndroidDownloadsCsvWriter @Inject constructor(
    @ApplicationContext private val context: Context,
) : DownloadsCsvWriter {
    override fun writeCsvToDownloads(fileName: String, csv: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            context.contentResolver.writeCsvWithMediaStore(fileName, csv)
        } else {
            writeCsvToLegacyDownloads(fileName, csv)
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun ContentResolver.writeCsvWithMediaStore(fileName: String, csv: String) {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, "text/csv")
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Could not create export file in Downloads")

        try {
            openOutputStream(uri)?.use { outputStream ->
                outputStream.writeCsv(csv)
            } ?: throw IllegalStateException("Could not open export file")
            markDownloadReady(uri)
        } catch (e: Exception) {
            markDownloadReady(uri)
            throw e
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun ContentResolver.markDownloadReady(uri: Uri) {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.IS_PENDING, 0)
        }
        update(uri, values, null, null)
    }

    private fun writeCsvToLegacyDownloads(fileName: String, csv: String) {
        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!downloadsDir.exists() && !downloadsDir.mkdirs()) {
            throw IllegalStateException("Could not create Downloads directory")
        }

        File(downloadsDir, fileName).outputStream().use { outputStream ->
            outputStream.writeCsv(csv)
        }
    }

    private fun OutputStream.writeCsv(csv: String) {
        write(csv.toByteArray(Charsets.UTF_8))
    }
}

internal object EntriesCsvExportFormat {
    fun exportFileName(timestampMillis: Long): String {
        val timestamp = FILE_TIMESTAMP_FORMATTER.format(
            Instant.ofEpochMilli(timestampMillis).atZone(ZoneId.systemDefault()),
        )
        return "wrait-export-$timestamp.csv"
    }

    fun entriesToCsv(entries: List<Entry>): String {
        return buildString {
            appendLine(CSV_HEADERS.joinToString(","))
            entries.forEach { entry ->
                appendLine(
                    listOf(
                        entry.rawTranscript,
                        entry.cleanedText.orEmpty(),
                        entry.isDraft.toString(),
                        entry.language,
                        entry.createdAt.toString(),
                        entry.wordCount.toString(),
                        entry.audioPath.orEmpty(),
                    ).joinToString(",") { value -> value.toCsvCell() },
                )
            }
        }
    }

    private fun String.toCsvCell(): String {
        val escaped = replace("\"", "\"\"")
        return "\"$escaped\""
    }

    private val CSV_HEADERS = listOf(
        "rawTranscript",
        "cleanedText",
        "isDraft",
        "language",
        "createdAt",
        "wordCount",
        "audioPath",
    )

    private val FILE_TIMESTAMP_FORMATTER: DateTimeFormatter =
        DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss")
}
