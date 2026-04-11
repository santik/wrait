package com.wrait.app.ui.entries

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.repository.EntryRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

data class EntryListUiState(
    val entries: List<Entry> = emptyList()
)

@HiltViewModel
class EntryListViewModel @Inject constructor(
    // No `val` needed — entryRepository is only used in the StateFlow initializer below.
    // Hilt still correctly expresses the dependency; nothing needs to access it after init.
    entryRepository: EntryRepository
) : ViewModel() {

    val uiState: StateFlow<EntryListUiState> = entryRepository.getAllEntries()
        .map { entries -> EntryListUiState(entries = entries) }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = EntryListUiState()
        )
}
