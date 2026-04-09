package com.wrait.app

import org.junit.Assert.assertEquals
import org.junit.Test

class KeepScreenOnCommandTest {

    @Test
    fun activeAndFlagNotSet_addsFlag() {
        val command = keepScreenOnCommand(
            isRecordingActive = true,
            keepScreenOnFlagSet = false,
        )
        assertEquals(KeepScreenOnCommand.AddFlag, command)
    }

    @Test
    fun activeAndFlagAlreadySet_noChange() {
        val command = keepScreenOnCommand(
            isRecordingActive = true,
            keepScreenOnFlagSet = true,
        )
        assertEquals(KeepScreenOnCommand.None, command)
    }

    @Test
    fun inactiveAndFlagSet_clearsFlag() {
        val command = keepScreenOnCommand(
            isRecordingActive = false,
            keepScreenOnFlagSet = true,
        )
        assertEquals(KeepScreenOnCommand.ClearFlag, command)
    }

    @Test
    fun inactiveAndFlagNotSet_noChange() {
        val command = keepScreenOnCommand(
            isRecordingActive = false,
            keepScreenOnFlagSet = false,
        )
        assertEquals(KeepScreenOnCommand.None, command)
    }
}
