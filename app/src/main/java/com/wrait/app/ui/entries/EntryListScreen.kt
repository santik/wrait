package com.wrait.app.ui.entries

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.dp
import com.wrait.app.domain.model.Entry
import com.wrait.app.ui.theme.DesignTokens
import com.wrait.app.ui.theme.DesignTokens.Gesture
import com.wrait.app.ui.theme.WrAItTheme
import java.time.Instant
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale

@Composable
fun EntryListScreen(
    entries: List<Entry>,
    onEntryClick: (Long) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val sorted = remember(entries) { entries.sortedByDescending { it.createdAt } }

    // NestedScrollConnection intercepts unconsumed downward drag when the
    // LazyColumn is already at the top. detectVerticalDragGestures on the
    // same Box acts as a fallback for the empty-state (no LazyColumn present).
    val nestedScrollConnection = remember {
        object : NestedScrollConnection {
            private var accumulated = 0f
            private var hasFired = false

            override fun onPostScroll(
                consumed: Offset,
                available: Offset,
                source: NestedScrollSource
            ): Offset {
                if (source == NestedScrollSource.UserInput && !hasFired) {
                    if (available.y > 0f) {
                        accumulated += available.y
                        if (accumulated > Gesture.SwipeBackThresholdPx) {
                            hasFired = true
                            onBack()
                        }
                    } else {
                        accumulated = 0f
                    }
                }
                return Offset.Zero
            }

            override suspend fun onPreFling(available: Velocity): Velocity {
                accumulated = 0f
                hasFired = false
                return super.onPreFling(available)
            }
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .statusBarsPadding()
            .nestedScroll(nestedScrollConnection)
            // Fallback: fires only when there is no LazyColumn to steal events
            .pointerInput(Unit) {
                detectVerticalDragGestures { _, dragAmount ->
                    if (dragAmount > Gesture.SwipeNavThresholdPx) onBack()
                }
            }
    ) {
        if (sorted.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "your entries will appear here",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.tertiary
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = DesignTokens.Spacing.md),
                verticalArrangement = Arrangement.spacedBy(DesignTokens.Spacing.sm)
            ) {
                item { Spacer(modifier = Modifier.height(DesignTokens.Spacing.lg)) }
                items(sorted, key = { it.id }) { entry ->
                    EntryCard(
                        entry = entry,
                        onClick = { onEntryClick(entry.id) }
                    )
                }
                item { Spacer(modifier = Modifier.height(DesignTokens.Spacing.lg)) }
            }
        }
    }
}

@Composable
private fun EntryCard(
    entry: Entry,
    onClick: () -> Unit
) {
    val dateString = formatEntryDate(entry.createdAt)
    val displayText = (entry.cleanedText ?: entry.rawTranscript)
        .lines()
        .firstOrNull { it.isNotBlank() } ?: entry.rawTranscript
    val textColor = if (entry.isDraft) {
        MaterialTheme.colorScheme.secondary
    } else {
        MaterialTheme.colorScheme.onSurface
    }

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(DesignTokens.Radius.card),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = if (entry.isDraft) DesignTokens.Spacing.xs else DesignTokens.Spacing.sm
    ) {
        Column(
            modifier = Modifier.padding(
                horizontal = DesignTokens.Spacing.md,
                vertical   = 14.dp
            )
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = dateString,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.tertiary,
                    modifier = Modifier.weight(1f)
                )
                if (entry.isDraft) {
                    Box(
                        modifier = Modifier
                            .background(
                                color = WrAItTheme.semanticColors.warningContainer,
                                shape = RoundedCornerShape(DesignTokens.Radius.small)
                            )
                            .padding(
                                horizontal = DesignTokens.Spacing.sm,
                                vertical   = DesignTokens.Spacing.xs
                            )
                    ) {
                        Text(
                            text  = "draft",
                            style = MaterialTheme.typography.labelSmall,
                            color = WrAItTheme.semanticColors.warning
                        )
                    }
                } else {
                    Text(
                        text  = "${entry.wordCount} words",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.tertiary
                    )
                }
            }
            Spacer(modifier = Modifier.height(DesignTokens.Spacing.xs))
            Text(
                text     = displayText,
                style    = MaterialTheme.typography.labelLarge,
                color    = textColor,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

private fun formatEntryDate(createdAt: Long): String {
    val date = Instant.ofEpochMilli(createdAt)
        .atZone(ZoneId.systemDefault())
        .toLocalDate()
    val dayOfWeek = date.dayOfWeek.getDisplayName(TextStyle.FULL, Locale.getDefault())
    val day = date.dayOfMonth
    val month = date.month.getDisplayName(TextStyle.FULL, Locale.getDefault())
    return "$dayOfWeek, $day $month"
}

@Preview(showBackground = true)
@Composable
private fun EntryListScreenPreview() {
    WrAItTheme {
        EntryListScreen(
            entries = listOf(
                Entry(
                    id = 1L,
                    rawTranscript = "Today I walked in the park and felt the sun on my face.",
                    cleanedText = null,
                    isDraft = true,
                    language = "en",
                    createdAt = System.currentTimeMillis(),
                    wordCount = 0
                ),
                Entry(
                    id = 2L,
                    rawTranscript = "Had a long call with the team.",
                    cleanedText = "Had a long call with the team about the product roadmap.",
                    isDraft = false,
                    language = "en",
                    createdAt = System.currentTimeMillis() - 86_400_000L,
                    wordCount = 11
                )
            ),
            onEntryClick = {},
            onBack = {}
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun EntryListScreenEmptyPreview() {
    WrAItTheme {
        EntryListScreen(
            entries = emptyList(),
            onEntryClick = {},
            onBack = {}
        )
    }
}
