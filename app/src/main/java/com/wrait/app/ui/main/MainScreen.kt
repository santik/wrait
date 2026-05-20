package com.wrait.app.ui.main

import android.provider.Settings
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import com.wrait.app.R
import com.wrait.app.RecordingCountdownState
import com.wrait.app.RecordingState
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.domain.model.EntryStats
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.ui.settings.SettingsPanel
import com.wrait.app.ui.theme.DesignTokens
import kotlinx.coroutines.delay

@Composable
fun MainScreen(
    recordingState: RecordingState,
    recordingCountdown: RecordingCountdownState?,
    showBlockedMessage: Boolean,
    shakeErrorKey: Int,
    stats: EntryStats,
    languageSummary: String,
    hasEverRecorded: Boolean,
    showSettingsPanel: Boolean,
    privacyMode: PrivacyMode,
    onButtonTap: () -> Unit,
    onLanguagesTap: () -> Unit,
    onSwipeUp: () -> Unit,
    onOpenSettings: () -> Unit,
    onPrivacyModeToggle: (Boolean) -> Unit,
    onSettingsPanelDismiss: () -> Unit,
    onStatusCleared: () -> Unit,
    onTapToRead: (entryId: Long) -> Unit,
    onStatusLineTap: () -> Unit,
    onStatsLineTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    LaunchedEffect(recordingState) {
        if (recordingState is RecordingState.Saved) {
            delay(DesignTokens.StatusLine.ClearDelayMs.toLong())
            onStatusCleared()
        }
    }

    val density = LocalDensity.current
    val currentCanOpenSettings by rememberUpdatedState(
        canOpenSettings(
            recordingState = recordingState,
            showSettingsPanel = showSettingsPanel,
        ),
    )

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .pointerInput(onSwipeUp, onOpenSettings) {
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
                    if (currentCanOpenSettings) {
                        if (totalY < -thresholdPx) onSwipeUp()
                        if (totalY > thresholdPx) onOpenSettings()
                    }
                }
            },
    ) {
        AnimatedVisibility(
            visible = currentCanOpenSettings,
            enter = fadeIn(animationSpec = tween(DesignTokens.Animation.FadeDuration)),
            exit = fadeOut(animationSpec = tween(DesignTokens.Animation.FadeDuration)),
            modifier = Modifier.align(Alignment.TopEnd),
        ) {
            SettingsButton(
                onOpenSettings = onOpenSettings,
                modifier = Modifier
                    .statusBarsPadding()
                    .padding(
                        top = DesignTokens.Spacing.md,
                        end = DesignTokens.Spacing.sm,
                    ),
            )
        }

        ActionButtonStack(
            actionButton = {
                ButtonArea(
                    recordingState = recordingState,
                    recordingCountdown = recordingCountdown,
                    showBlockedMessage = showBlockedMessage,
                    shakeErrorKey = shakeErrorKey,
                    onTap = onButtonTap,
                )
            },
            statusContent = {
                StatusLine(
                    recordingState = recordingState,
                    showBlockedMessage = showBlockedMessage,
                    hasEverRecorded = hasEverRecorded,
                    onTap = statusLineTapAction(
                        recordingState = recordingState,
                        showBlockedMessage = showBlockedMessage,
                        hasEverRecorded = hasEverRecorded,
                        onStatusLineTap = onStatusLineTap,
                        onTapToRead = onTapToRead,
                        onButtonTap = onButtonTap,
                    ),
                )
            },
            statsContent = {
                StatsLine(
                    stats = stats,
                    onTap = if (recordingState is RecordingState.Listening ||
                        recordingState is RecordingState.Processing ||
                        recordingState is RecordingState.Uploading
                    ) {
                        null
                    } else {
                        onStatsLineTap
                    },
                )
            },
        )

        if (showSettingsPanel) {
            SettingsPanel(
                languageSummary = languageSummary,
                onLanguagesTap = onLanguagesTap,
                privacyMode = privacyMode,
                onModeToggle = onPrivacyModeToggle,
                onDismiss = onSettingsPanelDismiss,
            )
        }
    }
}

@Composable
private fun SettingsButton(
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val description = stringResource(R.string.main_open_settings_description)

    IconButton(
        onClick = onOpenSettings,
        modifier = modifier.semantics { contentDescription = description },
    ) {
        Icon(
            imageVector = Icons.Filled.Settings,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
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
    val statusText = statusTextFor(
        recordingState = recordingState,
        showBlockedMessage = showBlockedMessage,
        hasEverRecorded = hasEverRecorded,
    )
    val animationsEnabled = Settings.Global.getFloat(
        LocalContext.current.contentResolver,
        Settings.Global.ANIMATOR_DURATION_SCALE,
        1f,
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
            val entryWord = if (stats.entryCount == 1) "entry" else "entries"
            val dayWord = if (stats.activeDays == 1) "day" else "days"
            Text(
                text = "${stats.entryCount} $entryWord · ${stats.activeDays} $dayWord" +
                    (if (onTap != null) " \u203a" else ""),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onBackground,
            )
        }
    }
}

internal fun statusLineTapAction(
    recordingState: RecordingState,
    showBlockedMessage: Boolean,
    hasEverRecorded: Boolean,
    onStatusLineTap: () -> Unit,
    onTapToRead: (entryId: Long) -> Unit,
    onButtonTap: () -> Unit,
): (() -> Unit)? {
    return when {
        showBlockedMessage -> onStatusLineTap
        recordingState is RecordingState.Saved -> {
            val entryId = recordingState.entryId
            { onTapToRead(entryId) }
        }
        recordingState is RecordingState.Idle && !hasEverRecorded -> onButtonTap
        else -> null
    }
}

internal fun canOpenSettings(
    recordingState: RecordingState,
    showSettingsPanel: Boolean,
): Boolean = !recordingState.isActive && !showSettingsPanel

internal fun statusTextFor(
    recordingState: RecordingState,
    showBlockedMessage: Boolean,
    hasEverRecorded: Boolean,
): String {
    if (showBlockedMessage) return "mic blocked · tap to open settings"
    return when (recordingState) {
        is RecordingState.Idle -> if (!hasEverRecorded) "tap button to write" else ""
        is RecordingState.Listening -> "listening…"
        is RecordingState.Uploading -> "uploading…"
        is RecordingState.Processing -> "cleaning up…"
        is RecordingState.Saved -> "tap to read"
        is RecordingState.Deleted -> if (recordingState.count == 1) "entry deleted" else "${recordingState.count} entries deleted"
        is RecordingState.Error -> when (recordingState.error) {
            RecognizerError.InsufficientPermissions -> "mic blocked · tap to open settings"
            RecognizerError.NoMatch -> "nothing caught · too quiet?"
            RecognizerError.TooShort -> "too short · keep talking"
            RecognizerError.ConnectionRequired -> "best mode needs connection"
            is RecognizerError.NotAvailable -> {
                val name = com.wrait.app.domain.model.displayNameForLanguage(recordingState.error.language)
                if (name.isNotBlank()) "no offline model for $name" else "offline model not installed"
            }
            RecognizerError.NoInternet,
            RecognizerError.Network,
            RecognizerError.Timeout -> "no connection · saved as draft"
            RecognizerError.BackendUnavailable -> "service unavailable · saved as draft"
            RecognizerError.ProxyAuthFailed -> "server config error · saved as draft"
            else -> "saved as draft · will retry"
        }
    }
}
