package com.wrait.app.ui.main

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.*
import androidx.compose.animation.fadeIn
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
import android.provider.Settings
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.wrait.app.RecordingState
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.ui.theme.DesignTokens

@Composable
internal fun ButtonArea(
    recordingState: RecordingState,
    showBlockedMessage: Boolean,
    shakeErrorKey: Int,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val animationsEnabled = Settings.Global.getFloat(
        LocalContext.current.contentResolver,
        Settings.Global.ANIMATOR_DURATION_SCALE,
        1f
    ) != 0f

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

    // --- dashed border for MicBlocked — always composed, fades in/out via alpha ---
    val isMicBlocked = showBlockedMessage ||
        (recordingState is RecordingState.Error &&
         recordingState.error == RecognizerError.InsufficientPermissions)
    val borderColor = MaterialTheme.colorScheme.error
    val dashedBorderAlpha by animateFloatAsState(
        targetValue = if (isMicBlocked) 1f else 0f,
        animationSpec = if (animationsEnabled)
            tween(durationMillis = DesignTokens.Animation.FadeDuration)
        else
            snap(),
        label = "dashedBorderAlpha"
    )
    val dashedBorderModifier = Modifier.drawBehind {
        val dashWidth  = DesignTokens.Button.DashedBorderDash.toPx()
        val gapWidth   = DesignTokens.Button.DashedBorderGap.toPx()
        val strokeWidth = DesignTokens.Button.DashedBorderWidth.toPx()
        drawCircle(
            color = borderColor.copy(alpha = dashedBorderAlpha),
            radius = (size.minDimension / 2f) - strokeWidth / 2f,
            style = Stroke(
                width = strokeWidth,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(dashWidth, gapWidth), 0f)
            )
        )
    }

    val isEnabled = recordingState !is RecordingState.Processing
    val isListening = recordingState is RecordingState.Listening

    val label = buttonLabelFor(recordingState)

    Box(
        modifier = modifier
            .size(DesignTokens.Button.SizeDp * 2f)  // fixed — prevents layout shift when PulseRing appears
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

private fun buttonLabelFor(recordingState: RecordingState): String =
    if (recordingState is RecordingState.Listening) "stop" else "wrait"

internal fun buttonAlphaFor(recordingState: RecordingState, showBlockedMessage: Boolean): Float {
    if (showBlockedMessage) return DesignTokens.Button.AlphaDisabled
    return when (recordingState) {
        is RecordingState.Processing -> DesignTokens.Button.AlphaDisabled
        is RecordingState.Error -> when (recordingState.error) {
            RecognizerError.InsufficientPermissions -> DesignTokens.Button.AlphaDisabled
            else -> DesignTokens.Button.AlphaFull
        }
        else -> DesignTokens.Button.AlphaFull
    }
}
