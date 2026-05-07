package com.wrait.app.ui.entries

import android.util.Log
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wrait.app.analytics.AnalyticsEntrySource
import com.wrait.app.analytics.AnalyticsTracker
import com.wrait.app.analytics.trackSafely
import com.wrait.app.di.IoDispatcher
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.repository.EntryRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

@HiltViewModel
class EntryDetailViewModel @Inject constructor(
    private val entryRepository: EntryRepository,
    private val analyticsTracker: AnalyticsTracker,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
    private val savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val entryId: Long = savedStateHandle.get<Long>("entryId") ?: run {
        Log.e("EntryDetailViewModel", "Missing or invalid entryId in navigation arguments")
        0L
    }

    val entry: StateFlow<Result<Entry?>> = entryRepository
        .getEntryById(entryId)
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(STATE_SUBSCRIPTION_TIMEOUT_MS),
            initialValue = Result.success(null)
        )

    private val _editedText = MutableStateFlow<String?>(null)
    val editedText: StateFlow<String?> = _editedText.asStateFlow()
    private var hasTrackedEntryOpened = false

    init {
        viewModelScope.launch {
            val currentEntry = currentEntryForAnalytics() ?: return@launch
            applyLoadedEntry(currentEntry)
        }
        viewModelScope.launch {
            entry.collect { result ->
                val e = result.getOrNull() ?: return@collect
                applyLoadedEntry(e)
            }
        }
        viewModelScope.launch {
            _editedText.filterNotNull().debounce(500).collect { persistEdit(it) }
        }
    }

    fun onTextChanged(text: String) { _editedText.value = text }

    fun flushEdit() {
        val text = _editedText.value ?: return
        viewModelScope.launch { persistEdit(text) }
    }

    private suspend fun persistEdit(text: String) {
        try {
            val wc = text.trim().split("\\s+".toRegex()).filter { it.isNotEmpty() }.size
            withContext(ioDispatcher) { entryRepository.updateWithCleanedText(entryId, text, wc) }
        } catch (e: Exception) {
            Log.e("EntryDetailViewModel", "Failed to save edit for entry $entryId", e)
        }
    }

    private val _showDeleteDialog = MutableStateFlow(false)
    val showDeleteDialog: StateFlow<Boolean> = _showDeleteDialog.asStateFlow()

    fun onDeleteTapped() {
        _showDeleteDialog.value = true
        entry.value.getOrNull()?.let { currentEntry ->
            analyticsTracker.trackSafely(TAG, "entry delete initiated") {
                trackEntryDeleteInitiated(AnalyticsEntrySource.Detail, currentEntry.isDraft)
            }
            return
        }

        viewModelScope.launch {
            val currentEntry = currentEntryForAnalytics() ?: return@launch
            analyticsTracker.trackSafely(TAG, "entry delete initiated") {
                trackEntryDeleteInitiated(AnalyticsEntrySource.Detail, currentEntry.isDraft)
            }
        }
    }
    fun onDeleteCancelled() { _showDeleteDialog.value = false }

    fun onShareSucceeded() {
        entry.value.getOrNull()?.let { currentEntry ->
            if (currentEntry.isDraft) return

            analyticsTracker.trackSafely(TAG, "entry shared") {
                // This event measures share intent after the chooser launches for finalized entries.
                trackEntryShared(AnalyticsEntrySource.Detail)
            }
            return
        }

        viewModelScope.launch {
            val currentEntry = currentEntryForAnalytics() ?: return@launch
            if (currentEntry.isDraft) return@launch

            analyticsTracker.trackSafely(TAG, "entry shared") {
                // This event measures share intent after the chooser launches for finalized entries.
                trackEntryShared(AnalyticsEntrySource.Detail)
            }
        }
    }

    fun confirmDelete(onDeleted: () -> Unit) {
        _showDeleteDialog.value = false
        val currentEntry = entry.value.getOrNull()
        viewModelScope.launch {
            val trackedEntry = currentEntry ?: currentEntryForAnalytics()
            try {
                withContext(ioDispatcher) { entryRepository.deleteEntries(listOf(entryId)) }
                if (trackedEntry != null) {
                    analyticsTracker.trackSafely(TAG, "entry deleted") {
                        trackEntryDeleted(AnalyticsEntrySource.Detail, trackedEntry.isDraft)
                    }
                }
                onDeleted()
            } catch (e: Exception) {
                Log.e("EntryDetailViewModel", "Failed to delete entry $entryId", e)
            }
        }
    }

    private fun applyLoadedEntry(currentEntry: Entry) {
        if (!hasTrackedEntryOpened) {
            hasTrackedEntryOpened = true
            analyticsTracker.trackSafely(TAG, "entry detail opened") {
                trackEntryDetailOpened(currentEntry.isDraft)
            }
        }
        if (_editedText.value == null && !currentEntry.isDraft) {
            _editedText.value = currentEntry.cleanedText ?: currentEntry.rawTranscript
        }
    }

    private suspend fun currentEntryForAnalytics(): Entry? {
        entry.value.getOrNull()?.let { return it }
        return entryRepository.getEntryByIdOnce(entryId).getOrNull()
    }

    private companion object {
        private const val TAG = "EntryDetailViewModel"
        private const val STATE_SUBSCRIPTION_TIMEOUT_MS = 5_000L
    }
}
