package com.wrait.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wrait.app.domain.repository.PreferencesRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class MainViewModel @Inject constructor(
    preferencesRepository: PreferencesRepository
) : ViewModel() {
    val selectedLanguage: Flow<String> = preferencesRepository.selectedLanguage

    private val _uiEvent = MutableSharedFlow<MainUiEvent>()
    val uiEvent = _uiEvent.asSharedFlow()

    fun onMainButtonClicked() {
        viewModelScope.launch {
            _uiEvent.emit(MainUiEvent.ShowButtonTappedMessage)
        }
    }
}

sealed class MainUiEvent {
    data object ShowButtonTappedMessage : MainUiEvent()
}
