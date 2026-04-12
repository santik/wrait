package com.wrait.app.ui.theme

import androidx.compose.ui.unit.dp

object DesignTokens {

    object Animation {
        const val FadeDuration = 300        // ms — standard fade in/out
        const val ShakeDuration = 310       // ms — error shake (~310ms total, 5 steps)
        const val PulseDuration = 1800      // ms — recording pulse loop
        const val DeleteFadeDuration = 200  // ms — deleted card fade out in LazyColumn
        const val SwipeDeleteFlingDurationMs = 250 // ms — swipe-to-delete snap animation
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

        // Swipe-to-delete card reveal
        val SwipeDeleteRevealDp = 80.dp  // how far the card slides before stopping
    }

    object Button {
        // Adaptive size: buttonSize = containerWidthDp × ScreenWidthRatio, clamped to [SizeMin, SizeMax].
        // Width is read from LocalWindowInfo.containerSize (px → dp) so it is accurate in
        // multi-window and foldable scenarios where Configuration.screenWidthDp can lag.
        //
        // Calibration: 393 dp (Pixel 8) × 0.56 = 220 dp — matches the original design intent.
        //
        // Landscape: a phone rotated to landscape (e.g. Pixel 8 ≈ 852 dp wide) would compute
        // 477 dp — far too large — so SizeMax caps it at 280 dp, keeping the button prominent
        // without overflowing the layout.
        //
        // EntryListScreen / EntryDetailScreen: pure text/list layouts; Material's default column
        // width and sp-based typography already adapt to screen size, so no explicit responsive
        // overrides are needed for S-043.
        const val ScreenWidthRatio = 0.56f
        val SizeMin = 160.dp   // floor: prevents button becoming tiny in split-screen / narrow windows
        val SizeMax = 280.dp   // ceiling: caps tablets and landscape phones at a sensible size
        const val PulseScaleMax = 1.6f
        const val PulseAlphaStart = 0.6f
        const val AlphaDisabled = 0.3f
        const val AlphaReduced = 0.5f
        const val AlphaFull = 1.0f
    }

    object StatusLine {
        const val ClearDelayMs = 4_000
        val GapAboveDp = 12.dp
        val MinHeightDp = 24.dp
    }

    object StatsLine {
        val GapAboveDp = 16.dp
    }

    object LanguageLabel {
        val GapBelowDp = 20.dp
    }
}
