package com.wrait.app.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface EntryDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entry: EntryEntity): Long

    @Update
    suspend fun update(entry: EntryEntity)

    @Query("SELECT * FROM entries ORDER BY createdAt DESC")
    fun getAllEntries(): Flow<List<EntryEntity>>

    @Query("SELECT * FROM entries WHERE isDraft = 1")
    suspend fun getPendingDrafts(): List<EntryEntity>

    @Query("UPDATE entries SET cleanedText = :cleanedText, wordCount = :wordCount, isDraft = 0, audioPath = NULL WHERE id = :id")
    suspend fun updateCleanedText(id: Long, cleanedText: String, wordCount: Int): Int

    @Query("UPDATE entries SET rawTranscript = :rawTranscript, wordCount = :wordCount, audioPath = NULL WHERE id = :id")
    suspend fun updateDraftTranscript(id: Long, rawTranscript: String, wordCount: Int): Int

    @Query("UPDATE entries SET rawTranscript = :rawTranscript, cleanedText = :cleanedText, wordCount = :wordCount, isDraft = 0, audioPath = NULL WHERE id = :id")
    suspend fun finalizeDraftWithCleanedText(
        id: Long,
        rawTranscript: String,
        cleanedText: String,
        wordCount: Int,
    ): Int

    @Query("SELECT * FROM entries WHERE id = :id")
    fun getEntryById(id: Long): Flow<EntryEntity?>

    @Query("UPDATE entries SET language = :language WHERE id = :id")
    suspend fun updateEntryLanguage(id: Long, language: String): Int

    @Query("DELETE FROM entries WHERE isDraft = 1 AND createdAt < :timestamp")
    suspend fun deleteDraftsOlderThan(timestamp: Long)

    @Query("DELETE FROM entries WHERE id IN (:ids)")
    suspend fun deleteEntries(ids: List<Long>)

    @Query("DELETE FROM entries")
    suspend fun deleteAllEntries()

    @Query("SELECT audioPath FROM entries WHERE id IN (:ids) AND audioPath IS NOT NULL")
    suspend fun getAudioPathsByIds(ids: List<Long>): List<String>

    @Query("SELECT audioPath FROM entries WHERE isDraft = 1 AND createdAt < :timestamp AND audioPath IS NOT NULL")
    suspend fun getDraftAudioPathsOlderThan(timestamp: Long): List<String>
}
