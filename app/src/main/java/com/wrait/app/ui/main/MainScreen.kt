package com.wrait.app.ui.main

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import android.provider.Settings
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextAlign
import com.wrait.app.RecordingState
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.domain.model.EntryStats
import com.wrait.app.ui.theme.DesignTokens
import com.wrait.app.ui.theme.LocalWraitSemanticColors
import kotlinx.coroutines.delay
import java.util.Locale

@Composable
fun MainScreen(
    recordingState: RecordingState,
    showBlockedMessage: Boolean,
    shakeErrorKey: Int,
    stats: EntryStats,
    selectedLanguage: String,
    onButtonTap: () -> Unit,
    onLanguageTap: () -> Unit,
    onSwipeUp: () -> Unit,
    onSwipeDown: () -> Unit,
    onStatusCleared: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // Saved auto-clear
    LaunchedEffect(recordingState) {
        if (recordingState is RecordingState.Saved) {
            delay(DesignTokens.StatusLine.ClearDelayMs.toLong())
            onStatusCleared()
        }
    }

    val density = LocalDensity.current

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .pointerInput(onSwipeUp, onSwipeDown) {
                // Accumulate total drag so the threshold is a total-distance check,
                // not a per-frame-delta check (which never fires at 80dp/frame).
                // requireUnconsumed = false so we receive the down event even when
                // a child composable (e.g. the button's clickable) already consumed it.
                val thresholdPx = with(density) { DesignTokens.Gesture.SwipeNavThresholdDp.toPx() }
                awaitEachGesture {
                    val down = awaitFirstDown(requireUnconsumed = false)
                    var totalY = 0f
                    while (true) {
                        val event = awaitPointerEvent()
                        val change = event.changes.firstOrNull { it.id == down.id } ?: break
                        totalY += change.position.y - change.previousPosition.y
                        if (!change.pressed) break
                    }
                    when {
                        totalY < -thresholdPx -> onSwipeUp()
                        totalY > thresholdPx  -> onSwipeDown()
                    }
                }
            }
    ) {
        TopStrip(
            recordingState = recordingState,
            showBlockedMessage = showBlockedMessage,
            modifier = Modifier.align(Alignment.TopCenter)
        )

        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Top
        ) {
            // Reserve space for the top strip
            Spacer(Modifier.height(DesignTokens.TopStrip.HeightDp))
            // Upper flex spacer
            Spacer(Modifier.weight(1f))
            // Language label
            LanguageLabel(language = selectedLanguage, onTap = onLanguageTap)
            Spacer(Modifier.height(DesignTokens.LanguageLabel.GapBelowDp))
            // Button
            ButtonArea(
                recordingState = recordingState,
                showBlockedMessage = showBlockedMessage,
                shakeErrorKey = shakeErrorKey,
                onTap = onButtonTap,
            )
            Spacer(Modifier.height(DesignTokens.StatusLine.GapAboveDp))
            // Status line
            StatusLine(
                recordingState = recordingState,
                showBlockedMessage = showBlockedMessage,
                stats = stats,
            )
            Spacer(Modifier.height(DesignTokens.StreakDot.GapAboveDp))
            // Streak dots
            StreakDots(streakDays = stats.streakDays)
            Spacer(Modifier.height(DesignTokens.StatsLine.GapAboveDp))
            // Stats
            StatsLine(stats = stats)
            // Lower flex spacer
            Spacer(Modifier.weight(1f))
        }
    }
}

@Composable
private fun TopStrip(
    recordingState: RecordingState,
    showBlockedMessage: Boolean,
    modifier: Modifier = Modifier,
) {
    val colorScheme = MaterialTheme.colorScheme
    val warningColor = LocalWraitSemanticColors.current.warning
    val animationsEnabled = Settings.Global.getFloat(
        LocalContext.current.contentResolver,
        Settings.Global.ANIMATOR_DURATION_SCALE,
        1f
    ) != 0f

    val targetColor = stripColorFor(recordingState, showBlockedMessage, colorScheme.error, warningColor)
    val animatedColor by animateColorAsState(
        targetValue = targetColor,
        animationSpec = if (animationsEnabled)
            tween(durationMillis = DesignTokens.Animation.StripColorDuration)
        else
            snap(),
        label = "stripColor"
    )
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(DesignTokens.TopStrip.HeightDp)
            .background(animatedColor)
    )
}

