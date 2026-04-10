package com.wrait.app.ui.entries

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.wrait.app.domain.model.Entry
import com.wrait.app.ui.theme.DesignTokens
import com.wrait.app.ui.theme.DesignTokens.Animation
import com.wrait.app.ui.theme.DesignTokens.Gesture
import com.wrait.app.ui.theme.DesignTokens.Spacing
import com.wrait.app.ui.theme.SemanticWarning
import com.wrait.app.ui.theme.WrAItTheme
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.util.Locale
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.semantics
import com.wrait.app.R

@Composable
fun EntryListScreen(
    uiState: EntryListUiState,
    onEntryClick: (Long) -> Unit,
    onBack: () -> Unit,
    onLongPress: (Long) -> Unit,
    onToggleSelection: (Long) -> Unit,
    onSelectAll: () -> Unit,
    onDeselectAll: () -> Unit,
    onExitSelection: () -> Unit,
    onDeleteTapped: () -> Unit,
    onDeleteCancelled: () -> Unit,
    onDeleteConfirmed: () -> Unit,
    modifier: Modifier = Modifier
) {
    val sorted = remember(uiState.entries) {
        uiState.entries.sortedByDescending { it.createdAt }
    }
    val backDescription   = stringResource(R.string.entry_list_back_description)
    val listTopPadding    = Spacing.md + Spacing.xxl + Spacing.sm   // back button + selection bar
    val listBottomPadding = Spacing.xxl + Spacing.lg + Spacing.md   // delete button

    // Intercept system back: exit selection mode instead of navigating back
    BackHandler(enabled = uiState.selectionMode) { onExitSelection() }

    // Reset selection state when app is sent to background
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_STOP) onExitSelection()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // NestedScrollConnection: swipe-down exits selection mode if active, otherwise navigates back.
    // Keyed on selectionMode so the lambda captures the current mode without stale closures.
    val nestedScrollConnection = remember(uiState.selectionMode) {
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
                            if (uiState.selectionMode) onExitSelection() else onBack()
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
            .pointerInput(uiState.selectionMode) {
                var hasFired = false
                detectVerticalDragGestures(
                    onDragStart  = { hasFired = false },
                    onDragEnd    = { hasFired = false },
                    onDragCancel = { hasFired = false }
                ) { _, dragAmount ->
                    if (!hasFired && dragAmount > Gesture.SwipeNavThresholdDp.toPx()) {
                        hasFired = true
                        if (uiState.selectionMode) onExitSelection() else onBack()
                    }
                }
            }
    ) {
        // Entry list or empty state — fills the full Box; never resizes during selection transitions
        if (sorted.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text  = "your entries will appear here",
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
                        entry             = entry,
                        selectionMode     = uiState.selectionMode,
                        selected          = entry.id in uiState.selectedIds,
                        onEntryClick      = onEntryClick,
                        onToggleSelection = onToggleSelection,
                        onLongPress       = onLongPress,
                        modifier          = Modifier.animateItem(
                            fadeOutSpec = tween(Animation.DeleteFadeDuration)
                        )
                    )
                }
            }
        }

        // Action bar — overlaid at top so it never pushes the list down
        SelectionActionBar(
            uiState         = uiState,
            allCount        = sorted.size,
            onExitSelection = onExitSelection,
            onSelectAll     = onSelectAll,
            onDeselectAll   = onDeselectAll,
            modifier        = Modifier.align(Alignment.TopCenter)
        )

        if (!uiState.selectionMode) {
            IconButton(
                onClick = onBack,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(top = Spacing.md, start = Spacing.sm)
                    .semantics { contentDescription = backDescription }
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = null,   // described by parent semantics above
                    tint = MaterialTheme.colorScheme.surface
                )
            }
        }

        // Delete button — pinned at bottom, fades in with selection mode
        DeleteButton(
            uiState      = uiState,
            onDeleteTapped = onDeleteTapped,
            modifier     = Modifier.align(Alignment.BottomCenter)
        )
    }

    // Confirmation dialog
    if (uiState.showDeleteDialog) {
        val count = uiState.selectedIds.size
        val noun  = if (count == 1) "entry" else "entries"
        AlertDialog(
            onDismissRequest = onDeleteCancelled,
            title = { Text("Delete $count $noun?") },
            text  = { Text("This cannot be undone.") },
            confirmButton = {
                TextButton(onClick = onDeleteConfirmed) {
                    Text("Delete", color = WrAItTheme.semanticColors.error)
                }
            },
            dismissButton = {
                TextButton(onClick = onDeleteCancelled) { Text("Cancel") }
            }
        )
    }
}

