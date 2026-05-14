package com.wrait.app.lock

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AppLockCoordinatorTest {
    private companion object {
        const val FIRST_PROMPT_NONCE = 1L
        const val SECOND_PROMPT_NONCE = 2L
    }

    private val coordinator = AppLockCoordinator()

    @Test
    fun processStart_ready_requestsPrompt() {
        val state = coordinator.onProcessStart(AppLockAvailability.Ready)

        assertEquals(AppLockStatus.Locked, state.status)
        assertTrue(state.isPromptPending)
        assertEquals(FIRST_PROMPT_NONCE, state.promptRequestNonce)
    }

    @Test
    fun repeatedProcessStart_whileForegrounded_doesNotRequestPromptAgain() {
        val firstState = coordinator.onProcessStart(AppLockAvailability.Ready)

        val secondState = coordinator.onProcessStart(AppLockAvailability.Ready)

        assertEquals(firstState, secondState)
        assertTrue(secondState.isPromptPending)
        assertEquals(FIRST_PROMPT_NONCE, secondState.promptRequestNonce)
    }

    @Test
    fun unlockSuccess_thenBackground_thenForeground_relocks() {
        coordinator.onProcessStart(AppLockAvailability.Ready)
        coordinator.onPromptShown()
        coordinator.onUnlockSucceeded()

        val unlocked = coordinator.state
        assertEquals(AppLockStatus.Unlocked, unlocked.status)

        coordinator.onProcessStop()
        val relocked = coordinator.onProcessStart(AppLockAvailability.Ready)

        assertEquals(AppLockStatus.Locked, relocked.status)
        assertTrue(relocked.isPromptPending)
        assertEquals(FIRST_PROMPT_NONCE, relocked.promptRequestNonce)
    }

    @Test
    fun promptShown_transitionsToPrompting() {
        coordinator.onProcessStart(AppLockAvailability.Ready)

        val state = coordinator.onPromptShown()

        assertEquals(AppLockStatus.Prompting, state.status)
        assertFalse(state.isPromptPending)
        assertEquals(FIRST_PROMPT_NONCE, state.promptRequestNonce)
    }

    @Test
    fun prompting_thenBackground_thenForeground_requestsFreshPrompt() {
        coordinator.onProcessStart(AppLockAvailability.Ready)
        coordinator.onPromptShown()

        coordinator.onProcessStop()
        val relocked = coordinator.onProcessStart(AppLockAvailability.Ready)

        assertEquals(AppLockStatus.Locked, relocked.status)
        assertTrue(relocked.isPromptPending)
        assertEquals(SECOND_PROMPT_NONCE, relocked.promptRequestNonce)
    }

    @Test
    fun setupRequired_blocksPrompting() {
        val state = coordinator.onProcessStart(AppLockAvailability.SecuritySetupRequired)

        assertEquals(AppLockStatus.SetupRequired, state.status)
        assertFalse(state.isPromptPending)
    }

    @Test
    fun temporarilyUnavailable_showsLockedMessage() {
        val state = coordinator.onProcessStart(AppLockAvailability.TemporarilyUnavailable)

        assertEquals(AppLockStatus.Locked, state.status)
        assertEquals(AppLockMessage.TemporarilyUnavailable, state.message)
        assertFalse(state.isPromptPending)
    }

    @Test
    fun cancelledPrompt_returnsLockedState() {
        coordinator.onProcessStart(AppLockAvailability.Ready)
        coordinator.onPromptShown()

        val state = coordinator.onUnlockCancelled()

        assertEquals(AppLockStatus.Locked, state.status)
        assertFalse(state.isPromptPending)
    }

    @Test
    fun explicitUnlockRequest_ready_requestsPrompt() {
        coordinator.onProcessStart(AppLockAvailability.Ready)
        coordinator.onPromptShown()
        coordinator.onUnlockCancelled()

        val state = coordinator.onUnlockRequested()

        assertEquals(AppLockStatus.Locked, state.status)
        assertTrue(state.isPromptPending)
        assertEquals(FIRST_PROMPT_NONCE, state.promptRequestNonce)
    }

    @Test
    fun promptTimeout_fromPrompting_showsTemporaryUnavailableMessage() {
        coordinator.onProcessStart(AppLockAvailability.Ready)
        coordinator.onPromptShown()

        val state = coordinator.onPromptTimeout()

        assertEquals(AppLockStatus.Locked, state.status)
        assertEquals(AppLockMessage.TemporarilyUnavailable, state.message)
        assertFalse(state.isPromptPending)
    }

    @Test
    fun promptTimeout_whenNotPrompting_isIgnored() {
        val state = coordinator.onPromptTimeout()

        assertEquals(AppLockStatus.Locked, state.status)
        assertNull(state.message)
        assertFalse(state.isPromptPending)
    }

    @Test
    fun processStop_setupRequired_preservesSetupState() {
        coordinator.onProcessStart(AppLockAvailability.SecuritySetupRequired)

        val state = coordinator.onProcessStop()

        assertEquals(AppLockStatus.SetupRequired, state.status)
        assertFalse(state.isPromptPending)
    }
}
