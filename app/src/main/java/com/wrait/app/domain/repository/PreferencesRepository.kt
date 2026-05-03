package com.wrait.app.domain.repository

import com.wrait.app.domain.model.LanguagePreferences
import com.wrait.app.domain.model.PrivacyMode
import kotlinx.coroutines.flow.Flow

interface PreferencesRepository {
    val languagePreferences: Flow<LanguagePreferences>
    val selectedLanguage: Flow<String>
    val hasEverRecorded: Flow<Boolean>
    val privacyMode: Flow<PrivacyMode>
    val deviceRegistered: Flow<Boolean>
    suspend fun saveLanguagePreferences(preferences: LanguagePreferences)
    suspend fun setLanguage(language: String)
    suspend fun setHasEverRecorded(value: Boolean)
    suspend fun savePrivacyMode(mode: PrivacyMode)
    suspend fun seedPrivacyModeOnce(default: PrivacyMode)
    suspend fun setDeviceRegistered(value: Boolean)
}
