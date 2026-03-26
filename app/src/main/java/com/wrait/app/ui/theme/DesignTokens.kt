package com.wrait.app.ui.theme

import androidx.compose.ui.unit.dp

object DesignTokens {

    object Animation {
        const val FadeDuration = 300        // ms — standard fade in/out
        const val ShakeDuration = 400       // ms — error shake
        const val PulseDuration = 1800      // ms — recording pulse loop
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
        val small = 4.dp
        val medium = 8.dp
        val large = 16.dp
        val xLarge = 24.dp
    }

    object Gesture {
        const val SwipeBackThresholdPx = 200f   // px — accumulated overscroll to trigger back
        const val SwipeNavThresholdPx  = 80f    // px — single-frame delta to trigger navigation
    }
}
