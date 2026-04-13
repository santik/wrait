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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.offset
import android.provider.Settings
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.unit.dp
import com.wrait.app.R
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

    // Button scales with actual container width: ~220 dp on Pixel 8 (393 dp wide),
    // larger on tablets, clamped so it never goes absurdly small or large.
    // LocalWindowInfo.containerSize reflects the real window in multi-window / foldable
    // scenarios where Configuration.screenWidthDp can lag or be inaccurate.
    // remember(containerWidthDp) skips recalculation on unrelated config changes
    // (locale, font-scale) while still reacting to rotation / window resize.
    val density = LocalDensity.current
    val containerWidthDp = with(density) { LocalWindowInfo.current.containerSize.width.toDp() }
    val buttonSize = remember(containerWidthDp) {
        (containerWidthDp.value * DesignTokens.Button.ScreenWidthRatio)
            .coerceIn(DesignTokens.Button.SizeMin.value, DesignTokens.Button.SizeMax.value).dp
    }

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

    val label = buttonLabelFor(recordingState)
    val buttonDescription = stringResource(R.string.main_button_description)

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
                modifier = Modifier.size(buttonSize * 2f)
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
    }
}

private fun buttonLabelFor(recordingState: RecordingState): String =
    if (recordingState is RecordingState.Listening) "stop" else "wrait"

internal fun buttonAlphaFor(recordingState: RecordingState, showBlockedMessage: Boolean): Float {
    if (showBlockedMessage) return DesignTokens.Button.AlphaDisabled
    return when (recordingState) {
        is RecordingState.Processing,
        is RecordingState.Uploading  -> DesignTokens.Button.AlphaDisabled
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
