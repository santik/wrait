package com.wrait.app.test.fake

import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.api.OpenAiApiService

class FakeOpenAiApiService : OpenAiApiService {
    var result: CleanupResult = CleanupResult.Success("cleaned text")
    var callCount: Int = 0

    fun reset() {
        result = CleanupResult.Success("cleaned text")
        callCount = 0
    }

    override suspend fun cleanupTranscript(rawText: String): CleanupResult {
        callCount++
        return result
    }
}
