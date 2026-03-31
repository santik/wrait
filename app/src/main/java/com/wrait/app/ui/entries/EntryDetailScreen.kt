package com.wrait.app.ui.entries

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
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
    entryResult: Result<Entry?>,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val entry = entryResult.getOrNull()
    val backDescription = stringResource(R.string.entry_detail_back_description)
    val scrollState = rememberScrollState()
    val swipeThresholdPx = with(androidx.compose.ui.platform.LocalDensity.current) { 120.dp.toPx() }
    var swipeAccumPx by remember { mutableFloatStateOf(0f) }
    var swipeTriggered by remember { mutableStateOf(false) }

    val swipeToDismissConnection = remember {
        object : NestedScrollConnection {
            override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                if (source != NestedScrollSource.UserInput) return Offset.Zero
                if (scrollState.value == 0 && available.y > 0) {
                    swipeAccumPx += available.y
                    if (!swipeTriggered && swipeAccumPx >= swipeThresholdPx) {
                        swipeTriggered = true
                        onBack()
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

    BackHandler(onBack = onBack)

    Column(
        modifier = modifier
            .fillMaxSize()
            .statusBarsPadding()
            .nestedScroll(swipeToDismissConnection)
            .verticalScroll(scrollState)
            .semantics {
                if (entry != null) {
                    contentDescription = "Entry detail"
                    if (entry.isDraft) stateDescription = "Draft entry"
                }
            }
    ) {
        // Back button
        IconButton(
            onClick = onBack,
            modifier = Modifier
                .padding(
                    top   = DesignTokens.Spacing.md,
                    start = DesignTokens.Spacing.sm
                )
                .semantics { contentDescription = backDescription }
        ) {
            Icon(
                imageVector        = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = null,   // described by parent semantics above
                tint               = MaterialTheme.colorScheme.onBackground
            )
        }

        when {
            entryResult.isFailure -> ErrorState(
                message = entryResult.exceptionOrNull()?.message
                    ?: stringResource(R.string.entry_detail_error_loading)
            )
            entry != null -> EntryDetailContent(entry = entry)
            // entry == null → initial load (null lasts at most one frame); render nothing
        }
    }
}

// ── Private composables ──────────────────────────────────────────────────────

@Composable
private fun EntryDetailContent(entry: Entry) {
    val formattedDate = rememberFormattedDate(entry.createdAt)
    val draftNotice   = stringResource(R.string.entry_detail_draft_notice)

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
        SelectionContainer {
            Column {
                Text(
                    text  = entry.cleanedText ?: entry.rawTranscript,
                    style = MaterialTheme.typography.bodyLarge.copy(lineHeight = 1.7.em),
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        Spacer(modifier = Modifier.height(DesignTokens.Spacing.xxl))
    }
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
            entryResult = Result.success(
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
            onBack = {}
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun EntryDetailScreenCleanPreview() {
    WrAItTheme {
        EntryDetailScreen(
            entryResult = Result.success(
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
            onBack = {}
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun EntryDetailScreenErrorPreview() {
    WrAItTheme {
        EntryDetailScreen(
            entryResult = Result.failure(Exception("Database read failed")),
            onBack = {}
        )
    }
}
