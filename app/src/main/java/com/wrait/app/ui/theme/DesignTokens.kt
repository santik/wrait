package com.wrait.app.ui.theme

import androidx.compose.ui.unit.dp

object DesignTokens {

    object Animation {
        const val FadeDuration = 300        // ms — standard fade in/out
        const val ShakeDuration = 310       // ms — error shake (~310ms total, 5 steps)
        const val PulseDuration = 1800      // ms — recording pulse loop
        const val DeleteFadeDuration = 200  // ms — deleted card fade out in LazyColumn
        const val StripColorDuration = 400  // ms — top strip colour transition
        const val ButtonAlphaDuration = 200 // ms — button opacity (Processing fade)
    }

    object Spacing {
        val xs = 4.dp
        val sm = 8.dp
        val md = 16.dp
        val lg = 24.dp
        val xl = 32.dp
        val xxl = 48.dp
    }

    object Radius {
        val small  = 4.dp
        val medium = 8.dp
        val card   = 12.dp
        val large  = 16.dp
        val xLarge = 24.dp
    }

    object Gesture {
        const val SwipeBackThresholdPx  = 200f  // px — accumulated overscroll to trigger back
        val SwipeNavThresholdDp         = 80.dp // dp — single-frame delta to trigger navigation
    }

    object Button {
        val SizeDp = 220.dp
        const val PulseScaleMax = 1.6f
        const val PulseAlphaStart = 0.6f
        const val AlphaDisabled = 0.3f
        const val AlphaReduced = 0.5f
        const val AlphaFull = 1.0f
    }

    object StatusLine {
        const val ClearDelayMs = 4_000
        val GapAboveDp = 12.dp
    }

    object StreakDot {
        val SizeDp = 6.dp
        val SpacingDp = 6.dp
        val GapAboveDp = 10.dp
    }

    object StatsLine {
        val GapAboveDp = 6.dp
    }

    object LanguageLabel {
        val GapBelowDp = 20.dp
    }
}
