package com.wrait.app.domain.repository

import com.wrait.app.domain.model.PrivacyMode
import kotlinx.coroutines.flow.Flow

interface PreferencesRepository {
    val selectedLanguage: Flow<String>
    val hasEverRecorded: Flow<Boolean>
    val privacyMode: Flow<PrivacyMode>
    suspend fun setLanguage(language: String)
    suspend fun setHasEverRecorded(value: Boolean)
    suspend fun savePrivacyMode(mode: PrivacyMode)
    suspend fun seedPrivacyModeOnce(default: PrivacyMode)
}
