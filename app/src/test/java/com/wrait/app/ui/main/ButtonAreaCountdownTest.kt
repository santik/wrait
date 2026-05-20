package com.wrait.app.ui.main

import com.wrait.app.data.speech.RecognitionConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ButtonAreaCountdownTest {

    @Test
    fun countdownProgress_hiddenBeforeFinalTenSeconds() {
        assertNull(
            countdownProgressForRemainingMillis(
                remainingMillis = RecognitionConfig.CountdownWindowMs + 1L,
                animationsEnabled = true,
            ),
        )
    }

    @Test
    fun countdownProgress_hiddenAtZeroAndBelow() {
        assertNull(countdownProgressForRemainingMillis(remainingMillis = 0L, animationsEnabled = true))
        assertNull(countdownProgressForRemainingMillis(remainingMillis = -1L, animationsEnabled = true))
    }

    @Test
    fun countdownProgress_hiddenForImplausibleFutureDeadline() {
        assertNull(
            countdownProgressForRemainingMillis(
                remainingMillis = RecognitionConfig.HardCapMs + 1_001L,
                animationsEnabled = true,
            ),
        )
    }

    @Test
    fun countdownProgress_fullAtCountdownWindowBoundary() {
        val progress = countdownProgressForRemainingMillis(
            remainingMillis = RecognitionConfig.CountdownWindowMs,
            animationsEnabled = true,
        )

        assertEquals(1.0f, progress ?: -1f, 0.0001f)
    }

    @Test
    fun countdownProgress_smoothWhenAnimationsEnabled() {
        val remainingMillis = RecognitionConfig.CountdownWindowMs / 2L
        val progress = countdownProgressForRemainingMillis(
            remainingMillis = remainingMillis,
            animationsEnabled = true,
        )

        assertEquals(
            remainingMillis.toFloat() / RecognitionConfig.CountdownWindowMs.toFloat(),
            progress ?: -1f,
            0.0001f,
        )
    }

    @Test
    fun countdownProgress_stepsWhenAnimationsDisabled() {
        if (RecognitionConfig.CountdownWindowMs <= 1_000L) {
            val progress = countdownProgressForRemainingMillis(
                remainingMillis = RecognitionConfig.CountdownWindowMs / 2L,
                animationsEnabled = false,
            )
            assertEquals(1.0f, progress ?: -1f, 0.0001f)
            return
        }

        val progressAtOnePointOneSeconds = countdownProgressForRemainingMillis(
            remainingMillis = minOf(RecognitionConfig.CountdownWindowMs, 1_100L),
            animationsEnabled = false,
        )
        val progressAtZeroPointNineSeconds = countdownProgressForRemainingMillis(
            remainingMillis = 900L,
            animationsEnabled = false,
        )

        assertEquals(
            2f / (RecognitionConfig.CountdownWindowMs / 1_000f),
            progressAtOnePointOneSeconds ?: -1f,
            0.0001f,
        )
        assertEquals(
            1f / (RecognitionConfig.CountdownWindowMs / 1_000f),
            progressAtZeroPointNineSeconds ?: -1f,
            0.0001f,
        )
    }

    @Test
    fun countdownDeadlinePlausibility_rejectsFarFutureValues() {
        assertEquals(
            false,
            isCountdownDeadlinePlausible(RecognitionConfig.HardCapMs + 1_001L),
        )
        assertEquals(
            true,
            isCountdownDeadlinePlausible(RecognitionConfig.HardCapMs + 1_000L),
        )
    }
}
