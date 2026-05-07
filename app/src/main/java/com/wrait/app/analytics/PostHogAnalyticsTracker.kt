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
                "error_type" to error.toAnalyticsErrorType().toAnalyticsValue(),
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
                "error_type" to cleanupReasonToAnalyticsErrorType(reason).toAnalyticsValue(),
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

    override fun trackMicrophonePermissionRequested() {
        capture(AnalyticsEventNames.MICROPHONE_PERMISSION_REQUESTED, emptyMap())
    }

    override fun trackMicrophonePermissionDenied() {
        capture(AnalyticsEventNames.MICROPHONE_PERMISSION_DENIED, emptyMap())
    }

    override fun trackMicrophonePermissionPermanentlyDenied() {
        capture(AnalyticsEventNames.MICROPHONE_PERMISSION_PERMANENTLY_DENIED, emptyMap())
    }

    override fun trackDraftRetryStarted(draftType: AnalyticsDraftType) {
        capture(
            AnalyticsEventNames.DRAFT_RETRY_STARTED,
            mapOf("draft_type" to draftType.toAnalyticsValue()),
        )
    }

    override fun trackDraftRetrySucceeded(draftType: AnalyticsDraftType) {
        capture(
            AnalyticsEventNames.DRAFT_RETRY_SUCCEEDED,
            mapOf(
                "draft_type" to draftType.toAnalyticsValue(),
                "result" to "entry_saved",
            ),
        )
    }

    override fun trackDraftRetryFailed(
        draftType: AnalyticsDraftType,
        failureStage: AnalyticsRetryFailureStage,
        errorType: AnalyticsErrorType,
    ) {
        capture(
            AnalyticsEventNames.DRAFT_RETRY_FAILED,
            mapOf(
                "draft_type" to draftType.toAnalyticsValue(),
                "failure_stage" to failureStage.toAnalyticsValue(),
                "error_type" to errorType.toAnalyticsValue(),
            ),
        )
    }

    override fun trackEntryDetailOpened(isDraft: Boolean) {
        capture(
            AnalyticsEventNames.ENTRY_DETAIL_OPENED,
            mapOf("is_draft" to isDraft),
        )
    }

    override fun trackEntryShared(source: AnalyticsEntrySource) {
        capture(
            AnalyticsEventNames.ENTRY_SHARED,
            mapOf(
                "source" to source.toAnalyticsValue(),
                "is_draft" to false,
            ),
        )
    }

    override fun trackEntryDeleteInitiated(source: AnalyticsEntrySource, isDraft: Boolean) {
        capture(
            AnalyticsEventNames.ENTRY_DELETE_INITIATED,
            mapOf(
                "source" to source.toAnalyticsValue(),
                "is_draft" to isDraft,
            ),
        )
    }

    override fun trackEntryDeleted(source: AnalyticsEntrySource, isDraft: Boolean) {
        capture(
            AnalyticsEventNames.ENTRY_DELETED,
            mapOf(
                "source" to source.toAnalyticsValue(),
                "is_draft" to isDraft,
            ),
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
