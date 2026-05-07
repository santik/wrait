package com.wrait.app.ui.entries

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wrait.app.analytics.AnalyticsEntrySource
import com.wrait.app.analytics.trackSafely
import com.wrait.app.analytics.AnalyticsTracker
import com.wrait.app.di.IoDispatcher
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.repository.EntryRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

data class EntryListUiState(
    val entries: List<Entry> = emptyList()
)

@HiltViewModel
class EntryListViewModel @Inject constructor(
    private val entryRepository: EntryRepository,
    private val analyticsTracker: AnalyticsTracker,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : ViewModel() {

    val uiState: StateFlow<EntryListUiState> = entryRepository.getAllEntries()
        .map { entries -> EntryListUiState(entries = entries) }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(STATE_SUBSCRIPTION_TIMEOUT_MS),
            initialValue = EntryListUiState()
        )

    fun onEntriesListOpened(entryCount: Int) {
        analyticsTracker.trackSafely(TAG, "entries list opened") {
            trackEntriesListOpened(entryCount)
        }
    }

    fun onDeleteInitiated(id: Long) {
        uiState.value.entries.firstOrNull { it.id == id }?.let { currentEntry ->
            analyticsTracker.trackSafely(TAG, "entry delete initiated") {
                trackEntryDeleteInitiated(AnalyticsEntrySource.List, currentEntry.isDraft)
            }
            return
        }

        viewModelScope.launch {
            val currentEntry = currentEntryForAnalytics(id) ?: return@launch
            analyticsTracker.trackSafely(TAG, "entry delete initiated") {
                trackEntryDeleteInitiated(AnalyticsEntrySource.List, currentEntry.isDraft)
            }
        }
    }

    fun deleteEntry(id: Long) {
        viewModelScope.launch {
            val currentEntry = currentEntryForAnalytics(id)
            try {
                withContext(ioDispatcher) { entryRepository.deleteEntries(listOf(id)) }
                if (currentEntry != null) {
                    analyticsTracker.trackSafely(TAG, "entry deleted") {
                        trackEntryDeleted(AnalyticsEntrySource.List, currentEntry.isDraft)
                    }
                }
            } catch (_: Exception) {
                // DB errors are silent — the entry remains in the list if deletion fails,
                // which is the correct fail-safe (no phantom deletes).
            }
        }
    }

    private suspend fun currentEntryForAnalytics(id: Long): Entry? {
        val visibleEntry = uiState.value.entries.firstOrNull { it.id == id }
        if (visibleEntry != null) return visibleEntry

        return entryRepository.getEntryByIdOnce(id).getOrNull()
    }

    private companion object {
        private const val TAG = "EntryListViewModel"
        private const val STATE_SUBSCRIPTION_TIMEOUT_MS = 5_000L
    }
}
