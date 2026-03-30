package com.wrait.app.data.repository

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.booleanPreferencesKey
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
        val HAS_PANEL_BEEN_OPENED = booleanPreferencesKey("has_panel_been_opened")
    }

    override val selectedLanguage: Flow<String> = dataStore.data
        .catch { exception ->
            if (exception is IOException) {
                emit(emptyPreferences())
            } else {
                throw exception
            }
        }
        .map { preferences ->
            preferences[PreferencesKeys.SELECTED_LANGUAGE] ?: Locale.getDefault().toLanguageTag()
        }

    override suspend fun setLanguage(language: String) {
        dataStore.edit { preferences ->
            preferences[PreferencesKeys.SELECTED_LANGUAGE] = language
        }
    }

    override val hasPanelBeenOpened: Flow<Boolean> = dataStore.data
        .catch { if (it is IOException) emit(emptyPreferences()) else throw it }
        .map { it[PreferencesKeys.HAS_PANEL_BEEN_OPENED] ?: false }

    override suspend fun markPanelOpened() {
        dataStore.edit { it[PreferencesKeys.HAS_PANEL_BEEN_OPENED] = true }
    }
}
