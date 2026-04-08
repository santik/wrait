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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextAlign
import com.wrait.app.RecordingState
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.domain.model.EntryStats
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.ui.theme.DesignTokens
import com.wrait.app.ui.settings.SettingsPanel
import kotlinx.coroutines.delay
import java.util.Locale

@Composable
fun MainScreen(
    recordingState: RecordingState,
    showBlockedMessage: Boolean,
    shakeErrorKey: Int,
    stats: EntryStats,
    selectedLanguage: String,
    hasEverRecorded: Boolean,
    showSettingsPanel: Boolean,
    privacyMode: PrivacyMode,
    onButtonTap: () -> Unit,
    onLanguageTap: () -> Unit,
    onSwipeUp: () -> Unit,
    onSwipeDown: () -> Unit,
    onPrivacyModeToggle: (Boolean) -> Unit,
    onSettingsPanelDismiss: () -> Unit,
    onStatusCleared: () -> Unit,
    onTapToRead: (entryId: Long) -> Unit,
    onStatusLineTap: () -> Unit,
    onStatsLineTap: () -> Unit,
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
    val currentShowSettingsPanel by rememberUpdatedState(showSettingsPanel)
    val swipesEnabled by rememberUpdatedState(!recordingState.isActive)

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .pointerInput(onSwipeUp, onSwipeDown) {
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
                    if (swipesEnabled && !currentShowSettingsPanel) {
                        if (totalY < -thresholdPx) onSwipeUp()
                        if (totalY > thresholdPx) onSwipeDown()
                    }
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
                hasEverRecorded = hasEverRecorded,
                onTap = when {
                    showBlockedMessage -> onStatusLineTap
                    recordingState is RecordingState.Saved -> run {
                        val entryId = recordingState.entryId
                        { onStatusCleared(); onTapToRead(entryId) }
                    }
                    recordingState is RecordingState.Idle && !hasEverRecorded -> onButtonTap
                    else -> null
                },
            )
            Spacer(Modifier.height(DesignTokens.StatsLine.GapAboveDp))
            // Stats
            StatsLine(
                stats = stats,
                onTap = if (recordingState is RecordingState.Listening ||
                    recordingState is RecordingState.Processing ||
                    recordingState is RecordingState.Uploading
                ) {
                    null
                } else {
                    onStatsLineTap
                }
            )
            // Lower flex spacer
            Spacer(Modifier.weight(1f))
        }

        if (showSettingsPanel) {
            SettingsPanel(
                privacyMode = privacyMode,
                onModeToggle = onPrivacyModeToggle,
                onDismiss = onSettingsPanelDismiss,
            )
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
    hasEverRecorded: Boolean,
    onTap: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val statusText = statusTextFor(recordingState, showBlockedMessage, hasEverRecorded)
    val animationsEnabled = Settings.Global.getFloat(
        LocalContext.current.contentResolver,
        Settings.Global.ANIMATOR_DURATION_SCALE,
        1f
    ) != 0f
    val clickModifier = if (onTap != null) {
        Modifier.clickable(
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
        modifier = modifier
            .minimumInteractiveComponentSize()
            .then(clickModifier),
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
private fun StatsLine(
    stats: EntryStats,
    onTap: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val clickModifier = if (onTap != null) {
        Modifier.clickable(
            indication = null,
            interactionSource = remember { MutableInteractionSource() },
            onClick = onTap,
        )
    } else {
        Modifier
    }
    Box(
        modifier = modifier
            .minimumInteractiveComponentSize()
            .then(clickModifier),
        contentAlignment = Alignment.Center,
    ) {
        if (stats.entryCount > 0) {
            Text(
                text = "${stats.entryCount} entries · ${stats.activeDays} days" +
                    (if (onTap != null) " \u203a" else ""),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onBackground,
            )
        }
    }
}

// --- Pure helper functions ---

internal fun statusTextFor(
    recordingState: RecordingState,
    showBlockedMessage: Boolean,
    hasEverRecorded: Boolean,
): String {
    if (showBlockedMessage) return "mic blocked · tap to open settings"
    return when (recordingState) {
        is RecordingState.Idle       -> if (!hasEverRecorded) "tap to write" else ""
        is RecordingState.Listening  -> "listening\u2026"
        is RecordingState.Uploading  -> "uploading\u2026"
        is RecordingState.Processing -> "cleaning up\u2026"
        is RecordingState.Saved      -> if (recordingState.detectedLanguage != null) {
                                            val name = LANGUAGES
                                                .firstOrNull { it.code.substringBefore("-").lowercase() == recordingState.detectedLanguage.lowercase() }
                                                ?.displayName
                                                ?: Locale.forLanguageTag(recordingState.detectedLanguage).displayLanguage
                                            "tap to read · detected $name"
                                        } else "tap to read"
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
