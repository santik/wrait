package com.wrait.app.data.repository

import com.wrait.app.data.EntryDao
import com.wrait.app.data.EntryEntity
import com.wrait.app.domain.util.TimeProvider
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files

class EntryRepositoryImplTest {

    @Test
    fun deleteEntries_audioDraft_removesAudioFileFromDisk() = runBlocking {
        val dao = FakeEntryDao()
        val repository = EntryRepositoryImpl(
            entryDao = dao,
            timeProvider = FixedTimeProvider(1_700_000_000_000L),
        )
        val audioFile = Files.createTempFile("wrait-audio-draft-", ".m4a").toFile().apply {
            writeBytes(byteArrayOf(1, 2, 3))
        }

        val id = repository.saveAudioDraft(audioFile.absolutePath, "en-US")
        assertTrue(audioFile.exists())

        repository.deleteEntries(listOf(id))

        assertFalse(audioFile.exists())
    }

    private class FixedTimeProvider(
        private val now: Long,
    ) : TimeProvider {
        override fun currentTimeMillis(): Long = now
    }

    private class FakeEntryDao : EntryDao {
        private val entries = linkedMapOf<Long, EntryEntity>()
        private var nextId = 1L

        override suspend fun insert(entry: EntryEntity): Long {
            val id = if (entry.id == 0L) nextId++ else entry.id
            entries[id] = entry.copy(id = id)
            return id
        }

        override suspend fun update(entry: EntryEntity) {
            entries[entry.id] = entry
        }

        override fun getAllEntries(): Flow<List<EntryEntity>> =
            flowOf(entries.values.sortedByDescending { it.createdAt })

        override suspend fun getPendingDrafts(): List<EntryEntity> =
            entries.values.filter { it.isDraft }

        override suspend fun updateCleanedText(id: Long, cleanedText: String, wordCount: Int): Int {
            val current = entries[id] ?: return 0
            entries[id] = current.copy(cleanedText = cleanedText, wordCount = wordCount, isDraft = false, audioPath = null)
            return 1
        }

        override suspend fun updateDraftTranscript(id: Long, rawTranscript: String, wordCount: Int): Int {
            val current = entries[id] ?: return 0
            entries[id] = current.copy(rawTranscript = rawTranscript, wordCount = wordCount, audioPath = null)
            return 1
        }

        override suspend fun finalizeDraftWithCleanedText(
            id: Long,
            rawTranscript: String,
            cleanedText: String,
            wordCount: Int,
        ): Int {
            val current = entries[id] ?: return 0
            entries[id] = current.copy(
                rawTranscript = rawTranscript,
                cleanedText = cleanedText,
                wordCount = wordCount,
                isDraft = false,
                audioPath = null,
            )
            return 1
        }

        override fun getEntryById(id: Long): Flow<EntryEntity?> = flowOf(entries[id])

        override suspend fun getEntryByIdOnce(id: Long): EntryEntity? = entries[id]

        override suspend fun updateEntryLanguage(id: Long, language: String): Int {
            val current = entries[id] ?: return 0
            entries[id] = current.copy(language = language)
            return 1
        }

        override suspend fun deleteDraftsOlderThan(timestamp: Long) {
            val ids = entries.values
                .filter { it.isDraft && it.createdAt < timestamp }
                .map { it.id }
            ids.forEach(entries::remove)
        }

        override suspend fun deleteEntries(ids: List<Long>) {
            ids.forEach(entries::remove)
        }

        override suspend fun deleteAllEntries() {
            entries.clear()
        }

        override suspend fun getAudioPathsByIds(ids: List<Long>): List<String> =
            ids.mapNotNull { id -> entries[id]?.audioPath }

        override suspend fun getDraftAudioPathsOlderThan(timestamp: Long): List<String> =
            entries.values
                .filter { it.isDraft && it.createdAt < timestamp }
                .mapNotNull { it.audioPath }
    }
}
