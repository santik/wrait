package com.wrait.app.data.repository

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import com.wrait.app.data.WraitStorageConfig
import com.wrait.app.domain.model.LanguagePreferences
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.model.defaultSupportedLanguageCode
import com.wrait.app.domain.model.normalizeLanguagePreferences
import com.wrait.app.domain.repository.PreferencesRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import java.io.IOException
import javax.inject.Inject

class PreferencesRepositoryImpl @Inject constructor(
    private val dataStore: DataStore<Preferences>
) : PreferencesRepository {

    private object PreferencesKeys {
        val PRIMARY_LANGUAGE = stringPreferencesKey("primary_language")
        val SELECTED_LANGUAGES = stringPreferencesKey("selected_languages")
        val SELECTED_LANGUAGE = stringPreferencesKey("selected_language")
        val HAS_EVER_RECORDED = booleanPreferencesKey("has_ever_recorded")
        val PRIVACY_MODE = stringPreferencesKey("privacy_mode")
        val DEVICE_REGISTERED = booleanPreferencesKey(WraitStorageConfig.DEVICE_REGISTERED)
        val LEGACY_TRANSCRIPTION_BACKEND = stringPreferencesKey("transcription_backend")
    }

    private val preferences: Flow<Preferences> = dataStore.data
        .catch { exception ->
            if (exception is IOException) {
                emit(emptyPreferences())
            } else {
                throw exception
            }
        }

    override val languagePreferences: Flow<LanguagePreferences> = preferences.map { stored ->
        val selectedLanguages = stored[PreferencesKeys.SELECTED_LANGUAGES]
            ?.split(',')
            ?.map { it.trim() }
            ?.filter { it.isNotBlank() }
            .orEmpty()
        val legacyLanguage = stored[PreferencesKeys.SELECTED_LANGUAGE]
            ?: defaultSupportedLanguageCode()

        normalizeLanguagePreferences(
            selectedLanguages = if (selectedLanguages.isEmpty()) listOf(legacyLanguage) else selectedLanguages,
            primaryLanguage = stored[PreferencesKeys.PRIMARY_LANGUAGE] ?: legacyLanguage,
        )
    }

    override val selectedLanguage: Flow<String> = languagePreferences.map { it.primaryLanguage }

    override val hasEverRecorded: Flow<Boolean> = preferences.map { stored ->
        stored[PreferencesKeys.HAS_EVER_RECORDED] ?: false
    }

    override val privacyMode: Flow<PrivacyMode> = preferences.map { stored ->
        when (stored[PreferencesKeys.PRIVACY_MODE]) {
            PrivacyMode.MODE_OFFLINE.name -> PrivacyMode.MODE_OFFLINE
            else -> PrivacyMode.MODE_BEST
        }
    }

    override val deviceRegistered: Flow<Boolean> = preferences.map { stored ->
        stored[PreferencesKeys.DEVICE_REGISTERED] ?: false
    }

    override suspend fun saveLanguagePreferences(preferences: LanguagePreferences) {
        val normalized = normalizeLanguagePreferences(
            selectedLanguages = preferences.selectedLanguages,
            primaryLanguage = preferences.primaryLanguage,
        )
        dataStore.edit { preferences ->
            preferences[PreferencesKeys.PRIMARY_LANGUAGE] = normalized.primaryLanguage
            preferences[PreferencesKeys.SELECTED_LANGUAGES] =
                normalized.selectedLanguages.joinToString(",")
            // Keep the legacy key aligned during the transition.
            preferences[PreferencesKeys.SELECTED_LANGUAGE] = normalized.primaryLanguage
        }
    }

    override suspend fun setLanguage(language: String) {
        saveLanguagePreferences(
            normalizeLanguagePreferences(
                selectedLanguages = listOf(language),
                primaryLanguage = language,
            )
        )
    }

    override suspend fun setHasEverRecorded(value: Boolean) {
        dataStore.edit { preferences ->
            preferences[PreferencesKeys.HAS_EVER_RECORDED] = value
        }
    }

    override suspend fun savePrivacyMode(mode: PrivacyMode) {
        dataStore.edit { preferences ->
            preferences[PreferencesKeys.PRIVACY_MODE] = mode.name
        }
    }

    override suspend fun seedPrivacyModeOnce(default: PrivacyMode) {
        dataStore.edit { preferences ->
            preferences.remove(PreferencesKeys.LEGACY_TRANSCRIPTION_BACKEND)
            if (!preferences.contains(PreferencesKeys.PRIVACY_MODE)) {
                preferences[PreferencesKeys.PRIVACY_MODE] = default.name
            }
        }
    }

    override suspend fun setDeviceRegistered(value: Boolean) {
        dataStore.edit { preferences ->
            preferences[PreferencesKeys.DEVICE_REGISTERED] = value
        }
    }
}
