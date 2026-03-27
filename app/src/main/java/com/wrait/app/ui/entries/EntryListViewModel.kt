package com.wrait.app.ui.entries

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.repository.EntryRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

data class EntryListUiState(
    val entries: List<Entry> = emptyList(),
    val selectionMode: Boolean = false,
    val selectedIds: Set<Long> = emptySet(),
    val showDeleteDialog: Boolean = false,
    /** Count of entries deleted in the last confirmed deletion. Read once on back-navigation, then cleared. */
    val lastDeletedCount: Int = 0
)

private data class SelectionState(
    val active: Boolean = false,
    val ids: Set<Long> = emptySet(),
    val showDialog: Boolean = false,
    val lastDeletedCount: Int = 0
)

@HiltViewModel
class EntryListViewModel @Inject constructor(
    private val entryRepository: EntryRepository
) : ViewModel() {

    private val _selectionState = MutableStateFlow(SelectionState())

    val uiState: StateFlow<EntryListUiState> = combine(
        entryRepository.getAllEntries(),
        _selectionState
    ) { entries, sel ->
        EntryListUiState(
            entries          = entries,
            selectionMode    = sel.active,
            selectedIds      = sel.ids,
            showDeleteDialog = sel.showDialog,
            lastDeletedCount = sel.lastDeletedCount
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = EntryListUiState()
    )

    fun enterSelectionMode(firstId: Long) {
        _selectionState.update { SelectionState(active = true, ids = setOf(firstId)) }
    }

    fun toggleSelection(id: Long) {
        _selectionState.update { s ->
            val updated = if (id in s.ids) s.ids - id else s.ids + id
            s.copy(ids = updated)
        }
    }

    fun selectAll(allIds: List<Long>) {
        _selectionState.update { it.copy(ids = allIds.toSet()) }
    }

    fun deselectAll() {
        _selectionState.update { it.copy(ids = emptySet()) }
    }

    fun exitSelectionMode() {
        _selectionState.update { SelectionState() }
    }

    fun onDeleteButtonTapped() {
        _selectionState.update { it.copy(showDialog = true) }
    }

    fun onDeleteCancelled() {
        _selectionState.update { it.copy(showDialog = false) }
    }

    fun confirmDelete() {
        val ids = _selectionState.value.ids.toList()
        if (ids.isEmpty()) return
        viewModelScope.launch {
            withContext(Dispatchers.IO) { entryRepository.deleteEntries(ids) }
            // Exit selection mode, record count for status line on main screen
            _selectionState.update { SelectionState(lastDeletedCount = ids.size) }
        }
    }

    fun clearDeletedCount() {
        _selectionState.update { it.copy(lastDeletedCount = 0) }
    }
}
