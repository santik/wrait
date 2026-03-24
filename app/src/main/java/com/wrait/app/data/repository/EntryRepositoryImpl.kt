package com.wrait.app.data.repository

import com.wrait.app.data.EntryDao
import com.wrait.app.data.EntryEntity
import com.wrait.app.data.mapper.toDomain
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.repository.EntryRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class EntryRepositoryImpl @Inject constructor(
    private val entryDao: EntryDao
) : EntryRepository {

    override suspend fun saveDraft(transcript: String, language: String): Long {
        val calculatedWordCount = transcript.trim().split(Regex("\\s+")).count { it.isNotEmpty() }
        val entity = EntryEntity(
            rawTranscript = transcript,
            cleanedText = null,
            isDraft = true,
            language = language,
            createdAt = System.currentTimeMillis(),
            wordCount = calculatedWordCount
        )
        return entryDao.insert(entity)
    }

    override suspend fun updateWithCleanedText(id: Long, text: String, wordCount: Int) {
        val affectedRows = entryDao.updateCleanedText(id, text, wordCount)
        if (affectedRows == 0) {
            throw IllegalArgumentException("Entry with id $id not found or already deleted")
        }
    }

    override fun getAllEntries(): Flow<List<Entry>> {
        return entryDao.getAllEntries().map { list ->
            list.map { it.toDomain() }
        }
    }

    override suspend fun getPendingDrafts(): List<Entry> {
        return entryDao.getPendingDrafts().map { it.toDomain() }
    }
}
