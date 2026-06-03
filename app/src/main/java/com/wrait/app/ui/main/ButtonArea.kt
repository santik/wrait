package com.wrait.app.ui.main

import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.*
import androidx.compose.animation.fadeIn
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.wrait.app.R
import com.wrait.app.RecordingCountdownState
import com.wrait.app.RecordingState
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.data.speech.RecognitionConfig
import com.wrait.app.ui.theme.DesignTokens
import kotlin.math.ceil
import kotlinx.coroutines.delay

private const val CountdownDeadlineToleranceMs = 1_000L
private const val CountdownReducedMotionPollIntervalMs = 100L
private const val CountdownReducedMotionStepMillis = 1_000f
private const val ButtonAreaTag = "ButtonArea"

@Composable
internal fun ButtonArea(
    recordingState: RecordingState,
    recordingCountdown: RecordingCountdownState?,
    showBlockedMessage: Boolean,
    shakeErrorKey: Int,
    onTap: () -> Unit,
    // Test-only seam for deterministic rendering assertions.
    countdownProgressOverride: Float? = null,
    modifier: Modifier = Modifier,
) {
    val animationsEnabled = Settings.Global.getFloat(
        LocalContext.current.contentResolver,
        Settings.Global.ANIMATOR_DURATION_SCALE,
        1f
    ) != 0f

    val buttonSize = rememberAdaptiveActionButtonSize()

    // --- alpha ---
    val targetAlpha = buttonAlphaFor(recordingState, showBlockedMessage)
    val animatedAlpha by animateFloatAsState(
        targetValue = targetAlpha,
        animationSpec = if (animationsEnabled)
            tween(durationMillis = DesignTokens.Animation.ButtonAlphaDuration)
        else
            snap(),
        label = "buttonAlpha"
    )

    // --- shake ---
    // LaunchedEffect keyed on shakeErrorKey (incremented per shake-eligible error in
    // MainViewModel) ensures the shake re-fires even when the same Error state is
    // emitted twice in succession.
    val shakeOffset = remember { Animatable(0f) }
    LaunchedEffect(shakeErrorKey) {
        if (shakeErrorKey == 0) return@LaunchedEffect  // initial value — no shake on first compose
        if (!animationsEnabled) return@LaunchedEffect   // respect reduce-motion
        shakeOffset.snapTo(0f)
        shakeOffset.animateTo(-6f, tween(50))
        shakeOffset.animateTo( 6f, tween(80))
        shakeOffset.animateTo(-4f, tween(70))
        shakeOffset.animateTo( 3f, tween(60))
        shakeOffset.animateTo( 0f, tween(50))
    }

    val isEnabled = recordingState !is RecordingState.Processing && recordingState !is RecordingState.Uploading
    val isListening = recordingState is RecordingState.Listening
    val countdownProgress = countdownProgressOverride ?: rememberCountdownRingProgress(
        recordingState = recordingState,
        recordingCountdown = recordingCountdown,
        animationsEnabled = animationsEnabled,
    )

    val label = buttonLabelFor(recordingState)
    val buttonDescription = stringResource(R.string.main_button_description)
    val countdownRingColor = MaterialTheme.colorScheme.onPrimary

    Box(
        modifier = modifier
            .size(buttonSize * 2f)  // fixed — prevents layout shift when PulseRing appears
            .alpha(animatedAlpha)
            .offset(x = shakeOffset.value.dp),
        contentAlignment = Alignment.Center
    ) {
        // Pulse ring behind button — only composed when Listening.
        // ExitTransition.None removes the composable immediately so the InfiniteTransition
        // stops on the frame the state leaves Listening (spec: "stop immediately").
        AnimatedVisibility(
            visible = isListening,
            enter = fadeIn(),
            exit = ExitTransition.None
        ) {
            PulseRing(
                modifier = Modifier
                    .size(buttonSize * 2f)
                    .testTag("recording_pulse_ring")
            )
        }

        // The button itself
        Box(
            modifier = Modifier
                .size(buttonSize)
                .semantics(mergeDescendants = true) {
                    contentDescription = buttonDescription
                }
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primary)
                .clickable(enabled = isEnabled, onClick = onTap),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onPrimary,
            )
        }

        if (countdownProgress != null) {
            Canvas(
                modifier = Modifier
                    .size(buttonSize)
                    .testTag("recording_countdown_ring"),
            ) {
                val strokeWidthPx = DesignTokens.Button.CountdownStrokeWidth.toPx()
                val inset = strokeWidthPx / 2f
                drawArc(
                    color = countdownRingColor,
                    startAngle = -90f,
                    sweepAngle = countdownProgress * 360f,
                    useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = Size(size.width - strokeWidthPx, size.height - strokeWidthPx),
                    style = Stroke(width = strokeWidthPx, cap = StrokeCap.Round),
                )
            }
        }
    }
}

