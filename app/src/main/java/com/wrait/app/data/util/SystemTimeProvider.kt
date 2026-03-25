package com.wrait.app.data.util

import com.wrait.app.domain.util.TimeProvider
import javax.inject.Inject

class SystemTimeProvider @Inject constructor() : TimeProvider {
    override fun currentTimeMillis(): Long = System.currentTimeMillis()
}
