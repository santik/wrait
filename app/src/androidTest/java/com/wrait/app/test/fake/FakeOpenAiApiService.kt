package com.wrait.app.test.fake

import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.api.OpenAiApiService

class FakeOpenAiApiService : OpenAiApiService {
    var result: CleanupResult = CleanupResult.Success("cleaned text")
    override suspend fun cleanupTranscript(rawText: String): CleanupResult = result
}
