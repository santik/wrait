package com.wrait.app.ui.main

import com.wrait.app.RecordingState
import org.junit.Assert.assertEquals
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
}

