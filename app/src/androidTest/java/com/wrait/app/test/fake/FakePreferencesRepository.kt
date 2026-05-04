package com.wrait.app.test.fake

import com.wrait.app.domain.model.LanguagePreferences
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.model.normalizeLanguagePreferences
import com.wrait.app.domain.repository.PreferencesRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map

class FakePreferencesRepository(
    initialLanguage: String = "en-US",
    initialSelectedLanguages: List<String> = listOf(initialLanguage),
    initialPrivacyMode: PrivacyMode = PrivacyMode.MODE_BEST,
    initialHasConfirmedLanguagePreferences: Boolean = false,
    initialHasEverRecorded: Boolean = false,
    initialDeviceRegistered: Boolean = false,
) : PreferencesRepository {

    private val _languagePreferences = MutableStateFlow(
        normalizeLanguagePreferences(
            selectedLanguages = initialSelectedLanguages,
            primaryLanguage = initialLanguage,
        )
    )
    override val languagePreferences: Flow<LanguagePreferences> = _languagePreferences
    override val selectedLanguage: Flow<String> = _languagePreferences.map { it.primaryLanguage }

    private val _hasConfirmedLanguagePreferences =
        MutableStateFlow(initialHasConfirmedLanguagePreferences)
    override val hasConfirmedLanguagePreferences: Flow<Boolean> = _hasConfirmedLanguagePreferences

    private val _hasEverRecorded = MutableStateFlow(initialHasEverRecorded)
    override val hasEverRecorded: Flow<Boolean> = _hasEverRecorded

    private val _privacyMode = MutableStateFlow(initialPrivacyMode)
    override val privacyMode: Flow<PrivacyMode> = _privacyMode

    private val _deviceRegistered = MutableStateFlow(initialDeviceRegistered)
    override val deviceRegistered: Flow<Boolean> = _deviceRegistered

    // Tracks whether an explicit savePrivacyMode (or first seedPrivacyModeOnce) call has been made.
    // Mirrors production semantics: seedPrivacyModeOnce is a no-op if the DataStore key is already present.
    // The constructor's initialPrivacyMode does NOT set this flag (fresh store = key absent).
    private var _modeExplicitlySet = false

    override suspend fun saveLanguagePreferences(preferences: LanguagePreferences) {
        _languagePreferences.value = normalizeLanguagePreferences(
            selectedLanguages = preferences.selectedLanguages,
            primaryLanguage = preferences.primaryLanguage,
        )
    }

    override suspend fun setLanguage(language: String) {
        saveLanguagePreferences(
            normalizeLanguagePreferences(
                selectedLanguages = listOf(language),
                primaryLanguage = language,
            )
        )
    }

    override suspend fun setHasConfirmedLanguagePreferences(value: Boolean) {
        _hasConfirmedLanguagePreferences.value = value
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

    override suspend fun setDeviceRegistered(value: Boolean) {
        _deviceRegistered.value = value
    }

    suspend fun setPrimaryLanguage(language: String) {
        val current = _languagePreferences.value
        saveLanguagePreferences(
            normalizeLanguagePreferences(
                selectedLanguages = current.selectedLanguages + language,
                primaryLanguage = language,
            )
        )
    }

    suspend fun setSelectedLanguages(languages: List<String>, primaryLanguage: String? = null) {
        saveLanguagePreferences(
            normalizeLanguagePreferences(
                selectedLanguages = languages,
                primaryLanguage = primaryLanguage ?: languages.firstOrNull(),
            )
        )
    }

    fun currentLanguagePreferences(): LanguagePreferences =
        _languagePreferences.value
}
