package com.wrait.app.analytics

import java.net.URI
import com.wrait.app.data.speech.TranscriptionFailureReason
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.domain.model.PrivacyMode

internal object AnalyticsEventNames {
    const val APP_OPENED = "app opened"
    const val RECORDING_STARTED = "recording started"
    const val TRANSCRIPTION_SUCCEEDED = "transcription succeeded"
    const val TRANSCRIPTION_FAILED = "transcription failed"
    const val CLEANUP_SUCCEEDED = "cleanup succeeded"
    const val CLEANUP_FAILED = "cleanup failed"
    const val ENTRY_SAVED = "entry saved"
    const val PRIVACY_MODE_TOGGLED = "privacy mode toggled"
    const val ENTRIES_LIST_OPENED = "entries list opened"
    const val MICROPHONE_PERMISSION_REQUESTED = "microphone permission requested"
    const val MICROPHONE_PERMISSION_DENIED = "microphone permission denied"
    const val MICROPHONE_PERMISSION_PERMANENTLY_DENIED = "microphone permission permanently denied"
    const val DRAFT_RETRY_STARTED = "draft retry started"
    const val DRAFT_RETRY_SUCCEEDED = "draft retry succeeded"
    const val DRAFT_RETRY_FAILED = "draft retry failed"
    const val ENTRY_DETAIL_OPENED = "entry detail opened"
    const val ENTRY_SHARED = "entry shared"
    const val ENTRY_DELETE_INITIATED = "entry delete initiated"
    const val ENTRY_DELETED = "entry deleted"
}

internal fun PrivacyMode.toAnalyticsValue(): String = when (this) {
    PrivacyMode.MODE_BEST -> "best"
    PrivacyMode.MODE_OFFLINE -> "offline"
}

internal fun AnalyticsSavePath.toAnalyticsValue(): String = when (this) {
    AnalyticsSavePath.Fresh -> "fresh"
    AnalyticsSavePath.Retry -> "retry"
}

internal fun AnalyticsDraftType.toAnalyticsValue(): String = when (this) {
    AnalyticsDraftType.Text -> "text"
    AnalyticsDraftType.Audio -> "audio"
}

internal fun AnalyticsRetryFailureStage.toAnalyticsValue(): String = when (this) {
    AnalyticsRetryFailureStage.Transcription -> "transcription"
    AnalyticsRetryFailureStage.Cleanup -> "cleanup"
}

internal fun AnalyticsErrorType.toAnalyticsValue(): String = when (this) {
    AnalyticsErrorType.TooShort -> "too_short"
    AnalyticsErrorType.NoMatch -> "no_match"
    AnalyticsErrorType.PermissionDenied -> "permission_denied"
    AnalyticsErrorType.Network -> "network"
    AnalyticsErrorType.ApiFailed -> "api_failed"
    AnalyticsErrorType.OfflineUnavailable -> "offline_unavailable"
}

internal fun AnalyticsEntrySource.toAnalyticsValue(): String = when (this) {
    AnalyticsEntrySource.List -> "list"
    AnalyticsEntrySource.Detail -> "detail"
}

internal fun bucketEntryCount(count: Int): String = when {
    count <= 0 -> "0"
    count == 1 -> "1"
    count in 2..5 -> "2-5"
    count in 6..20 -> "6-20"
    else -> "20+"
}

internal fun RecognizerError.toAnalyticsErrorType(): AnalyticsErrorType = when (this) {
    RecognizerError.TooShort -> AnalyticsErrorType.TooShort
    RecognizerError.NoMatch -> AnalyticsErrorType.NoMatch
    RecognizerError.InsufficientPermissions -> AnalyticsErrorType.PermissionDenied
    RecognizerError.ConnectionRequired,
    RecognizerError.Network,
    RecognizerError.NoInternet,
    RecognizerError.Timeout -> AnalyticsErrorType.Network
    is RecognizerError.NotAvailable -> AnalyticsErrorType.OfflineUnavailable
    RecognizerError.BackendUnavailable,
    RecognizerError.ProxyAuthFailed,
    RecognizerError.ApiFailed,
    RecognizerError.Audio,
    RecognizerError.Client,
    RecognizerError.Server,
    is RecognizerError.Unknown -> AnalyticsErrorType.ApiFailed
}

internal fun cleanupReasonToAnalyticsErrorType(reason: String): AnalyticsErrorType = when (reason.trim().lowercase()) {
    "network error",
    "timeout" -> AnalyticsErrorType.Network
    else -> AnalyticsErrorType.ApiFailed
}

internal fun TranscriptionFailureReason.toAnalyticsErrorType(): AnalyticsErrorType = when (this) {
    TranscriptionFailureReason.TooShort -> AnalyticsErrorType.TooShort
    TranscriptionFailureReason.NothingCaught -> AnalyticsErrorType.NoMatch
    TranscriptionFailureReason.MicBlocked -> AnalyticsErrorType.PermissionDenied
    TranscriptionFailureReason.NetworkError -> AnalyticsErrorType.Network
    TranscriptionFailureReason.ModelNotAvailable -> AnalyticsErrorType.OfflineUnavailable
    TranscriptionFailureReason.BackendUnavailable,
    TranscriptionFailureReason.ProxyAuthFailed,
    TranscriptionFailureReason.ApiError -> AnalyticsErrorType.ApiFailed
}

internal fun isValidAnalyticsHost(host: String): Boolean {
    if (host.isBlank()) return false

    return runCatching {
        val uri = URI(host)
        (uri.scheme == "https" || uri.scheme == "http") &&
            !uri.host.isNullOrBlank()
    }.getOrDefault(false)
}

internal fun blockedAnalyticsPropertyKeys(
    propertyKeys: Set<String>,
    blockedKeys: Set<String>,
): Set<String> = propertyKeys.filterTo(linkedSetOf()) { it in blockedKeys }

internal fun shouldEnableAnalyticsSdk(
    enabled: Boolean,
    apiKey: String,
    host: String,
): Boolean = enabled && apiKey.isNotBlank() && isValidAnalyticsHost(host)
