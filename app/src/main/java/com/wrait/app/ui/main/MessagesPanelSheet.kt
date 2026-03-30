package com.wrait.app.ui.main

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.wrait.app.domain.model.AppMessage
import com.wrait.app.domain.model.MessageType
import com.wrait.app.ui.theme.LocalWraitSemanticColors
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun MessagesPanelSheet(
    messages: List<AppMessage>,
    onDismissMessage: (UUID) -> Unit,
    onRetryCleanup: (messageId: UUID, entryId: Long) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        if (messages.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 32.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "nothing to show",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.tertiary,
                )
            }
        } else {
            val needsAttentionMessages = messages.filter {
                it.type == MessageType.CleanupFailed || it.type == MessageType.NetworkError
            }
            val recentMessages = messages.filter {
                it.type == MessageType.DraftCleaned
            }

            LazyColumn(
                modifier = Modifier.fillMaxWidth(),
                contentPadding = PaddingValues(bottom = 24.dp),
            ) {
                if (needsAttentionMessages.isNotEmpty()) {
                    item(key = "header_needs_attention") {
                        SectionHeader(title = "Needs attention")
                    }
                    items(needsAttentionMessages, key = { it.id }) { message ->
                        MessageRow(
                            message = message,
                            onDismissMessage = onDismissMessage,
                            onRetryCleanup = onRetryCleanup,
                        )
                    }
                }

                if (recentMessages.isNotEmpty()) {
                    item(key = "header_recent") {
                        SectionHeader(title = "Recent")
                    }
                    items(recentMessages, key = { it.id }) { message ->
                        MessageRow(
                            message = message,
                            onDismissMessage = onDismissMessage,
                            onRetryCleanup = onRetryCleanup,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(
    title: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = title,
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.tertiary,
        modifier = modifier.padding(horizontal = 24.dp, vertical = 8.dp),
    )
}

@Composable
private fun MessageRow(
    message: AppMessage,
    onDismissMessage: (UUID) -> Unit,
    onRetryCleanup: (messageId: UUID, entryId: Long) -> Unit,
    modifier: Modifier = Modifier,
) {
    val semanticColors = LocalWraitSemanticColors.current
    val dotColor = when (message.type) {
        MessageType.DraftCleaned -> semanticColors.success
        MessageType.CleanupFailed,
        MessageType.NetworkError -> semanticColors.warning
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        // Coloured dot
        Surface(
            modifier = Modifier
                .padding(top = 4.dp)
                .size(8.dp),
            shape = CircleShape,
            color = dotColor,
            content = {},
        )

        Spacer(Modifier.width(12.dp))

        // Content column
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = message.title,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = message.description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (message.actionLabel != null && message.type == MessageType.CleanupFailed) {
                TextButton(
                    onClick = {
                        val entryId = message.entryId ?: return@TextButton
                        onRetryCleanup(message.id, entryId)
                    },
                    contentPadding = PaddingValues(horizontal = 0.dp, vertical = 4.dp),
                ) {
                    Text(
                        text = message.actionLabel,
                        style = MaterialTheme.typography.labelSmall,
                    )
                }
            }
        }

        // Dismiss button
        IconButton(
            onClick = { onDismissMessage(message.id) },
            modifier = Modifier.size(36.dp),
        ) {
            Icon(
                imageVector = Icons.Filled.Close,
                contentDescription = "Dismiss",
                tint = MaterialTheme.colorScheme.tertiary,
                modifier = Modifier.size(16.dp),
            )
        }
    }
}
