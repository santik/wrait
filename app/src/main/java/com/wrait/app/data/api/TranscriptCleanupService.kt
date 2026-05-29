package com.wrait.app.data.api

interface TranscriptCleanupService {
    suspend fun cleanupTranscript(rawText: String, language: String): CleanupResult
}

sealed class CleanupResult {
    data class Success(
        val cleanedText: String,
        val quota: RecordQuotaState? = null,
    ) : CleanupResult()
    data class Failure(
        val reason: String,
        val quota: RecordQuotaState? = null,
    ) : CleanupResult()
}
