package com.wrait.app.domain.repository

import com.wrait.app.domain.model.Entry
import kotlinx.coroutines.flow.Flow

interface EntryRepository {
    suspend fun saveDraft(transcript: String, language: String): Long
    suspend fun saveAudioDraft(audioPath: String, language: String): Long
    suspend fun updateWithCleanedText(id: Long, text: String, wordCount: Int)
    suspend fun updateDraftTranscript(id: Long, rawTranscript: String, wordCount: Int)
    suspend fun finalizeDraftWithCleanedText(id: Long, rawTranscript: String, cleanedText: String, wordCount: Int)
    fun getAllEntries(): Flow<List<Entry>>
    fun getEntryById(id: Long): Flow<Result<Entry?>>
    suspend fun getPendingDrafts(): List<Entry>
    suspend fun deleteStaleDrafts(daysOld: Int)
    suspend fun deleteStaleDrafts()
    suspend fun deleteEntries(ids: List<Long>)
}