private fun buttonLabelFor(recordingState: RecordingState): String = when (recordingState) {
    is RecordingState.Listening -> "stop"
    else -> "wrait"
}

internal fun buttonAlphaFor(recordingState: RecordingState, showBlockedMessage: Boolean): Float {
    if (showBlockedMessage) return DesignTokens.Button.AlphaDisabled
    return when (recordingState) {
        is RecordingState.Processing,
        is RecordingState.Uploading  -> DesignTokens.Button.AlphaDisabled
        is RecordingState.Error -> when (recordingState.error) {
            RecognizerError.InsufficientPermissions -> DesignTokens.Button.AlphaReduced
            else -> DesignTokens.Button.AlphaFull
        }
        else -> DesignTokens.Button.AlphaFull
    }
}

@Composable
private fun rememberCountdownRingProgress(
    recordingState: RecordingState,
    recordingCountdown: RecordingCountdownState?,
    animationsEnabled: Boolean,
): Float? {
    val deadline = recordingCountdown?.hardCapDeadlineElapsedRealtime ?: return null
    if (recordingState !is RecordingState.Listening) return null

    val progress by produceState<Float?>(
        initialValue = countdownProgressForRemainingMillis(
            remainingMillis = deadline - SystemClock.elapsedRealtime(),
            animationsEnabled = animationsEnabled,
        ),
        key1 = deadline,
        key2 = animationsEnabled,
        key3 = recordingState,
    ) {
        var loggedOutOfRangeDeadline = false
        while (true) {
            val remainingMillis = deadline - SystemClock.elapsedRealtime()
            if (!isCountdownDeadlinePlausible(remainingMillis)) {
                Log.w(
                    ButtonAreaTag,
                    "Ignoring implausible countdown deadline: remainingMillis=$remainingMillis hardCapMs=${RecognitionConfig.HardCapMs}",
                )
                value = null
                break
            }
            val progress = countdownProgressForRemainingMillis(
                remainingMillis = remainingMillis,
                animationsEnabled = animationsEnabled,
            )
            if (progress == null &&
                remainingMillis > RecognitionConfig.HardCapMs &&
                !loggedOutOfRangeDeadline
            ) {
                loggedOutOfRangeDeadline = true
                Log.w(
                    ButtonAreaTag,
                    "Countdown deadline exceeds hard cap; hiding ring until remainingMillis falls within hardCapMs " +
                        "(remainingMillis=$remainingMillis hardCapMs=${RecognitionConfig.HardCapMs})",
                )
            }
            value = progress
            if (remainingMillis <= 0L) break
            if (animationsEnabled) {
                withFrameNanos { }
            } else {
                delay(CountdownReducedMotionPollIntervalMs)
            }
        }
    }
    return progress
}

internal fun countdownProgressForRemainingMillis(
    remainingMillis: Long,
    animationsEnabled: Boolean,
): Float? {
    if (!isCountdownDeadlinePlausible(remainingMillis)) {
        return null
    }
    if (remainingMillis <= 0L || remainingMillis > RecognitionConfig.HardCapMs) {
        return null
    }

    return if (animationsEnabled) {
        remainingMillis.toFloat() / RecognitionConfig.HardCapMs.toFloat()
    } else {
        ceil(remainingMillis / CountdownReducedMotionStepMillis)
            .coerceIn(1f, RecognitionConfig.HardCapMs / CountdownReducedMotionStepMillis) /
            (RecognitionConfig.HardCapMs / CountdownReducedMotionStepMillis)
    }
}

internal fun isCountdownDeadlinePlausible(remainingMillis: Long): Boolean =
    remainingMillis <= RecognitionConfig.HardCapMs + CountdownDeadlineToleranceMs
