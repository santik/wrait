package com.wrait.flutter

/**
 * Pure logic for the home-screen widget's daily recording quota.
 *
 * Applies the optimistic daily reset (spec 055 plan D-6): once the current time
 * has reached the cached reset boundary, the day is shown as fresh (0 used)
 * until the app next syncs real values from the backend. Kept free of Android
 * dependencies so it can be unit-tested in isolation (JUnit).
 */
object WidgetQuotaDisplay {
    data class Quota(val used: Int, val limit: Int)

    /**
     * @param used the cached recordings-taken count
     * @param limit the cached daily limit
     * @param resetAtMs cached quota reset boundary, epoch milliseconds
     * @param nowMs current time, epoch milliseconds
     */
    fun resolve(used: Int, limit: Int, resetAtMs: Long, nowMs: Long): Quota {
        val safeLimit = limit.coerceAtLeast(0)
        if (nowMs >= resetAtMs) {
            return Quota(used = 0, limit = safeLimit)
        }
        return Quota(used = used.coerceIn(0, safeLimit), limit = safeLimit)
    }

    /** Renders the quota as "used / total". */
    fun format(quota: Quota): String = "${quota.used} / ${quota.limit}"
}