@Composable
private fun LanguageLabel(
    language: String,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // Look up display name from the hardcoded list so it renders in the language's
    // own script (e.g. "Русский", not "Russian"). Fall back to system locale name
    // for languages not in the list.
    val displayName = remember(language) {
        LANGUAGES.firstOrNull { it.code == language }?.displayName
            ?: Locale.forLanguageTag(language).displayLanguage
                .replaceFirstChar { it.uppercaseChar() }
    }
    // Box with minimumInteractiveComponentSize guarantees a 48dp tap target even
    // though the text itself is small (labelSmall / 11sp).
    Box(
        modifier = modifier
            .minimumInteractiveComponentSize()
            .clickable(onClick = onTap),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text  = "$displayName \u203a",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.tertiary,
        )
    }
}

@Composable
private fun StatusLine(
    recordingState: RecordingState,
    showBlockedMessage: Boolean,
    stats: EntryStats,
    modifier: Modifier = Modifier,
) {
    val hasEntries = stats.entryCount > 0
    val statusText = statusTextFor(recordingState, showBlockedMessage, hasEntries)
    val animationsEnabled = Settings.Global.getFloat(
        LocalContext.current.contentResolver,
        Settings.Global.ANIMATOR_DURATION_SCALE,
        1f
    ) != 0f
    AnimatedContent(
        targetState = statusText,
        transitionSpec = {
            if (animationsEnabled) {
                fadeIn(animationSpec = tween(DesignTokens.Animation.FadeDuration)) togetherWith
                fadeOut(animationSpec = tween(DesignTokens.Animation.FadeDuration))
            } else {
                EnterTransition.None togetherWith ExitTransition.None
            }
        },
        label = "statusLine",
        modifier = modifier,
    ) { text ->
        Text(
            text = text,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onBackground,
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
    }
}

@Composable
private fun StreakDots(
    streakDays: List<Boolean>,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(DesignTokens.StreakDot.SpacingDp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        streakDays.forEach { active ->
            Box(
                modifier = Modifier
                    .size(DesignTokens.StreakDot.SizeDp)
                    .clip(CircleShape)
                    .background(
                        if (active) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onBackground.copy(alpha = 0.35f)
                    )
            )
        }
    }
}

@Composable
private fun StatsLine(
    stats: EntryStats,
    modifier: Modifier = Modifier,
) {
    if (stats.entryCount > 0) {
        Text(
            text = "${stats.entryCount} entries · ${stats.activeDays} days",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onBackground,
            modifier = modifier,
        )
    }
}

// --- Pure helper functions ---

private fun statusTextFor(
    recordingState: RecordingState,
    showBlockedMessage: Boolean,
    hasEntries: Boolean,
): String {
    if (showBlockedMessage) return "mic blocked · tap to open settings"
    return when (recordingState) {
        is RecordingState.Idle       -> if (hasEntries) "" else "tap to write"
        is RecordingState.Listening  -> "listening\u2026"
        is RecordingState.Processing -> "cleaning up\u2026"
        is RecordingState.Saved      -> "entry saved · swipe up to read"
        is RecordingState.Deleted    -> if (recordingState.count == 1) "entry deleted"
                                        else "${recordingState.count} entries deleted"
        is RecordingState.Error      -> when (recordingState.error) {
            RecognizerError.InsufficientPermissions -> "mic blocked · tap to open settings"
            RecognizerError.NoMatch                 -> "nothing caught · too quiet?"
            RecognizerError.TooShort                -> "too short · keep talking"
            RecognizerError.NoInternet,
            RecognizerError.Network,
            RecognizerError.Timeout                 -> "no connection · saved as draft"
            else                                    -> "saved as draft · will retry"
        }
    }
}

private fun stripColorFor(
    recordingState: RecordingState,
    showBlockedMessage: Boolean,
    errorColor: Color,
    warningColor: Color,
): Color {
    if (showBlockedMessage) return errorColor
    return when (recordingState) {
        is RecordingState.Error -> when (recordingState.error) {
            RecognizerError.InsufficientPermissions -> errorColor
            RecognizerError.NoInternet,
            RecognizerError.Network,
            RecognizerError.Timeout,
            RecognizerError.ApiFailed,
            RecognizerError.Server,
            RecognizerError.Client,
            RecognizerError.Audio,
            RecognizerError.NotAvailable            -> warningColor
            is RecognizerError.Unknown              -> warningColor
            else                                    -> Color.Transparent
        }
        else -> Color.Transparent
    }
}
