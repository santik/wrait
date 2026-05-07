package com.wrait.app.analytics

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.After
import org.junit.Before
import org.junit.Test

class AnalyticsSdkStateTest {
    @Before
    fun setUp() {
        AnalyticsSdkState.markUnavailable()
    }

    @After
    fun tearDown() {
        AnalyticsSdkState.markUnavailable()
    }

    @Test
    fun defaultState_isUnavailable() {
        assertFalse(AnalyticsSdkState.isReady)
    }

    @Test
    fun markReady_setsStateToReady() {
        AnalyticsSdkState.markReady()

        assertTrue(AnalyticsSdkState.isReady)
    }

    @Test
    fun markUnavailable_clearsReadyState() {
        AnalyticsSdkState.markReady()

        AnalyticsSdkState.markUnavailable()

        assertFalse(AnalyticsSdkState.isReady)
    }

    @Test
    fun repeatedTransitions_followLastWriteWinsContract() {
        AnalyticsSdkState.markReady()
        AnalyticsSdkState.markUnavailable()
        AnalyticsSdkState.markReady()

        assertTrue(AnalyticsSdkState.isReady)
    }
}
