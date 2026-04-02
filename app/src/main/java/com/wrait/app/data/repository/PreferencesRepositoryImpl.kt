package com.wrait.app.data.repository

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
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
        stored[PreferencesKeys.SELECTED_LANGUAGE] ?: Locale.getDefault().toLanguageTag()
    }

    override val hasEverRecorded: Flow<Boolean> = preferences.map { stored ->
        stored[PreferencesKeys.HAS_EVER_RECORDED] ?: false
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
}
