package com.wrait.app.lock

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AppLockViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun promptShown_timesOutToTemporaryUnavailable() = runTest(dispatcher.scheduler) {
        val viewModel = AppLockViewModel()

        viewModel.onProcessStart(AppLockAvailability.Ready)
        viewModel.onPromptShown()

        val promptingState = viewModel.uiState.value
        assertEquals(AppLockStatus.Prompting, promptingState.status)
        assertFalse(promptingState.isPromptPending)

        advanceTimeBy(APP_LOCK_PROMPT_TIMEOUT_MS)
        advanceUntilIdle()

        val timedOutState = viewModel.uiState.value
        assertEquals(AppLockStatus.Locked, timedOutState.status)
        assertEquals(AppLockMessage.TemporarilyUnavailable, timedOutState.message)
        assertFalse(timedOutState.isPromptPending)
    }

    @Test
    fun unlockSuccess_cancelsPromptTimeout() = runTest(dispatcher.scheduler) {
        val viewModel = AppLockViewModel()

        viewModel.onProcessStart(AppLockAvailability.Ready)
        viewModel.onPromptShown()
        viewModel.onUnlockSucceeded()

        advanceTimeBy(APP_LOCK_PROMPT_TIMEOUT_MS)
        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(AppLockStatus.Unlocked, state.status)
        assertNull(state.message)
        assertFalse(state.isPromptPending)
    }
}
