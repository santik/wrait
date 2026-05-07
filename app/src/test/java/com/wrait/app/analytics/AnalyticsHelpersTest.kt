package com.wrait.app.analytics

import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.domain.model.PrivacyMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AnalyticsHelpersTest {
    @Test
    fun privacyMode_mapsToExpectedAnalyticsValues() {
        assertEquals("best", PrivacyMode.MODE_BEST.toAnalyticsValue())
        assertEquals("offline", PrivacyMode.MODE_OFFLINE.toAnalyticsValue())
    }

    @Test
    fun entryCount_bucketBoundaries_areStable() {
        assertEquals("0", bucketEntryCount(0))
        assertEquals("1", bucketEntryCount(1))
        assertEquals("2-5", bucketEntryCount(2))
        assertEquals("2-5", bucketEntryCount(5))
        assertEquals("6-20", bucketEntryCount(6))
        assertEquals("6-20", bucketEntryCount(20))
        assertEquals("20+", bucketEntryCount(21))
    }

    @Test
    fun recognizerErrors_mapToApprovedAnalyticsTypes() {
        assertEquals(AnalyticsErrorType.TooShort, RecognizerError.TooShort.toAnalyticsErrorType())
        assertEquals(AnalyticsErrorType.NoMatch, RecognizerError.NoMatch.toAnalyticsErrorType())
        assertEquals(
            AnalyticsErrorType.PermissionDenied,
            RecognizerError.InsufficientPermissions.toAnalyticsErrorType()
        )
        assertEquals(AnalyticsErrorType.Network, RecognizerError.ConnectionRequired.toAnalyticsErrorType())
        assertEquals(AnalyticsErrorType.Network, RecognizerError.NoInternet.toAnalyticsErrorType())
        assertEquals(
            AnalyticsErrorType.OfflineUnavailable,
            RecognizerError.NotAvailable("en-US").toAnalyticsErrorType()
        )
        assertEquals(AnalyticsErrorType.ApiFailed, RecognizerError.ApiFailed.toAnalyticsErrorType())
        assertEquals(AnalyticsErrorType.ApiFailed, RecognizerError.Unknown(123).toAnalyticsErrorType())
    }

    @Test
    fun cleanupReasons_mapToCoarseAnalyticsTypes() {
        assertEquals(AnalyticsErrorType.Network, cleanupReasonToAnalyticsErrorType("network error"))
        assertEquals(AnalyticsErrorType.Network, cleanupReasonToAnalyticsErrorType("timeout"))
        assertEquals(AnalyticsErrorType.ApiFailed, cleanupReasonToAnalyticsErrorType("backend exploded"))
    }

    @Test
    fun analyticsHost_validation_matchesExpectedSchemes() {
        assertTrue(isValidAnalyticsHost("https://us.i.posthog.com"))
        assertTrue(isValidAnalyticsHost("http://localhost"))
        assertFalse(isValidAnalyticsHost(""))
        assertFalse(isValidAnalyticsHost("posthog"))
        assertFalse(isValidAnalyticsHost("ftp://us.i.posthog.com"))
    }

    @Test
    fun blockedAnalyticsPropertyKeys_returnsExactBlockedMatchesOnly() {
        val removed = blockedAnalyticsPropertyKeys(
            propertyKeys = linkedSetOf("text", "privacy_mode", "audioPath", "shareText", "myText"),
            blockedKeys = setOf("text", "audioPath", "shareText"),
        )

        assertEquals(linkedSetOf("text", "audioPath", "shareText"), removed)
    }

    @Test
    fun shouldEnableAnalyticsSdk_requiresEnabledFlagApiKeyAndValidHost() {
        assertTrue(
            shouldEnableAnalyticsSdk(
                enabled = true,
                apiKey = "phc_test",
                host = "https://eu.i.posthog.com",
            )
        )
        assertFalse(
            shouldEnableAnalyticsSdk(
                enabled = false,
                apiKey = "phc_test",
                host = "https://eu.i.posthog.com",
            )
        )
        assertFalse(
            shouldEnableAnalyticsSdk(
                enabled = true,
                apiKey = "",
                host = "https://eu.i.posthog.com",
            )
        )
        assertFalse(
            shouldEnableAnalyticsSdk(
                enabled = true,
                apiKey = "phc_test",
                host = "not-a-url",
            )
        )
    }
}
