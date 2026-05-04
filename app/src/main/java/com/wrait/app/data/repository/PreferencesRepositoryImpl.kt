package com.wrait.app.data.repository

import android.util.Log
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import com.wrait.app.data.WraitStorageConfig
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.model.defaultSupportedLanguageCode
import com.wrait.app.domain.model.resolveSupportedLanguageCode
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

    override val selectedLanguage: Flow<String> = preferences.map(::resolveStoredLanguage)

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
            val resolved = resolveSupportedLanguageCode(language) ?: defaultSupportedLanguageCode()
            if (!language.equals(resolved, ignoreCase = true)) {
                Log.w(TAG, "Requested language '$language' resolved to '$resolved'")
            }
            preferences[PreferencesKeys.SELECTED_LANGUAGE] = resolved
            preferences.remove(PreferencesKeys.PRIMARY_LANGUAGE)
            preferences.remove(PreferencesKeys.SELECTED_LANGUAGES)
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

    private fun resolveStoredLanguage(stored: Preferences): String {
        resolveSupportedLanguageCode(stored[PreferencesKeys.SELECTED_LANGUAGE])?.let {
            Log.d(TAG, "Resolved selected language from selected_language: $it")
            return it
        }
        resolveSupportedLanguageCode(stored[PreferencesKeys.PRIMARY_LANGUAGE])?.let {
            Log.d(TAG, "Resolved selected language from legacy primary_language: $it")
            return it
        }

        val fromLegacySelection = stored[PreferencesKeys.SELECTED_LANGUAGES]
            ?.split(',')
            ?.asSequence()
            ?.map(String::trim)
            ?.mapNotNull(::resolveSupportedLanguageCode)
            ?.firstOrNull()
        if (fromLegacySelection != null) {
            Log.d(TAG, "Resolved selected language from legacy selected_languages: $fromLegacySelection")
            return fromLegacySelection
        }

        val fallback = defaultSupportedLanguageCode()
        Log.w(TAG, "Falling back to default supported language: $fallback")
        return fallback
    }

    private companion object {
        private const val TAG = "PreferencesRepository"
    }
}
