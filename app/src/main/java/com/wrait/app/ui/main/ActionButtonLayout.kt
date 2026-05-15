package com.wrait.app.ui.main

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.wrait.app.ui.theme.DesignTokens

@Composable
internal fun rememberAdaptiveActionButtonSize(): Dp {
    val density = LocalDensity.current
    val containerWidthDp = with(density) { LocalWindowInfo.current.containerSize.width.toDp() }
    return remember(containerWidthDp) {
        (containerWidthDp.value * DesignTokens.Button.ScreenWidthRatio)
            .coerceIn(DesignTokens.Button.SizeMin.value, DesignTokens.Button.SizeMax.value)
            .dp
    }
}

/**
 * Shared vertical alignment track for the main action button and the lock-screen recovery action.
 *
 * When status or stats content is omitted, the stack reserves the same vertical space so the
 * action button stays aligned with the main screen layout.
 */
@Composable
internal fun ActionButtonStack(
    actionButton: @Composable () -> Unit,
    statusContent: (@Composable () -> Unit)? = null,
    statsContent: (@Composable () -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Top,
    ) {
        Spacer(Modifier.weight(1f))
        actionButton()
        Spacer(Modifier.height(DesignTokens.StatusLine.GapAboveDp))
        if (statusContent != null) {
            statusContent()
        } else {
            Spacer(Modifier.height(DesignTokens.StatusLine.ReservedHeightDp))
        }
        Spacer(Modifier.height(DesignTokens.StatsLine.GapAboveDp))
        if (statsContent != null) {
            statsContent()
        } else {
            Spacer(Modifier.height(DesignTokens.StatsLine.ReservedHeightDp))
        }
        Spacer(Modifier.weight(1f))
    }
}
