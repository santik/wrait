package com.wrait.app.analytics

internal object AnalyticsSdkState {
    @Volatile
    var isReady: Boolean = false
        private set

    fun markReady() {
        isReady = true
    }

    fun markUnavailable() {
        isReady = false
    }
}
