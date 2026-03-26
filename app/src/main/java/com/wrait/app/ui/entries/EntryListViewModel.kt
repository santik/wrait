package com.wrait.app.ui.entries

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.repository.EntryRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class EntryListViewModel @Inject constructor(
    entryRepository: EntryRepository
) : ViewModel() {

    val entries: StateFlow<List<Entry>> = entryRepository.getAllEntries()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = emptyList()
        )
}
