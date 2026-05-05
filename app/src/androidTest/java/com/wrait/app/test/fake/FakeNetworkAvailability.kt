package com.wrait.app.test.fake

import com.wrait.app.data.device.NetworkAvailability

class FakeNetworkAvailability(
    var isAvailable: Boolean = true,
) : NetworkAvailability {
    var callCount: Int = 0

    override fun canAttemptCloudUpload(): Boolean = isAvailable
        .also { callCount += 1 }

    fun reset(isAvailable: Boolean = true) {
        this.isAvailable = isAvailable
        callCount = 0
    }
}
