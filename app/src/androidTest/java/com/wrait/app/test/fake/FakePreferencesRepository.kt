package com.wrait.app.test.fake

import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.repository.PreferencesRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow

class FakePreferencesRepository(
    initialLanguage: String = "en-US",
    initialPrivacyMode: PrivacyMode = PrivacyMode.MODE_BEST,
    initialHasEverRecorded: Boolean = false,
) : PreferencesRepository {

    private val _selectedLanguage = MutableStateFlow(initialLanguage)
    override val selectedLanguage: Flow<String> = _selectedLanguage

    private val _hasEverRecorded = MutableStateFlow(initialHasEverRecorded)
    override val hasEverRecorded: Flow<Boolean> = _hasEverRecorded

    private val _privacyMode = MutableStateFlow(initialPrivacyMode)
    override val privacyMode: Flow<PrivacyMode> = _privacyMode

    // Tracks whether an explicit savePrivacyMode (or first seedPrivacyModeOnce) call has been made.
    // Mirrors production semantics: seedPrivacyModeOnce is a no-op if the DataStore key is already present.
    // The constructor's initialPrivacyMode does NOT set this flag (fresh store = key absent).
    private var _modeExplicitlySet = false

    override suspend fun setLanguage(language: String) {
        _selectedLanguage.value = language
    }

    override suspend fun setHasEverRecorded(value: Boolean) {
        _hasEverRecorded.value = value
    }

    override suspend fun savePrivacyMode(mode: PrivacyMode) {
        _modeExplicitlySet = true
        _privacyMode.value = mode
    }

    override suspend fun seedPrivacyModeOnce(default: PrivacyMode) {
        if (!_modeExplicitlySet) {
            _modeExplicitlySet = true
            _privacyMode.value = default
        }
    }
}
