package com.wrait.app.test.fake

import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.api.TranscriptCleanupService

class FakeTranscriptCleanupService : TranscriptCleanupService {
    var result: CleanupResult = CleanupResult.Success("cleaned text")
    var callCount: Int = 0
    var lastRawText: String? = null
    var lastLanguage: String? = null

    fun reset() {
        result = CleanupResult.Success("cleaned text")
        callCount = 0
        lastRawText = null
        lastLanguage = null
    }

    override suspend fun cleanupTranscript(rawText: String, language: String): CleanupResult {
        callCount++
        lastRawText = rawText
        lastLanguage = language
        return result
    }
}
