package com.wrait.app.ui.main

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.*
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.foundation.layout.offset
import androidx.compose.ui.unit.dp
import com.wrait.app.RecordingState
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.ui.theme.DesignTokens

@Composable
internal fun ButtonArea(
    recordingState: RecordingState,
    showBlockedMessage: Boolean,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // --- alpha ---
    val targetAlpha = buttonAlphaFor(recordingState, showBlockedMessage)
    val animatedAlpha by animateFloatAsState(
        targetValue = targetAlpha,
        animationSpec = tween(durationMillis = DesignTokens.Animation.FadeDuration),
        label = "buttonAlpha"
    )

    // --- shake ---
    val shakeOffset = remember { Animatable(0f) }
    val shouldShake = recordingState is RecordingState.Error &&
        (recordingState.error == RecognizerError.NoMatch ||
         recordingState.error == RecognizerError.TooShort)
    LaunchedEffect(recordingState) {
        if (shouldShake) {
            shakeOffset.animateTo(
                targetValue = 0f,
                animationSpec = keyframes {
                    durationMillis = DesignTokens.Animation.ShakeDuration
                    0f   at 0
                    -12f at 50
                    12f  at 100
                    -10f at 160
                    10f  at 220
                    -6f  at 290
                    6f   at 340
                    0f   at 400
                }
            )
        }
    }

    // --- dashed border for MicBlocked ---
    val isMicBlocked = showBlockedMessage ||
        (recordingState is RecordingState.Error &&
         recordingState.error == RecognizerError.InsufficientPermissions)
    val borderColor = MaterialTheme.colorScheme.error
    val dashedBorderModifier = if (isMicBlocked) {
        Modifier.drawBehind {
            val dashWidth = DesignTokens.Button.DashedBorderDash.toPx()
            val gapWidth  = DesignTokens.Button.DashedBorderGap.toPx()
            val strokeWidth = DesignTokens.Button.DashedBorderWidth.toPx()
            drawCircle(
                color = borderColor,
                radius = (size.minDimension / 2f) - strokeWidth / 2f,
                style = Stroke(
                    width = strokeWidth,
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(dashWidth, gapWidth), 0f)
                )
            )
        }
    } else Modifier

    val isEnabled = recordingState !is RecordingState.Processing
    val isListening = recordingState is RecordingState.Listening

    val label = buttonLabelFor(recordingState, showBlockedMessage)

    Box(
        modifier = modifier
            .size(DesignTokens.Button.SizeDp * 2f)  // fixed — prevents layout shift when PulseRing appears
            .alpha(animatedAlpha)
            .offset(x = shakeOffset.value.dp),
        contentAlignment = Alignment.Center
    ) {
        // Pulse ring behind button — only composed when Listening
        AnimatedVisibility(
            visible = isListening,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            PulseRing(
                modifier = Modifier.size(DesignTokens.Button.SizeDp * 2f)
            )
        }

        // The button itself
        Box(
            modifier = Modifier
                .size(DesignTokens.Button.SizeDp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primary)
                .then(dashedBorderModifier)
                .clickable(enabled = isEnabled, onClick = onTap),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onPrimary,
            )
        }
    }
}

private fun buttonLabelFor(recordingState: RecordingState, showBlockedMessage: Boolean): String =
    if (recordingState is RecordingState.Listening) "stop" else "wrait"

internal fun buttonAlphaFor(recordingState: RecordingState, showBlockedMessage: Boolean): Float {
    if (showBlockedMessage) return DesignTokens.Button.AlphaDisabled
    return when (recordingState) {
        is RecordingState.Processing -> DesignTokens.Button.AlphaDisabled
        is RecordingState.Error -> when (recordingState.error) {
            RecognizerError.InsufficientPermissions -> DesignTokens.Button.AlphaDisabled
            RecognizerError.NoInternet,
            RecognizerError.Network,
            RecognizerError.Timeout -> DesignTokens.Button.AlphaReduced
            else -> DesignTokens.Button.AlphaFull
        }
        else -> DesignTokens.Button.AlphaFull
    }
}
