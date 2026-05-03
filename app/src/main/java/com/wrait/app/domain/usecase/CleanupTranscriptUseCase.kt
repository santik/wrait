package com.wrait.app.domain.usecase

import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.api.TranscriptCleanupService
import javax.inject.Inject

class CleanupTranscriptUseCase @Inject constructor(
    private val transcriptCleanupService: TranscriptCleanupService,
) {
    suspend operator fun invoke(rawText: String, language: String): CleanupResult {
        return transcriptCleanupService.cleanupTranscript(rawText, language)
    }
}
