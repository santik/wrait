package com.wrait.app.data.api

import android.util.Log
import com.wrait.app.data.api.generated.model.RecordQuota
import java.time.OffsetDateTime

data class RecordQuotaState(
    val limit: Int,
    val count: Int,
    val remaining: Int,
    val resetAt: OffsetDateTime,
)

/**
 * Converts backend quota into app state only when it is internally consistent.
 *
 * Returning `null` is intentional for invalid backend quota values so callers can
 * preserve the last valid quota already shown in the UI instead of replacing it
 * with nonsensical data.
 */
internal fun RecordQuota.toRecordQuotaStateOrNull(
    source: String,
): RecordQuotaState? {
    val validationError = when {
        limit < 0 -> "limit must be >= 0"
        count < 0 -> "count must be >= 0"
        remaining < 0 -> "remaining must be >= 0"
        count > limit -> "count must be <= limit"
        remaining > limit -> "remaining must be <= limit"
        else -> null
    }

    if (validationError != null) {
        Log.w(
            TAG,
            "Ignoring invalid quota from $source: $validationError " +
                "(limit=$limit, count=$count, remaining=$remaining, resetAt=$resetAt)",
        )
        return null
    }

    return RecordQuotaState(
        limit = limit,
        count = count,
        remaining = remaining,
        resetAt = resetAt,
    )
}

private const val TAG = "RecordQuotaState"
