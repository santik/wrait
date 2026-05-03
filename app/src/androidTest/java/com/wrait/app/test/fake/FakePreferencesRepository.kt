package com.wrait.app.test.fake

import com.wrait.app.domain.model.CleanupBackend
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.repository.PreferencesRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow

class FakePreferencesRepository(
    initialLanguage: String = "en-US",
    initialPrivacyMode: PrivacyMode = PrivacyMode.MODE_BEST,
    initialHasEverRecorded: Boolean = false,
    initialDeviceRegistered: Boolean = false,
    initialCleanupBackend: CleanupBackend = CleanupBackend.ANDROID,
) : PreferencesRepository {

    private val _selectedLanguage = MutableStateFlow(initialLanguage)
    override val selectedLanguage: Flow<String> = _selectedLanguage

    private val _hasEverRecorded = MutableStateFlow(initialHasEverRecorded)
    override val hasEverRecorded: Flow<Boolean> = _hasEverRecorded

    private val _privacyMode = MutableStateFlow(initialPrivacyMode)
    override val privacyMode: Flow<PrivacyMode> = _privacyMode

    private val _cleanupBackend = MutableStateFlow(initialCleanupBackend)
    override val cleanupBackend: Flow<CleanupBackend> = _cleanupBackend

    private val _deviceRegistered = MutableStateFlow(initialDeviceRegistered)
    override val deviceRegistered: Flow<Boolean> = _deviceRegistered

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

    override suspend fun saveCleanupBackend(backend: CleanupBackend) {
        _cleanupBackend.value = backend
    }

    override suspend fun setDeviceRegistered(value: Boolean) {
        _deviceRegistered.value = value
    }
}
