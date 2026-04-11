package com.wrait.app.ui.entries

import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.dp
import com.wrait.app.R
import com.wrait.app.domain.model.Entry
import com.wrait.app.ui.theme.DesignTokens
import com.wrait.app.ui.theme.DesignTokens.Animation
import com.wrait.app.ui.theme.DesignTokens.Gesture
import com.wrait.app.ui.theme.DesignTokens.Spacing
import com.wrait.app.ui.theme.WrAItTheme
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.util.Locale

@Composable
fun EntryListScreen(
    uiState: EntryListUiState,
    onEntryClick: (Long) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val sorted = remember(uiState.entries) {
        uiState.entries.sortedByDescending { it.createdAt }
    }
    val backDescription = stringResource(R.string.entry_list_back_description)
    val emptyStateText  = stringResource(R.string.entry_list_empty_state)

    // Top: room for the overlaid back-button IconButton (Spacing.md offset + ~48 dp touch target)
    val listTopPadding    = Spacing.md + Spacing.xxl
    // Bottom: standard breathing room below the last card
    val listBottomPadding = Spacing.lg + Spacing.md

    // Swipe-down-to-back via the LazyColumn's overscroll. onPreFling resets the accumulator so a
    // fling that doesn't reach the threshold doesn't carry state into the next drag.
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
    ) {
        if (sorted.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text  = emptyStateText,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.tertiary
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = Spacing.md),
                contentPadding = PaddingValues(
                    top    = listTopPadding,
                    bottom = listBottomPadding
                ),
                verticalArrangement = Arrangement.spacedBy(Spacing.sm)
            ) {
                items(sorted, key = { it.id }) { entry ->
                    EntryCard(
                        entry        = entry,
                        onEntryClick = onEntryClick,
                        modifier     = Modifier.animateItem(
                            fadeOutSpec = tween(Animation.DeleteFadeDuration)
                        )
                    )
                }
            }
        }

        IconButton(
            onClick = onBack,
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(top = Spacing.md, start = Spacing.sm)
                .semantics { contentDescription = backDescription }
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.surface
            )
        }
    }
}

@Composable
private fun EntryCard(
    entry: Entry,
    onEntryClick: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    val dateString  = formatEntryDate(entry.createdAt)
    val audioDraftPreview = stringResource(R.string.entry_list_audio_draft_preview)
    val audioDraftDisabledDescription = stringResource(R.string.entry_list_audio_draft_state_description)
    val displayText = entryCardDisplayText(entry, audioDraftPreview)
    val isAudioDraft = entry.isAudioOnlyDraftCard()
    val textColor = if (isAudioDraft) {
        MaterialTheme.colorScheme.tertiary
    } else if (entry.isDraft) {
        MaterialTheme.colorScheme.secondary
    } else {
        MaterialTheme.colorScheme.onSurface
    }

    Box(modifier = modifier) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(enabled = !isAudioDraft) { onEntryClick(entry.id) },
            shape          = RoundedCornerShape(DesignTokens.Radius.card),
            color          = MaterialTheme.colorScheme.surface,
            tonalElevation = if (entry.isDraft) Spacing.xs else Spacing.sm
        ) {
            Column(
                modifier = Modifier
                    .semantics {
                        if (isAudioDraft) {
                            disabled()
                            stateDescription = audioDraftDisabledDescription
                        }
                    }
                    .padding(
                        horizontal = Spacing.md,
                        vertical   = 14.dp
                    )
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text     = dateString,
                        style    = MaterialTheme.typography.bodySmall,
                        color    = MaterialTheme.colorScheme.tertiary,
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
                                    horizontal = Spacing.sm,
                                    vertical   = Spacing.xs
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
                Spacer(modifier = Modifier.height(Spacing.xs))
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
}

private fun formatEntryDate(createdAt: Long): String {
    val zdt       = Instant.ofEpochMilli(createdAt).atZone(ZoneId.systemDefault())
    val dayOfWeek = zdt.dayOfWeek.getDisplayName(TextStyle.FULL, Locale.getDefault())
    val day       = zdt.dayOfMonth
    val month     = zdt.month.getDisplayName(TextStyle.FULL, Locale.getDefault())
    val base      = "$dayOfWeek, $day $month"
    val time      = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(Locale.getDefault()).format(zdt)
    return "$base · $time"
}

// Private: only used by EntryCard above. Exposed as internal previously when selection mode
// needed it from the screen level; now self-contained within this file.
private fun Entry.isAudioOnlyDraftCard(): Boolean =
    audioPath != null && cleanedText.isNullOrBlank() && rawTranscript.isBlank()

private fun entryCardDisplayText(
    entry: Entry,
    audioDraftPreview: String,
): String {
    val preview = when {
        !entry.cleanedText.isNullOrBlank() -> entry.cleanedText
        entry.rawTranscript.isNotBlank() -> entry.rawTranscript
        entry.isAudioOnlyDraftCard() -> audioDraftPreview
        else -> ""
    }
    return preview.lines().firstOrNull { it.isNotBlank() }.orEmpty()
}

// --- Previews ---

@Preview(showBackground = true)
@Composable
private fun EntryListScreenPreview() {
    WrAItTheme {
        EntryListScreen(
            uiState = EntryListUiState(
                entries = listOf(
                    Entry(
                        id            = 1L,
                        rawTranscript = "Today I walked in the park and felt the sun on my face.",
                        cleanedText   = null,
                        isDraft       = true,
                        language      = "en",
                        createdAt     = System.currentTimeMillis(),
                        wordCount     = 0
                    ),
                    Entry(
                        id            = 2L,
                        rawTranscript = "Had a long call with the team.",
                        cleanedText   = "Had a long call with the team about the product roadmap.",
                        isDraft       = false,
                        language      = "en",
                        createdAt     = System.currentTimeMillis() - 86_400_000L,
                        wordCount     = 11
                    )
                )
            ),
            onEntryClick = {},
            onBack       = {}
        )
    }
}

// Dedicated preview to verify audio-draft card styling:
// tertiary text colour, "draft" label, and disabled (non-tappable) state.
@Preview(showBackground = true)
@Composable
private fun EntryListAudioDraftPreview() {
    WrAItTheme {
        EntryListScreen(
            uiState = EntryListUiState(
                entries = listOf(
                    Entry(
                        id            = 1L,
                        rawTranscript = "",
                        cleanedText   = null,
                        isDraft       = true,
                        language      = "en",
                        createdAt     = System.currentTimeMillis(),
                        wordCount     = 0,
                        audioPath     = "/tmp/test.m4a"
                    )
                )
            ),
            onEntryClick = {},
            onBack       = {}
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun EntryListScreenEmptyPreview() {
    WrAItTheme {
        EntryListScreen(
            uiState      = EntryListUiState(),
            onEntryClick = {},
            onBack       = {}
        )
    }
}
