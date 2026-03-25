package com.wrait.app

import androidx.lifecycle.ViewModel
import com.wrait.app.domain.repository.PreferencesRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

@HiltViewModel
class MainViewModel @Inject constructor(
    preferencesRepository: PreferencesRepository
) : ViewModel() {
    val selectedLanguage: Flow<String> = preferencesRepository.selectedLanguage
}
