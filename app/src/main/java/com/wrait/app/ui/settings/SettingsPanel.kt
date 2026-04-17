package com.wrait.app.ui.settings

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.model.TranscriptionBackend
import kotlinx.coroutines.delay

private const val SLIDE_DURATION_MS = 300
private val HANDLE_WIDTH = 32.dp
private val HANDLE_HEIGHT = 4.dp
private val HANDLE_RADIUS = 2.dp
private const val DISMISS_DRAG_THRESHOLD = 40f // px — upward drag to dismiss

@Composable
fun SettingsPanel(
    privacyMode: PrivacyMode,
    onModeToggle: (Boolean) -> Unit,
    transcriptionBackend: TranscriptionBackend,
    onTranscriptionBackendToggle: (Boolean) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var visible by remember { mutableStateOf(true) }

    LaunchedEffect(visible) {
        if (!visible) {
            delay(SLIDE_DURATION_MS.toLong())
            onDismiss()
        }
    }

    // Full-screen Box: scrim (tap outside) + panel surface (anchored to top)
    Box(modifier = modifier.fillMaxSize()) {
        // Scrim — tap anywhere below the panel to dismiss
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clickable(
                    indication = null,
                    interactionSource = remember { MutableInteractionSource() },
                    onClick = { visible = false },
                )
        )

        AnimatedVisibility(
            visible = visible,
            enter = slideInVertically(
                animationSpec = tween(SLIDE_DURATION_MS),
                initialOffsetY = { -it },
            ),
            exit = slideOutVertically(
                animationSpec = tween(SLIDE_DURATION_MS),
                targetOffsetY = { -it },
            ),
            modifier = Modifier.align(Alignment.TopCenter),
        ) {
            Surface(
                color = MaterialTheme.colorScheme.surface,
                modifier = Modifier
                    .fillMaxWidth()
                    // Swipe-up on the panel itself dismisses it
                    .pointerInput(Unit) {
                        var totalY = 0f
                        detectVerticalDragGestures(
                            onDragCancel = { totalY = 0f },
                            onDragEnd = { totalY = 0f },
                        ) { _, dragAmount ->
                            totalY += dragAmount
                            if (totalY < -DISMISS_DRAG_THRESHOLD) visible = false
                        }
                    }
                    // Prevent taps on the surface propagating to the scrim
                    .clickable(
                        indication = null,
                        interactionSource = remember { MutableInteractionSource() },
                        onClick = {},
                    ),
            ) {
                Column(modifier = Modifier
                    .statusBarsPadding()
                    .padding(horizontal = 24.dp, vertical = 20.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .semantics(mergeDescendants = true) {},
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f).padding(end = 16.dp)) {
                            Text(
                                text = "Offline mode",
                                style = MaterialTheme.typography.bodyLarge,
                            )
                            Text(
                                text = "Record without internet. Lower transcription quality.",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Switch(
                            checked = privacyMode == PrivacyMode.MODE_OFFLINE,
                            onCheckedChange = onModeToggle,
                        )
                    }

                    Spacer(Modifier.height(16.dp))

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .semantics(mergeDescendants = true) {},
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f).padding(end = 16.dp)) {
                            Text(
                                text = "Use backend",
                                style = MaterialTheme.typography.bodyLarge,
                            )
                            Text(
                                text = "Route audio through server. Keeps API key off device.",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Switch(
                            checked = transcriptionBackend == TranscriptionBackend.PROXY,
                            onCheckedChange = onTranscriptionBackendToggle,
                        )
                    }

                    Spacer(Modifier.height(16.dp))

                    // Drag handle
                    Box(
                        modifier = Modifier
                            .align(Alignment.CenterHorizontally)
                            .size(width = HANDLE_WIDTH, height = HANDLE_HEIGHT)
                            .background(
                                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
                                shape = RoundedCornerShape(HANDLE_RADIUS),
                            )
                    )
                }
            }
        }
    }
}

