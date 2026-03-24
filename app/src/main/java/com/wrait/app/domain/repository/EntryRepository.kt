package com.wrait.app.domain.repository

import com.wrait.app.domain.model.Entry
import kotlinx.coroutines.flow.Flow

interface EntryRepository {
    suspend fun saveDraft(transcript: String, language: String): Long
    suspend fun updateWithCleanedText(id: Long, text: String, wordCount: Int)
    fun getAllEntries(): Flow<List<Entry>>
    suspend fun getPendingDrafts(): List<Entry>
}
