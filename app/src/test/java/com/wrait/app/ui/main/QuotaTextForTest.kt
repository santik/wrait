package com.wrait.app.ui.main

import com.wrait.app.data.api.RecordQuotaState
import com.wrait.app.domain.model.PrivacyMode
import java.time.OffsetDateTime
import org.junit.Assert.assertEquals
import org.junit.Test

class QuotaTextForTest {
    @Test
    fun bestMode_withQuota_formatsTotalAndRemaining() {
        val text = quotaTextFor(
            privacyMode = PrivacyMode.MODE_BEST,
            quota = RecordQuotaState(
                limit = 10,
                count = 3,
                remaining = 7,
                resetAt = OffsetDateTime.parse("2026-05-28T00:00:00Z"),
            ),
        )

        assertEquals("10 total · 7 left", text)
    }

    @Test
    fun bestMode_withZeroRemaining_formatsZeroLeft() {
        val text = quotaTextFor(
            privacyMode = PrivacyMode.MODE_BEST,
            quota = RecordQuotaState(
                limit = 10,
                count = 10,
                remaining = 0,
                resetAt = OffsetDateTime.parse("2026-05-28T00:00:00Z"),
            ),
        )

        assertEquals("10 total · 0 left", text)
    }

    @Test
    fun bestMode_withoutQuota_returnsEmptyString() {
        val text = quotaTextFor(
            privacyMode = PrivacyMode.MODE_BEST,
            quota = null,
        )

        assertEquals("", text)
    }

    @Test
    fun offlineMode_hidesQuotaEvenWhenKnown() {
        val text = quotaTextFor(
            privacyMode = PrivacyMode.MODE_OFFLINE,
            quota = RecordQuotaState(
                limit = 10,
                count = 10,
                remaining = 0,
                resetAt = OffsetDateTime.parse("2026-05-28T00:00:00Z"),
            ),
        )

        assertEquals("", text)
    }
}
