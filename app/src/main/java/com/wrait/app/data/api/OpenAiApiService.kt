package com.wrait.app.data.api

interface OpenAiApiService {
    suspend fun cleanupTranscript(rawText: String): CleanupResult
}

sealed class CleanupResult {
    data class Success(val cleanedText: String) : CleanupResult()
    data class Failure(val reason: String) : CleanupResult()
}
