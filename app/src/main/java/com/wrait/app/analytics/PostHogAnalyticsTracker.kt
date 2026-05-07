package com.wrait.app.analytics

import android.util.Log
import com.posthog.PostHog
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.domain.model.PrivacyMode

class PostHogAnalyticsTracker : AnalyticsTracker {
    override fun trackAppOpened(privacyMode: PrivacyMode, entryCount: Int) {
        capture(
            AnalyticsEventNames.APP_OPENED,
            mapOf(
                "privacy_mode" to privacyMode.toAnalyticsValue(),
                "has_entries" to (entryCount > 0),
                "entry_count_bucket" to bucketEntryCount(entryCount),
            ),
        )
    }

    override fun trackRecordingStarted(privacyMode: PrivacyMode, selectedLanguage: String) {
        capture(
            AnalyticsEventNames.RECORDING_STARTED,
            mapOf(
                "privacy_mode" to privacyMode.toAnalyticsValue(),
                "selected_language" to selectedLanguage,
            ),
        )
    }

    override fun trackTranscriptionSucceeded(
        privacyMode: PrivacyMode,
        detectedLanguagePresent: Boolean,
        savePath: AnalyticsSavePath,
    ) {
        capture(
            AnalyticsEventNames.TRANSCRIPTION_SUCCEEDED,
            mapOf(
                "privacy_mode" to privacyMode.toAnalyticsValue(),
                "detected_language_present" to detectedLanguagePresent,
                "save_path" to savePath.toAnalyticsValue(),
            ),
        )
    }

    override fun trackTranscriptionFailed(privacyMode: PrivacyMode, error: RecognizerError) {
        capture(
            AnalyticsEventNames.TRANSCRIPTION_FAILED,
            mapOf(
                "privacy_mode" to privacyMode.toAnalyticsValue(),
                "error_type" to error.toAnalyticsErrorType(),
            ),
        )
    }

    override fun trackCleanupSucceeded(privacyMode: PrivacyMode, savePath: AnalyticsSavePath) {
        capture(
            AnalyticsEventNames.CLEANUP_SUCCEEDED,
            mapOf(
                "privacy_mode" to privacyMode.toAnalyticsValue(),
                "save_path" to savePath.toAnalyticsValue(),
            ),
        )
    }

    override fun trackCleanupFailed(
        privacyMode: PrivacyMode,
        savePath: AnalyticsSavePath,
        reason: String,
    ) {
        capture(
            AnalyticsEventNames.CLEANUP_FAILED,
            mapOf(
                "privacy_mode" to privacyMode.toAnalyticsValue(),
                "save_path" to savePath.toAnalyticsValue(),
                "error_type" to cleanupReasonToAnalyticsErrorType(reason),
            ),
        )
    }

    override fun trackEntrySaved(privacyMode: PrivacyMode, savePath: AnalyticsSavePath) {
        capture(
            AnalyticsEventNames.ENTRY_SAVED,
            mapOf(
                "privacy_mode" to privacyMode.toAnalyticsValue(),
                "save_path" to savePath.toAnalyticsValue(),
            ),
        )
    }

    override fun trackPrivacyModeToggled(from: PrivacyMode, to: PrivacyMode) {
        capture(
            AnalyticsEventNames.PRIVACY_MODE_TOGGLED,
            mapOf(
                "from" to from.toAnalyticsValue(),
                "to" to to.toAnalyticsValue(),
            ),
        )
    }

    override fun trackEntriesListOpened(entryCount: Int) {
        capture(
            AnalyticsEventNames.ENTRIES_LIST_OPENED,
            mapOf("entry_count_bucket" to bucketEntryCount(entryCount)),
        )
    }

    override fun optIn() {
        if (!AnalyticsSdkState.isReady) return
        runCatching { PostHog.optIn() }
            .onFailure { Log.w(TAG, "PostHog opt-in failed", it) }
    }

    override fun optOut() {
        if (!AnalyticsSdkState.isReady) return
        runCatching { PostHog.optOut() }
            .onFailure { Log.w(TAG, "PostHog opt-out failed", it) }
    }

    private fun capture(
        eventName: String,
        properties: Map<String, Any>,
    ) {
        // BuildConfig gating happens in DI, but runtime setup can still fail or be disabled,
        // so we keep a cheap readiness guard here as defense in depth.
        if (!AnalyticsSdkState.isReady) return

        runCatching {
            PostHog.capture(eventName, properties = properties)
        }.onFailure { error ->
            Log.w(TAG, "PostHog capture failed for $eventName", error)
        }
    }

    private companion object {
        private const val TAG = "PostHogTracker"
    }
}
