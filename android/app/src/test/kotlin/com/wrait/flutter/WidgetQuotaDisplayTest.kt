package com.wrait.flutter

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Unit tests for the home-screen widget quota logic (spec 055 plan D-6).
 */
class WidgetQuotaDisplayTest {
    @Test
    fun `before reset shows cached used over limit`() {
        val quota = WidgetQuotaDisplay.resolve(
            used = 3,
            limit = 10,
            resetAtMs = 2_000L,
            nowMs = 1_000L,
        )

        assertEquals(3, quota.used)
        assertEquals(10, quota.limit)
        assertEquals("3 / 10", WidgetQuotaDisplay.format(quota))
    }

    @Test
    fun `at or after reset shows a fresh day`() {
        val atReset = WidgetQuotaDisplay.resolve(
            used = 8,
            limit = 10,
            resetAtMs = 1_000L,
            nowMs = 1_000L,
        )
        assertEquals(0, atReset.used)
        assertEquals(10, atReset.limit)

        val afterReset = WidgetQuotaDisplay.resolve(
            used = 8,
            limit = 10,
            resetAtMs = 1_000L,
            nowMs = 5_000L,
        )
        assertEquals(0, afterReset.used)
        assertEquals("0 / 10", WidgetQuotaDisplay.format(afterReset))
    }

    @Test
    fun `used is clamped into the zero to limit range`() {
        val quota = WidgetQuotaDisplay.resolve(
            used = 99,
            limit = 10,
            resetAtMs = 2_000L,
            nowMs = 1_000L,
        )

        assertEquals(10, quota.used)
    }
}
