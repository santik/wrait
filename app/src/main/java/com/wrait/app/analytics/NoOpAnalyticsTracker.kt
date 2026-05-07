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

    override fun trackMicrophonePermissionRequested() = Unit

    override fun trackMicrophonePermissionDenied() = Unit

    override fun trackMicrophonePermissionPermanentlyDenied() = Unit

    override fun trackDraftRetryStarted(draftType: AnalyticsDraftType) = Unit

    override fun trackDraftRetrySucceeded(draftType: AnalyticsDraftType) = Unit

    override fun trackDraftRetryFailed(
        draftType: AnalyticsDraftType,
        failureStage: AnalyticsRetryFailureStage,
        errorType: AnalyticsErrorType,
    ) = Unit

    override fun trackEntryDetailOpened(isDraft: Boolean) = Unit

    override fun trackEntryShared(source: AnalyticsEntrySource) = Unit

    override fun trackEntryDeleteInitiated(source: AnalyticsEntrySource, isDraft: Boolean) = Unit

    override fun trackEntryDeleted(source: AnalyticsEntrySource, isDraft: Boolean) = Unit

    override fun optIn() = Unit

    override fun optOut() = Unit
}
