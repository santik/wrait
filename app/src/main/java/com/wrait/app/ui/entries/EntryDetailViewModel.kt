package com.wrait.app.ui.entries

import android.util.Log
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.repository.EntryRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

@HiltViewModel
class EntryDetailViewModel @Inject constructor(
    private val entryRepository: EntryRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val entryId: Long = savedStateHandle.get<Long>("entryId") ?: run {
        Log.e("EntryDetailViewModel", "Missing or invalid entryId in navigation arguments")
        0L
    }

    val entry: StateFlow<Result<Entry?>> = entryRepository
        .getEntryById(entryId)
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = Result.success(null)
        )

    private val _showDeleteDialog = MutableStateFlow(false)
    val showDeleteDialog: StateFlow<Boolean> = _showDeleteDialog.asStateFlow()

    fun onDeleteTapped()    { _showDeleteDialog.value = true  }
    fun onDeleteCancelled() { _showDeleteDialog.value = false }

    fun confirmDelete(onDeleted: () -> Unit) {
        _showDeleteDialog.value = false
        viewModelScope.launch {
            try {
                withContext(Dispatchers.IO) { entryRepository.deleteEntries(listOf(entryId)) }
                onDeleted()
            } catch (e: Exception) {
                Log.e("EntryDetailViewModel", "Failed to delete entry $entryId", e)
            }
        }
    }
}
