package com.wrait.app.data.repository

import android.util.Log
import com.wrait.app.data.EntryDao
import com.wrait.app.data.EntryEntity
import com.wrait.app.data.mapper.toDomain
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.util.TimeProvider
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import java.util.concurrent.TimeUnit
import javax.inject.Inject

class EntryRepositoryImpl @Inject constructor(
    private val entryDao: EntryDao,
    private val timeProvider: TimeProvider
) : EntryRepository {

    override suspend fun saveDraft(transcript: String, language: String): Long {
        val calculatedWordCount = transcript.trim().split(Regex("\\s+")).count { it.isNotEmpty() }
        val entity = EntryEntity(
            rawTranscript = transcript,
            cleanedText = null,
            isDraft = true,
            language = language,
            createdAt = timeProvider.currentTimeMillis(),
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

    override fun getEntryById(id: Long): Flow<Result<Entry?>> =
        entryDao.getEntryById(id)
            .map { entity ->
                try {
                    Result.success(entity?.toDomain())
                } catch (e: Exception) {
                    Log.e("EntryRepository", "Failed to map entry $id", e)
                    Result.failure(e)
                }
            }
            .catch { e ->
                Log.e("EntryRepository", "Database error getting entry $id", e)
                emit(Result.failure(e))
            }

    override suspend fun getPendingDrafts(): List<Entry> {
        return entryDao.getPendingDrafts().map { it.toDomain() }
    }

    override suspend fun deleteStaleDrafts(daysOld: Int) {
        require(daysOld >= 0) { "daysOld cannot be negative" }
        val cutoffTimestamp = timeProvider.currentTimeMillis() - TimeUnit.DAYS.toMillis(daysOld.toLong())
        entryDao.deleteDraftsOlderThan(cutoffTimestamp)
    }

    override suspend fun deleteStaleDrafts() {
        deleteStaleDrafts(7)
    }

    override suspend fun deleteEntries(ids: List<Long>) {
        if (ids.isEmpty()) return
        entryDao.deleteEntries(ids)
    }
}
