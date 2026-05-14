package com.wrait.app.ui.lock

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.background
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.graphics.Color
import com.wrait.app.R
import com.wrait.app.lock.AppLockMessage
import com.wrait.app.lock.AppLockStatus
import com.wrait.app.lock.AppLockUiState
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
                .background(MaterialTheme.colorScheme.scrim.copy(alpha = 0.18f))
                .statusBarsPadding()
                .padding(DesignTokens.Spacing.lg),
            contentAlignment = Alignment.Center,
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
                        Button(
                            onClick = onUnlock,
                            modifier = Modifier.testTag("app_lock_unlock"),
                        ) {
                            Text(stringResource(R.string.app_lock_unlock))
                        }
                    }
                }
            }
        }
    }
}