@Composable
private fun SelectionActionBar(
    uiState: EntryListUiState,
    allCount: Int,
    onExitSelection: () -> Unit,
    onSelectAll: () -> Unit,
    onDeselectAll: () -> Unit,
    modifier: Modifier = Modifier
) {
    AnimatedVisibility(
        visible  = uiState.selectionMode,
        enter    = fadeIn(tween(Animation.FadeDuration)) +
                   slideInVertically(tween(Animation.FadeDuration)) { -it },
        exit     = fadeOut(tween(Animation.FadeDuration)) +
                   slideOutVertically(tween(Animation.FadeDuration)) { -it },
        modifier = modifier
    ) {
        val allSelected = uiState.selectedIds.size == allCount && allCount > 0
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.sm),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onExitSelection) {
                Icon(
                    imageVector        = Icons.Default.Close,
                    contentDescription = "Cancel selection"
                )
            }
            Text(
                text     = "${uiState.selectedIds.size} selected",
                style    = MaterialTheme.typography.titleSmall,
                modifier = Modifier.weight(1f)
            )
            TextButton(
                onClick = if (allSelected) onDeselectAll else onSelectAll
            ) {
                Text(if (allSelected) "Deselect all" else "Select all")
            }
        }
    }
}

@Composable
private fun DeleteButton(
    uiState: EntryListUiState,
    onDeleteTapped: () -> Unit,
    modifier: Modifier = Modifier
) {
    AnimatedVisibility(
        visible  = uiState.selectionMode,
        enter    = fadeIn(tween(Animation.FadeDuration)),
        exit     = fadeOut(tween(Animation.FadeDuration)),
        modifier = modifier
    ) {
        val count    = uiState.selectedIds.size
        val hasItems = count > 0
        val label    = if (count == 1) "Delete 1 entry" else "Delete $count entries"
        Button(
            onClick  = onDeleteTapped,
            enabled  = hasItems,
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = Spacing.md, vertical = Spacing.md)
                .alpha(if (hasItems) 1f else 0.4f),
            colors   = ButtonDefaults.buttonColors(
                containerColor         = WrAItTheme.semanticColors.error,
                disabledContainerColor = WrAItTheme.semanticColors.error
            )
        ) {
            Text(label, color = WrAItTheme.semanticColors.onSemantic)
        }
    }
}

