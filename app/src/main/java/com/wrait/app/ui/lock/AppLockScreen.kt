package com.wrait.app.ui.lock

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import com.wrait.app.R
import com.wrait.app.lock.AppLockMessage
import com.wrait.app.lock.AppLockStatus
import com.wrait.app.lock.AppLockUiState
import com.wrait.app.ui.main.ActionButtonStack
import com.wrait.app.ui.main.rememberAdaptiveActionButtonSize
import com.wrait.app.ui.theme.DesignTokens

@Composable
fun AppLockScreen(
    uiState: AppLockUiState,
    onUnlock: () -> Unit,
    onOpenSecuritySettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val showExplainer = uiState.status == AppLockStatus.SetupRequired ||
        uiState.message == AppLockMessage.TemporarilyUnavailable
    val showUnlockButton = uiState.status == AppLockStatus.Locked &&
        !uiState.isPromptPending &&
        uiState.message == null
    val title = when (uiState.status) {
        AppLockStatus.SetupRequired -> stringResource(R.string.app_lock_setup_required_title)
        else -> ""
    }
    val message = when {
        uiState.status == AppLockStatus.SetupRequired ->
            stringResource(R.string.app_lock_setup_required_message)
        uiState.message == AppLockMessage.TemporarilyUnavailable ->
            stringResource(R.string.app_lock_temporarily_unavailable)
        else -> ""
    }

    Surface(
        color = Color.Transparent,
        modifier = modifier
            .fillMaxSize()
            .testTag("app_lock_overlay"),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.scrim.copy(alpha = DesignTokens.AppLock.ScrimAlpha)),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clickable(
                        indication = null,
                        interactionSource = remember { MutableInteractionSource() },
                        onClick = {},
                    ),
            )
            if (showExplainer) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .statusBarsPadding()
                        .padding(DesignTokens.Spacing.lg),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(DesignTokens.Spacing.md),
                    ) {
                        Text(
                            text = title,
                            style = MaterialTheme.typography.headlineSmall,
                            color = MaterialTheme.colorScheme.onBackground,
                            textAlign = TextAlign.Center,
                        )
                        Text(
                            text = message,
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                        )

                        if (uiState.status == AppLockStatus.SetupRequired) {
                            Button(
                                onClick = onOpenSecuritySettings,
                                modifier = Modifier.testTag("app_lock_open_settings"),
                            ) {
                                Text(stringResource(R.string.app_lock_open_security_settings))
                            }
                        } else if (uiState.message == AppLockMessage.TemporarilyUnavailable) {
                            AppLockPrimaryActionButton(
                                onClick = onUnlock,
                                label = stringResource(R.string.app_lock_unlock),
                                modifier = Modifier.testTag("app_lock_unlock_retry"),
                            )
                        }
                    }
                }
            } else if (showUnlockButton) {
                ActionButtonStack(
                    actionButton = {
                        AppLockPrimaryActionButton(
                            onClick = onUnlock,
                            label = stringResource(R.string.app_lock_unlock),
                            modifier = Modifier.testTag("app_lock_unlock_main"),
                        )
                    },
                )
            }
        }
    }
}

@Composable
private fun AppLockPrimaryActionButton(
    onClick: () -> Unit,
    label: String,
    modifier: Modifier = Modifier,
) {
    val buttonSize = rememberAdaptiveActionButtonSize()

    Box(
        modifier = modifier
            .size(buttonSize)
            .semantics(mergeDescendants = true) {
                contentDescription = label
            }
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.primary)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onPrimary,
        )
    }
}
