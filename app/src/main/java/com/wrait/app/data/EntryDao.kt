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

    @Query("UPDATE entries SET cleanedText = :cleanedText, wordCount = :wordCount, isDraft = 0 WHERE id = :id")
    suspend fun updateCleanedText(id: Long, cleanedText: String, wordCount: Int): Int

    @Query("DELETE FROM entries WHERE isDraft = 1 AND createdAt < :timestamp")
    suspend fun deleteDraftsOlderThan(timestamp: Long)
}
