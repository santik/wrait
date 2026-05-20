package com.wrait.app.ui.main

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.wrait.app.RecordingState
import com.wrait.app.ui.theme.WrAItTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ButtonAreaTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun countdownRing_hidden_whenNoProgressProvided() {
        composeRule.setContent {
            WrAItTheme {
                ButtonArea(
                    recordingState = RecordingState.Listening,
                    recordingCountdown = null,
                    showBlockedMessage = false,
                    shakeErrorKey = 0,
                    onTap = {},
                    countdownProgressOverride = null,
                )
            }
        }

        composeRule.onAllNodesWithTag("recording_countdown_ring", useUnmergedTree = true)
            .assertCountEquals(0)
    }

    @Test
    fun countdownRing_visible_whenProgressProvided() {
        composeRule.setContent {
            WrAItTheme {
                ButtonArea(
                    recordingState = RecordingState.Listening,
                    recordingCountdown = null,
                    showBlockedMessage = false,
                    shakeErrorKey = 0,
                    onTap = {},
                    countdownProgressOverride = 0.9f,
                )
            }
        }

        composeRule.onAllNodesWithTag("recording_countdown_ring", useUnmergedTree = true)
            .assertCountEquals(1)
    }
}
