package com.wrait.app.ui.entries

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.repository.EntryRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
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
    private val entryRepository: EntryRepository
) : ViewModel() {

    val uiState: StateFlow<EntryListUiState> = entryRepository.getAllEntries()
        .map { entries -> EntryListUiState(entries = entries) }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = EntryListUiState()
        )

    fun deleteEntry(id: Long) {
        viewModelScope.launch {
            try {
                withContext(Dispatchers.IO) { entryRepository.deleteEntries(listOf(id)) }
            } catch (_: Exception) {
                // DB errors are silent — the entry remains in the list if deletion fails,
                // which is the correct fail-safe (no phantom deletes).
            }
        }
    }
}
