package com.wrait.app.ui.entries

import android.content.ActivityNotFoundException
import android.content.Intent
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.em
import com.wrait.app.R
import com.wrait.app.domain.model.Entry
import com.wrait.app.ui.theme.DesignTokens
import com.wrait.app.ui.theme.WrAItTheme
import java.time.Instant
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale

@Composable
fun EntryDetailScreen(
    entryResult:       Result<Entry?>,
    showDeleteDialog:  Boolean,
    editedText:        String?,
    onTextChanged:     (String) -> Unit,
    showDevDraft:      Boolean = false,
    onBack:            () -> Unit,
    onDeleteTapped:    () -> Unit,
    onDeleteCancelled: () -> Unit,
    onDeleteConfirmed: () -> Unit,
    modifier: Modifier = Modifier
) {
    val entry = entryResult.getOrNull()
    val backDescription = stringResource(R.string.entry_detail_back_description)
    val shareDescription = stringResource(R.string.entry_detail_share_description)
    val shareSheetTitle = stringResource(R.string.entry_detail_share_title)
    val shareUnavailableMessage = stringResource(R.string.entry_detail_share_unavailable)
    val scrollState = rememberScrollState()
    val swipeBackThresholdPx = with(LocalDensity.current) { DesignTokens.Gesture.SwipeBackThresholdDp.toPx() }
    var swipeAccumPx by remember { mutableFloatStateOf(0f) }
    var swipeTriggered by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val formattedDate = entry?.let { rememberFormattedDate(it.createdAt) }
    val shareText = entry?.shareableTextForShare()
    val keyboardController = LocalSoftwareKeyboardController.current
    val focusManager = LocalFocusManager.current
    val dismissAndBack: () -> Unit = {
        keyboardController?.hide()
        focusManager.clearFocus()
        onBack()
    }
    val currentDismissAndBack by rememberUpdatedState(dismissAndBack)

    val swipeToDismissConnection = remember(swipeBackThresholdPx, scrollState) {
        object : NestedScrollConnection {
            override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                if (source != NestedScrollSource.UserInput) return Offset.Zero
                if (scrollState.value == 0 && available.y > 0) {
                    swipeAccumPx += available.y
                    if (!swipeTriggered && swipeAccumPx >= swipeBackThresholdPx) {
                        swipeTriggered = true
                        currentDismissAndBack()
                    }
                } else {
                    swipeAccumPx = 0f
                    swipeTriggered = false
                }
                return Offset.Zero
            }

            override suspend fun onPreFling(available: Velocity): Velocity {
                swipeAccumPx = 0f
                swipeTriggered = false
                return Velocity.Zero
            }

            override suspend fun onPostFling(consumed: Velocity, available: Velocity): Velocity {
                swipeAccumPx = 0f
                swipeTriggered = false
                return Velocity.Zero
            }
        }
    }

    BackHandler(onBack = dismissAndBack)

    Box(
        modifier = modifier
            .fillMaxSize()
            .statusBarsPadding()
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .nestedScroll(swipeToDismissConnection)
                .verticalScroll(scrollState)
                .semantics {
                    if (entry != null) {
                        contentDescription = "Entry detail"
                        if (entry.isDraft) stateDescription = "Draft entry"
                    }
                }
        ) {
            // Header actions: back on the left, share/delete on the right
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = DesignTokens.Spacing.md, start = DesignTokens.Spacing.sm, end = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(
                    onClick = dismissAndBack,
                    modifier = Modifier.semantics { contentDescription = backDescription },
                ) {
                    Icon(
                        imageVector        = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = null,   // described by parent semantics above
                        tint               = MaterialTheme.colorScheme.surface
                    )
                }

                Row {
                    if (shareText != null && formattedDate != null) {
                        IconButton(
                            onClick = {
                                val intent = Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(Intent.EXTRA_TEXT, buildShareMessage(formattedDate, shareText))
                                }
                                if (intent.resolveActivity(context.packageManager) != null) {
                                    try {
                                        context.startActivity(Intent.createChooser(intent, shareSheetTitle))
                                    } catch (_: ActivityNotFoundException) {
                                        Toast.makeText(
                                            context,
                                            shareUnavailableMessage,
                                            Toast.LENGTH_SHORT,
                                        ).show()
                                    }
                                } else {
                                    Toast.makeText(
                                        context,
                                        shareUnavailableMessage,
                                        Toast.LENGTH_SHORT,
                                    ).show()
                                }
                            }
                        ) {
                            Icon(
                                imageVector = Icons.Default.Share,
                                contentDescription = shareDescription,
                                tint = MaterialTheme.colorScheme.surface,
                            )
                        }
                    }

                    if (entryResult.isSuccess && entry != null) {
                        IconButton(onClick = onDeleteTapped) {
                            Icon(
                                imageVector = Icons.Default.Delete,
                                contentDescription = "Delete entry",
                                tint = MaterialTheme.colorScheme.surface,
                            )
                        }
                    }
                }
            }

            when {
                entryResult.isFailure -> ErrorState(
                    message = entryResult.exceptionOrNull()?.message
                        ?: stringResource(R.string.entry_detail_error_loading)
                )
                entry != null && formattedDate != null -> EntryDetailContent(
                    entry = entry,
                    formattedDate = formattedDate,
                    editedText = editedText,
                    onTextChanged = onTextChanged,
                    showDevDraft = showDevDraft,
                )
                // entry == null → initial load (null lasts at most one frame); render nothing
            }
        }

    }

    // Confirmation dialog
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = onDeleteCancelled,
            title   = { Text("Delete this entry?") },
            text    = { Text("This cannot be undone.") },
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

