package com.wrait.app.ui.main

import com.wrait.app.RecordingState
import com.wrait.app.data.speech.RecognizerError
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StatusTextForTest {
    @Test
    fun idle_showsTapToWrite_untilFirstRecording() {
        val text = statusTextFor(
            recordingState = RecordingState.Idle,
            showBlockedMessage = false,
            hasEverRecorded = false,
        )
        assertEquals("tap to write", text)
    }

    @Test
    fun idle_hidesTapToWrite_afterFirstRecording() {
        val text = statusTextFor(
            recordingState = RecordingState.Idle,
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("", text)
    }

    @Test
    fun idle_blockedMessage_overridesTapToWrite() {
        val text = statusTextFor(
            recordingState = RecordingState.Idle,
            showBlockedMessage = true,
            hasEverRecorded = false,
        )
        assertEquals("mic blocked \u00b7 tap to open settings", text)
    }

    @Test
    fun listening_showsEllipsis() {
        val text = statusTextFor(
            recordingState = RecordingState.Listening,
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("listening\u2026", text)
    }

    @Test
    fun uploading_showsEllipsis() {
        val text = statusTextFor(
            recordingState = RecordingState.Uploading,
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("uploading\u2026", text)
    }

    @Test
    fun processing_showsCleaningUp() {
        val text = statusTextFor(
            recordingState = RecordingState.Processing,
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("cleaning up\u2026", text)
    }

    @Test
    fun saved_showsTapToRead() {
        val text = statusTextFor(
            recordingState = RecordingState.Saved(entryId = 1L),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("tap to read", text)
    }

    @Test
    fun deleted_singleEntry_showsSingular() {
        val text = statusTextFor(
            recordingState = RecordingState.Deleted(count = 1),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("entry deleted", text)
    }

    @Test
    fun deleted_multipleEntries_showsCount() {
        val text = statusTextFor(
            recordingState = RecordingState.Deleted(count = 3),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("3 entries deleted", text)
    }

    @Test
    fun error_noInternet_showsSavedAsDraft() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.NoInternet),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("no connection \u00b7 saved as draft", text)
    }

    @Test
    fun error_network_showsSavedAsDraft() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.Network),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("no connection \u00b7 saved as draft", text)
    }

    @Test
    fun error_timeout_showsSavedAsDraft() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.Timeout),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("no connection \u00b7 saved as draft", text)
    }

    @Test
    fun error_apiFailed_showsWillRetry() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.ApiFailed),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("saved as draft \u00b7 will retry", text)
    }

    @Test
    fun error_tooShort_showsKeepTalking() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.TooShort),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("too short \u00b7 keep talking", text)
    }

    @Test
    fun error_noMatch_showsTooQuiet() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.NoMatch),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("nothing caught \u00b7 too quiet?", text)
    }

    @Test
    fun error_insufficientPermissions_showsMicBlocked() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.InsufficientPermissions),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("mic blocked \u00b7 tap to open settings", text)
    }

    @Test
    fun saved_noDetectedLanguage_showsTapToRead() {
        val text = statusTextFor(
            recordingState = RecordingState.Saved(entryId = 1L, detectedLanguage = null),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("tap to read", text)
    }

    @Test
    fun saved_withDetectedLanguage_showsDetectedHint() {
        val text = statusTextFor(
            recordingState = RecordingState.Saved(entryId = 1L, detectedLanguage = "fr"),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        // Should contain the human-readable name, not raw code "fr"
        assertTrue("Status should start with 'tap to read'", text.startsWith("tap to read"))
        assertTrue("Status should mention detected language", text.contains("detected"))
        assertFalse("Raw language code should not appear", text.endsWith("fr"))
    }

    @Test
    fun blocked_overridesAllNonIdleStates() {
        // showBlockedMessage=true should always return the blocked message, regardless of state
        val text = statusTextFor(
            recordingState = RecordingState.Listening,
            showBlockedMessage = true,
            hasEverRecorded = true,
        )
        assertEquals("mic blocked \u00b7 tap to open settings", text)
    }
}

