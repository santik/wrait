package com.wrait.app.data.repository

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import com.wrait.app.data.WraitStorageConfig
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.model.SUPPORTED_LANGUAGE_CODES
import com.wrait.app.domain.repository.PreferencesRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import java.io.IOException
import java.util.Locale
import javax.inject.Inject

class PreferencesRepositoryImpl @Inject constructor(
    private val dataStore: DataStore<Preferences>
) : PreferencesRepository {

    private object PreferencesKeys {
        val SELECTED_LANGUAGE = stringPreferencesKey("selected_language")
        val HAS_EVER_RECORDED = booleanPreferencesKey("has_ever_recorded")
        val PRIVACY_MODE = stringPreferencesKey("privacy_mode")
        val DEVICE_REGISTERED = booleanPreferencesKey(WraitStorageConfig.DEVICE_REGISTERED)
    }

    private val preferences: Flow<Preferences> = dataStore.data
        .catch { exception ->
            if (exception is IOException) {
                emit(emptyPreferences())
            } else {
                throw exception
            }
        }

    override val selectedLanguage: Flow<String> = preferences.map { stored ->
        val code = stored[PreferencesKeys.SELECTED_LANGUAGE]
            ?: Locale.getDefault().toLanguageTag()
        if (code in SUPPORTED_LANGUAGE_CODES) code else "en-US"
    }

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

    override suspend fun setLanguage(language: String) {
        dataStore.edit { preferences ->
            preferences[PreferencesKeys.SELECTED_LANGUAGE] = language
        }
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