@Composable
private fun EntryCard(
    entry: Entry,
    selectionMode: Boolean,
    selected: Boolean,
    onEntryClick: (Long) -> Unit,
    onToggleSelection: (Long) -> Unit,
    onLongPress: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    val haptic      = LocalHapticFeedback.current
    val dateString  = formatEntryDate(entry.createdAt)
    val audioDraftPreview = stringResource(R.string.entry_list_audio_draft_preview)
    val audioDraftDisabledDescription = stringResource(R.string.entry_list_audio_draft_state_description)
    val displayText = entryCardDisplayText(entry, audioDraftPreview)
    val isAudioDraft = entry.isAudioOnlyDraftCard()
    val isAudioDraftDisabled = isAudioDraft && !selectionMode
    val textColor = if (isAudioDraftDisabled) {
        MaterialTheme.colorScheme.tertiary
    } else if (entry.isDraft) {
        MaterialTheme.colorScheme.secondary
    } else {
        MaterialTheme.colorScheme.onSurface
    }
    val interactionSource = remember { MutableInteractionSource() }

    val selectedTint  = WrAItTheme.semanticColors.warningContainer.copy(alpha = 0.5f)
    val defaultColor  = MaterialTheme.colorScheme.surface
    val cardColor by animateColorAsState(
        targetValue = if (selected) selectedTint else defaultColor,
        animationSpec = tween(Animation.FadeDuration),
        label = "cardColor"
    )

    Box(modifier = modifier) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .combinedClickable(
                    interactionSource = interactionSource,
                    indication = if (isAudioDraftDisabled) null else LocalIndication.current,
                    onClick = {
                        when {
                            selectionMode -> onToggleSelection(entry.id)
                            !isAudioDraft -> onEntryClick(entry.id)
                            // isAudioDraft && !selectionMode: intentional no-op
                            else -> Unit
                        }
                    },
                    onLongClick = {
                        if (!selectionMode) {
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                            onLongPress(entry.id)
                        }
                    }
                ),
            // Accessibility: expose audio-only drafts as temporarily disabled outside selection mode.
            // Long-press still works for entering selection mode.
            // Visual cue: disabled audio draft text is rendered with tertiary color.
            // The card remains visible and selectable once selection mode is active.
            // This keeps behavior explicit for screen-reader users.
            shape         = RoundedCornerShape(DesignTokens.Radius.card),
            color         = cardColor,
            tonalElevation = if (entry.isDraft) Spacing.xs else Spacing.sm
        ) {
            Column(
                modifier = Modifier
                    .semantics {
                        if (isAudioDraftDisabled) {
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

        // Amber circular checkmark — top-end corner when selected
        if (selected) {
            Canvas(
                modifier = Modifier
                    .size(28.dp)
                    .align(Alignment.TopEnd)
                    .padding(top = Spacing.sm, end = Spacing.sm)
            ) {
                // Filled amber circle
                drawCircle(
                    color  = SemanticWarning,
                    radius = size.minDimension / 2f
                )
                // White checkmark stroke
                val path = Path().apply {
                    moveTo(size.width * 0.25f, size.height * 0.52f)
                    lineTo(size.width * 0.44f, size.height * 0.70f)
                    lineTo(size.width * 0.76f, size.height * 0.32f)
                }
                drawPath(
                    path  = path,
                    color = Color.White,
                    style = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round)
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

internal fun Entry.isAudioOnlyDraftCard(): Boolean =
    audioPath != null && cleanedText.isNullOrBlank() && rawTranscript.isBlank()

internal fun entryCardDisplayText(
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
                    ),
                    Entry(
                        id            = 3L,
                        rawTranscript = "",
                        cleanedText   = null,
                        isDraft       = true,
                        language      = "en",
                        createdAt     = System.currentTimeMillis() - 172_800_000L,
                        wordCount     = 0,
                        audioPath     = "/tmp/test.m4a"
                    )
                )
            ),
            onEntryClick      = {},
            onBack            = {},
            onLongPress       = {},
            onToggleSelection = {},
            onSelectAll       = {},
            onDeselectAll     = {},
            onExitSelection   = {},
            onDeleteTapped    = {},
            onDeleteCancelled = {},
            onDeleteConfirmed = {}
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun EntryListSelectionPreview() {
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
                        rawTranscript = "Had a long call with the team about the product roadmap.",
                        cleanedText   = "Had a long call with the team about the product roadmap.",
                        isDraft       = false,
                        language      = "en",
                        createdAt     = System.currentTimeMillis() - 86_400_000L,
                        wordCount     = 11
                    )
                ),
                selectionMode = true,
                selectedIds   = setOf(1L)
            ),
            onEntryClick      = {},
            onBack            = {},
            onLongPress       = {},
            onToggleSelection = {},
            onSelectAll       = {},
            onDeselectAll     = {},
            onExitSelection   = {},
            onDeleteTapped    = {},
            onDeleteCancelled = {},
            onDeleteConfirmed = {}
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun EntryListScreenEmptyPreview() {
    WrAItTheme {
        EntryListScreen(
            uiState           = EntryListUiState(),
            onEntryClick      = {},
            onBack            = {},
            onLongPress       = {},
            onToggleSelection = {},
            onSelectAll       = {},
            onDeselectAll     = {},
            onExitSelection   = {},
            onDeleteTapped    = {},
            onDeleteCancelled = {},
            onDeleteConfirmed = {}
        )
    }
}
