package com.wrait.app.ui.main

import com.wrait.app.RecordingState
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CanOpenSettingsTest {

    @Test
    fun idle_allowsSettingsWhenPanelClosed() {
        assertTrue(
            canOpenSettings(
                recordingState = RecordingState.Idle,
                showSettingsPanel = false,
            ),
        )
    }

    @Test
    fun activeRecording_blocksSettings() {
        assertFalse(
            canOpenSettings(
                recordingState = RecordingState.Listening,
                showSettingsPanel = false,
            ),
        )
    }

    @Test
    fun openPanel_blocksDuplicateSettingsEntry() {
        assertFalse(
            canOpenSettings(
                recordingState = RecordingState.Idle,
                showSettingsPanel = true,
            ),
        )
    }
}
