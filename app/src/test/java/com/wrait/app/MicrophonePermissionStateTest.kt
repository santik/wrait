package com.wrait.app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MicrophonePermissionStateTest {

    @Test
    fun requestedAndNoRationale_isPermanentlyDenied() {
        assertTrue(
            isMicrophonePermissionPermanentlyDenied(
                hasRequestedPermission = true,
                shouldShowRationale = false,
            )
        )
    }

    @Test
    fun notYetRequested_isNotPermanentlyDenied() {
        assertFalse(
            isMicrophonePermissionPermanentlyDenied(
                hasRequestedPermission = false,
                shouldShowRationale = false,
            )
        )
    }

    @Test
    fun rationaleStillShown_isNotPermanentlyDenied() {
        assertFalse(
            isMicrophonePermissionPermanentlyDenied(
                hasRequestedPermission = true,
                shouldShowRationale = true,
            )
        )
    }
}
