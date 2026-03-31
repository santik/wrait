package com.wrait.app.ui.main

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import android.provider.Settings
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextAlign
import com.wrait.app.RecordingState
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.domain.model.EntryStats
import com.wrait.app.ui.theme.DesignTokens
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
    onStatusCleared: () -> Unit,
    onStatusLineTap: () -> Unit,
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
            .pointerInput(onSwipeUp) {
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
                    if (totalY < -thresholdPx) onSwipeUp()
                }
            }
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Top
        ) {
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
                onTap = if (showBlockedMessage) onStatusLineTap else null,
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
private fun LanguageLabel(
    language: String,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val displayName = remember(language) {
        LANGUAGES.firstOrNull { it.code == language }?.displayName
            ?: Locale.forLanguageTag(language).displayLanguage
                .replaceFirstChar { it.uppercaseChar() }
    }
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
    onTap: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val hasEntries = stats.entryCount > 0
    val statusText = statusTextFor(recordingState, showBlockedMessage, hasEntries)
    val animationsEnabled = Settings.Global.getFloat(
        LocalContext.current.contentResolver,
        Settings.Global.ANIMATOR_DURATION_SCALE,
        1f
    ) != 0f
    val tapModifier = if (onTap != null) {
        Modifier
            .minimumInteractiveComponentSize()
            .clickable(
                indication = null,
                interactionSource = remember { MutableInteractionSource() },
                onClick = onTap,
            )
    } else {
        Modifier
    }
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
        modifier = modifier.then(tapModifier),
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
        is RecordingState.Uploading  -> "uploading\u2026"
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
