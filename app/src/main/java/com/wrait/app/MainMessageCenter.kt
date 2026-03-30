package com.wrait.app

import android.util.Log
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.api.OpenAiApiService
import com.wrait.app.di.IoDispatcher
import com.wrait.app.domain.model.AppMessage
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.model.MessageStripLevel
import com.wrait.app.domain.model.MessageType
import com.wrait.app.domain.repository.EntryRepository
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale
import java.util.UUID
import javax.inject.Inject

class MainMessageCenter @Inject constructor(
    private val entryRepository: EntryRepository,
    private val openAiApiService: OpenAiApiService,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
    private val scope: CoroutineScope
) {
    private val _messages = MutableStateFlow<List<AppMessage>>(emptyList())
    val messages: StateFlow<List<AppMessage>> = _messages.asStateFlow()

    val messageStripLevel: StateFlow<MessageStripLevel> = _messages
        .map { list ->
            if (list.any { it.type == MessageType.CleanupFailed || it.type == MessageType.NetworkError })
                MessageStripLevel.Warning
            else
                MessageStripLevel.None
        }
        .stateIn(scope, SharingStarted.WhileSubscribed(5_000), MessageStripLevel.None)

    fun dismissMessage(id: UUID) {
        _messages.update { list -> list.filter { it.id != id } }
    }

    fun retryCleanup(messageId: UUID, entryId: Long) {
        scope.launch {
            dismissMessage(messageId)
            try {
                val entry = entryRepository.getEntryById(entryId).first().getOrNull() ?: return@launch
                when (val result = openAiApiService.cleanupTranscript(entry.rawTranscript)) {
                    is CleanupResult.Success -> {
                        val wordCount = result.cleanedText.trim()
                            .split(Regex("\\s+")).count { it.isNotEmpty() }
                        withContext(ioDispatcher) {
                            entryRepository.updateWithCleanedText(entryId, result.cleanedText, wordCount)
                        }
                        addMessage(MessageType.DraftCleaned, entry)
                    }
                    is CleanupResult.Failure -> addMessage(MessageType.CleanupFailed, entry)
                }
            } catch (e: Exception) {
                Log.e(TAG, "retryCleanup failed for entry $entryId", e)
            }
        }
    }

    suspend fun retryPendingDrafts() {
        val drafts = entryRepository.getPendingDrafts()
        if (drafts.isEmpty()) return
        Log.d(TAG, "Retrying ${drafts.size} pending draft(s)")
        drafts.forEach { entry ->
            currentCoroutineContext().ensureActive()
            try {
                when (val result = openAiApiService.cleanupTranscript(entry.rawTranscript)) {
                    is CleanupResult.Success -> {
                        val wordCount = result.cleanedText.trim()
                            .split(Regex("\\s+")).count { it.isNotEmpty() }
                        withContext(ioDispatcher) {
                            entryRepository.updateWithCleanedText(entry.id, result.cleanedText, wordCount)
                        }
                        addMessage(MessageType.DraftCleaned, entry)
                    }
                    is CleanupResult.Failure -> addMessage(MessageType.CleanupFailed, entry)
                }
            } catch (e: Exception) {
                // One draft failing must not abort the rest of the retry loop
                Log.e(TAG, "Unexpected error retrying draft ${entry.id}", e)
            }
        }
    }

    fun addMessage(type: MessageType, entry: Entry) {
        val day = formatEntryDay(entry.createdAt)
        val message = when (type) {
            MessageType.DraftCleaned -> AppMessage(
                id          = UUID.randomUUID(),
                type        = MessageType.DraftCleaned,
                title       = "Entry cleaned",
                description = "Your draft from $day was cleaned up.",
                entryId     = entry.id,
                createdAt   = System.currentTimeMillis(),
            )
            MessageType.CleanupFailed -> AppMessage(
                id          = UUID.randomUUID(),
                type        = MessageType.CleanupFailed,
                title       = "Cleanup failed",
                description = "Could not clean up your entry from $day.",
                actionLabel = "Retry",
                entryId     = entry.id,
                createdAt   = System.currentTimeMillis(),
            )
            MessageType.NetworkError -> AppMessage(
                id          = UUID.randomUUID(),
                type        = MessageType.NetworkError,
                title       = "Saved as draft",
                description = "Your entry from $day was saved as a draft — will retry on next open.",
                entryId     = entry.id,
                createdAt   = System.currentTimeMillis(),
            )
        }
        _messages.update { it + message }
        if (type == MessageType.DraftCleaned) {
            scope.launch {
                delay(48L * 60 * 60 * 1_000)
                dismissMessage(message.id)
            }
        }
    }

    private fun formatEntryDay(createdAt: Long): String {
        val zone      = ZoneId.systemDefault()
        val today     = LocalDate.now(zone)
        val entryDate = Instant.ofEpochMilli(createdAt).atZone(zone).toLocalDate()
        return when (entryDate) {
            today                -> "today"
            today.minusDays(1)   -> "yesterday"
            else                 -> entryDate.dayOfWeek
                .getDisplayName(TextStyle.FULL, Locale.getDefault())
                .lowercase().replaceFirstChar { it.uppercaseChar() }
        }
    }

    private companion object {
        private const val TAG = "MainMessageCenter"
    }
}
