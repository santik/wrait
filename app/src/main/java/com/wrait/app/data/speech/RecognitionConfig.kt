package com.wrait.app.data.speech

import com.wrait.app.BuildConfig

object RecognitionConfig {
    const val SilenceTimeoutMs   = 5_000L   // silence before auto-stop (intent extras)
    const val MinimumUtteranceMs = 2_000L   // don't stop in the first 2 s even if silent
    const val MaxRestartAttempts = 100      // OEM devices can fire ~1 timeout/1.5 s; covers long sessions
    val HardCapMs = BuildConfig.RECORDING_HARD_CAP_MS
    val CountdownWindowMs = minOf(10_000L, HardCapMs)
}
