package com.wrait.app.ui.main

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import android.provider.Settings
import androidx.compose.ui.platform.LocalContext
import com.wrait.app.ui.theme.DesignTokens

@Composable
internal fun PulseRing(modifier: Modifier = Modifier) {
    val animationsEnabled = Settings.Global.getFloat(
        LocalContext.current.contentResolver,
        Settings.Global.ANIMATOR_DURATION_SCALE,
        1f
    ) != 0f

    // With reduce-motion on, skip the ring entirely — no animation plays.
    if (!animationsEnabled) return

    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val scale by infiniteTransition.animateFloat(
        initialValue = 1.0f,
        targetValue = DesignTokens.Button.PulseScaleMax,
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = DesignTokens.Animation.PulseDuration,
                easing = EaseOut
            ),
            repeatMode = RepeatMode.Restart
        ),
        label = "pulseScale"
    )
    val alpha by infiniteTransition.animateFloat(
        initialValue = DesignTokens.Button.PulseAlphaStart,
        targetValue = 0.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = DesignTokens.Animation.PulseDuration,
                easing = EaseOut
            ),
            repeatMode = RepeatMode.Restart
        ),
        label = "pulseAlpha"
    )
    val color = MaterialTheme.colorScheme.primary
    Canvas(modifier = modifier) {
        val radius = (size.minDimension / 2f) * scale
        drawCircle(
            color = color.copy(alpha = alpha),
            radius = radius
        )
    }
}
