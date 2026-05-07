package com.wrait.app.analytics

import java.net.URI
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
}

internal fun PrivacyMode.toAnalyticsValue(): String = when (this) {
    PrivacyMode.MODE_BEST -> "best"
    PrivacyMode.MODE_OFFLINE -> "offline"
}

internal fun AnalyticsSavePath.toAnalyticsValue(): String = when (this) {
    AnalyticsSavePath.Fresh -> "fresh"
    AnalyticsSavePath.Retry -> "retry"
}

internal fun bucketEntryCount(count: Int): String = when {
    count <= 0 -> "0"
    count == 1 -> "1"
    count in 2..5 -> "2-5"
    count in 6..20 -> "6-20"
    else -> "20+"
}

internal fun RecognizerError.toAnalyticsErrorType(): String = when (this) {
    RecognizerError.TooShort -> "too_short"
    RecognizerError.NoMatch -> "no_match"
    RecognizerError.InsufficientPermissions -> "permission_denied"
    RecognizerError.ConnectionRequired,
    RecognizerError.Network,
    RecognizerError.NoInternet,
    RecognizerError.Timeout -> "network"
    is RecognizerError.NotAvailable -> "offline_unavailable"
    RecognizerError.BackendUnavailable,
    RecognizerError.ProxyAuthFailed,
    RecognizerError.ApiFailed,
    RecognizerError.Audio,
    RecognizerError.Client,
    RecognizerError.Server,
    is RecognizerError.Unknown -> "api_failed"
}

internal fun cleanupReasonToAnalyticsErrorType(reason: String): String = when (reason.trim().lowercase()) {
    "network error",
    "timeout" -> "network"
    else -> "api_failed"
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
