package com.wrait.app.ui.main

import com.wrait.app.ui.theme.DesignTokens
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Verifies the ratio-based button sizing logic used in ButtonArea.
 *
 * The formula:
 *   buttonSize = (screenWidthDp * ScreenWidthRatio).coerceIn(SizeMin, SizeMax)
 *
 * is intentionally kept as inline code in ButtonArea (no separate function to call)
 * so these tests replicate the formula directly, ensuring they stay in lock-step
 * with DesignTokens constants.
 */
class ButtonSizeTest {

    private fun buttonSizeDp(screenWidthDp: Int): Float =
        (screenWidthDp * DesignTokens.Button.ScreenWidthRatio)
            .coerceIn(
                DesignTokens.Button.SizeMin.value,
                DesignTokens.Button.SizeMax.value,
            )

    @Test
    fun pixel8_393dp_yields_approximately_220dp() {
        val size = buttonSizeDp(393)
        // 393 × 0.56 = 220.08 — should sit at ~220 dp, well above the 160 dp floor
        assertEquals(220.08f, size, 0.1f)
    }

    @Test
    fun pixel8Pro_412dp_yields_approximately_231dp() {
        val size = buttonSizeDp(412)
        assertEquals(230.72f, size, 0.1f)
    }

    @Test
    fun narrowWindow_200dp_is_clamped_to_SizeMin() {
        val size = buttonSizeDp(200)
        // 200 × 0.56 = 112 dp — below SizeMin floor
        assertEquals(DesignTokens.Button.SizeMin.value, size, 0.01f)
    }

    @Test
    fun wideTablet_960dp_is_clamped_to_SizeMax() {
        val size = buttonSizeDp(960)
        // 960 × 0.56 = 537.6 dp — above SizeMax ceiling
        assertEquals(DesignTokens.Button.SizeMax.value, size, 0.01f)
    }

    @Test
    fun phoneLandscape_852dp_is_clamped_to_SizeMax() {
        // Pixel 8 landscape width is ~852 dp; ratio gives ~477 dp which is capped.
        val size = buttonSizeDp(852)
        assertEquals(DesignTokens.Button.SizeMax.value, size, 0.01f)
    }

    @Test
    fun result_is_always_within_min_max_bounds() {
        val widths = listOf(100, 200, 320, 393, 412, 600, 840, 960, 1280)
        for (w in widths) {
            val size = buttonSizeDp(w)
            assertTrue(
                "Width $w dp: size $size dp is below SizeMin",
                size >= DesignTokens.Button.SizeMin.value,
            )
            assertTrue(
                "Width $w dp: size $size dp is above SizeMax",
                size <= DesignTokens.Button.SizeMax.value,
            )
        }
    }
}