// ── Private composables ──────────────────────────────────────────────────────

@Composable
private fun EntryDetailContent(
    entry: Entry,
    formattedDate: String,
    editedText: String?,
    onTextChanged: (String) -> Unit,
    showDevDraft: Boolean,
) {
    val draftNotice   = stringResource(R.string.entry_detail_draft_notice)
    val devDraftText = entryDetailDevDraftText(entry, showDevDraft)

    Column(
        modifier = Modifier.padding(horizontal = DesignTokens.Spacing.lg)
    ) {
        Spacer(modifier = Modifier.height(DesignTokens.Spacing.sm))

        // Date + time header
        Text(
            text  = formattedDate,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.tertiary
        )

        Spacer(modifier = Modifier.height(DesignTokens.Spacing.md))

        // Draft notice
        if (entry.isDraft) {
            Text(
                text  = draftNotice,
                style = MaterialTheme.typography.labelSmall,
                color = WrAItTheme.semanticColors.warning
            )
            Spacer(modifier = Modifier.height(DesignTokens.Spacing.sm))
        }

        // Body text
        if (!entry.isDraft && editedText != null) {
            BasicTextField(
                value = editedText,
                onValueChange = onTextChanged,
                textStyle = MaterialTheme.typography.bodyLarge.copy(
                    lineHeight = 1.7.em,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                ),
                modifier = Modifier.fillMaxWidth().imePadding()
            )
        } else {
            SelectionContainer {
                Text(
                    text  = when {
                        !entry.cleanedText.isNullOrBlank() -> entry.cleanedText
                        entry.rawTranscript.isNotBlank() -> entry.rawTranscript
                        entry.audioPath != null -> "Audio draft. Not transcribed yet."
                        else -> ""
                    },
                    style = MaterialTheme.typography.bodyLarge.copy(lineHeight = 1.7.em),
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        if (devDraftText != null) {
            Spacer(modifier = Modifier.height(DesignTokens.Spacing.sm))
            Text(
                text = devDraftText,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.tertiary
            )
        }

        Spacer(modifier = Modifier.height(DesignTokens.Spacing.xxl))
    }
}

internal fun Entry.shareableTextForShare(): String? {
    if (isDraft) return null
    if (!cleanedText.isNullOrBlank()) return cleanedText
    if (rawTranscript.isNotBlank()) return rawTranscript
    return null
}

internal fun buildShareMessage(formattedDate: String, body: String): String =
    "$formattedDate\n\n$body"

internal fun entryDetailDevDraftText(
    entry: Entry,
    showDevDraft: Boolean,
): String? {
    if (!showDevDraft) return null
    if (entry.isDraft) return null
    val cleaned = entry.cleanedText?.trim().orEmpty()
    val raw = entry.rawTranscript.trim()
    if (cleaned.isBlank() || raw.isBlank()) return null

    val rawPreview = raw.lines().firstOrNull { it.isNotBlank() }?.trim().orEmpty()
    if (rawPreview.isBlank()) return null
    return "draft: $rawPreview"
}

@Composable
private fun ErrorState(message: String) {
    Box(
        modifier          = Modifier
            .fillMaxSize()
            .padding(DesignTokens.Spacing.lg),
        contentAlignment  = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text  = stringResource(R.string.entry_detail_error_loading),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.error
            )
            Spacer(modifier = Modifier.height(DesignTokens.Spacing.sm))
            Text(
                text  = message,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun rememberFormattedDate(createdAt: Long): String =
    remember(createdAt) {
        val zdt       = Instant.ofEpochMilli(createdAt).atZone(ZoneId.systemDefault())
        val dayOfWeek = zdt.dayOfWeek.getDisplayName(TextStyle.FULL, Locale.getDefault())
        val day       = zdt.dayOfMonth
        val month     = zdt.month.getDisplayName(TextStyle.FULL, Locale.getDefault())
        val time      = String.format(Locale.getDefault(), "%02d:%02d", zdt.hour, zdt.minute)
        "$dayOfWeek, $day $month · $time"
    }

// ── Previews ─────────────────────────────────────────────────────────────────

@Preview(showBackground = true)
@Composable
private fun EntryDetailScreenDraftPreview() {
    WrAItTheme {
        EntryDetailScreen(
            entryResult       = Result.success(
                Entry(
                    id            = 1L,
                    rawTranscript = "The meeting this morning was difficult. I didn't expect the team to push back on the timeline so strongly. We need to rethink the whole approach.",
                    cleanedText   = null,
                    isDraft       = true,
                    language      = "en",
                    createdAt     = System.currentTimeMillis(),
                    wordCount     = 0
                )
            ),
            showDeleteDialog  = false,
            editedText        = null,
            onTextChanged     = {},
            onBack            = {},
            onDeleteTapped    = {},
            onDeleteCancelled = {},
            onDeleteConfirmed = {}
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun EntryDetailScreenCleanPreview() {
    WrAItTheme {
        EntryDetailScreen(
            entryResult       = Result.success(
                Entry(
                    id            = 2L,
                    rawTranscript = "raw text",
                    cleanedText   = "The meeting this morning was difficult. I didn't expect the team to push back on the timeline so strongly. We need to rethink the whole approach before the next sprint.",
                    isDraft       = false,
                    language      = "en",
                    createdAt     = System.currentTimeMillis() - 86_400_000L,
                    wordCount     = 35
                )
            ),
            showDeleteDialog  = false,
            editedText        = "The meeting this morning was difficult. I didn't expect the team to push back on the timeline so strongly. We need to rethink the whole approach before the next sprint.",
            onTextChanged     = {},
            onBack            = {},
            onDeleteTapped    = {},
            onDeleteCancelled = {},
            onDeleteConfirmed = {}
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun EntryDetailScreenErrorPreview() {
    WrAItTheme {
        EntryDetailScreen(
            entryResult       = Result.failure(Exception("Database read failed")),
            showDeleteDialog  = false,
            editedText        = null,
            onTextChanged     = {},
            onBack            = {},
            onDeleteTapped    = {},
            onDeleteCancelled = {},
            onDeleteConfirmed = {}
        )
    }
}
