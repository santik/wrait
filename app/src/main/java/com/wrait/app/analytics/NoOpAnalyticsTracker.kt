package com.wrait.app.analytics

import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.domain.model.PrivacyMode

class NoOpAnalyticsTracker : AnalyticsTracker {
    override fun trackAppOpened(privacyMode: PrivacyMode, entryCount: Int) = Unit

    override fun trackRecordingStarted(privacyMode: PrivacyMode, selectedLanguage: String) = Unit

    override fun trackTranscriptionSucceeded(
        privacyMode: PrivacyMode,
        detectedLanguagePresent: Boolean,
        savePath: AnalyticsSavePath,
    ) = Unit

    override fun trackTranscriptionFailed(privacyMode: PrivacyMode, error: RecognizerError) = Unit

    override fun trackCleanupSucceeded(privacyMode: PrivacyMode, savePath: AnalyticsSavePath) = Unit

    override fun trackCleanupFailed(
        privacyMode: PrivacyMode,
        savePath: AnalyticsSavePath,
        reason: String,
    ) = Unit

    override fun trackEntrySaved(privacyMode: PrivacyMode, savePath: AnalyticsSavePath) = Unit

    override fun trackPrivacyModeToggled(from: PrivacyMode, to: PrivacyMode) = Unit

    override fun trackEntriesListOpened(entryCount: Int) = Unit

    override fun optIn() = Unit

    override fun optOut() = Unit
}
