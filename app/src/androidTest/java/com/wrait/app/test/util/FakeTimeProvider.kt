package com.wrait.app.test.util

import com.wrait.app.domain.util.TimeProvider

class FakeTimeProvider(var time: Long = System.currentTimeMillis()) : TimeProvider {
    override fun currentTimeMillis(): Long = time
}
