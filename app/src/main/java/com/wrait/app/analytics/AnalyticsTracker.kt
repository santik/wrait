package com.wrait.app.analytics

import android.util.Log
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.domain.model.PrivacyMode

enum class AnalyticsSavePath {
    Fresh,
    Retry,
}

interface AnalyticsTracker {
    fun trackAppOpened(privacyMode: PrivacyMode, entryCount: Int)
    fun trackRecordingStarted(privacyMode: PrivacyMode, selectedLanguage: String)
    fun trackTranscriptionSucceeded(
        privacyMode: PrivacyMode,
        detectedLanguagePresent: Boolean,
        savePath: AnalyticsSavePath,
    )
    fun trackTranscriptionFailed(privacyMode: PrivacyMode, error: RecognizerError)
    fun trackCleanupSucceeded(privacyMode: PrivacyMode, savePath: AnalyticsSavePath)
    fun trackCleanupFailed(privacyMode: PrivacyMode, savePath: AnalyticsSavePath, reason: String)
    fun trackEntrySaved(privacyMode: PrivacyMode, savePath: AnalyticsSavePath)
    fun trackPrivacyModeToggled(from: PrivacyMode, to: PrivacyMode)
    fun trackEntriesListOpened(entryCount: Int)
    fun optIn()
    fun optOut()
}

internal inline fun AnalyticsTracker.trackSafely(
    tag: String,
    action: String,
    block: AnalyticsTracker.() -> Unit,
) {
    runCatching { block() }
        .onFailure { Log.w(tag, "Analytics failure during $action", it) }
}
