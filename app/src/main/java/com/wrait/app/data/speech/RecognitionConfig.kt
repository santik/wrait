package com.wrait.app.data.speech

object RecognitionConfig {
    const val SilenceTimeoutMs   = 5_000L   // silence before auto-stop (intent extras)
    const val MinimumUtteranceMs = 2_000L   // don't stop in the first 2 s even if silent
    const val MaxRestartAttempts = 100      // OEM devices can fire ~1 timeout/1.5 s; covers 2 min
    const val HardCapMs          = 120_000L // 2-minute absolute maximum
}
