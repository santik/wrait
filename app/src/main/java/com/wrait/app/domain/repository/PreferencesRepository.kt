package com.wrait.app.domain.repository

import com.wrait.app.domain.model.CleanupBackend
import com.wrait.app.domain.model.PrivacyMode
import kotlinx.coroutines.flow.Flow

interface PreferencesRepository {
    val selectedLanguage: Flow<String>
    val hasEverRecorded: Flow<Boolean>
    val privacyMode: Flow<PrivacyMode>
    val cleanupBackend: Flow<CleanupBackend>
    val deviceRegistered: Flow<Boolean>
    suspend fun setLanguage(language: String)
    suspend fun setHasEverRecorded(value: Boolean)
    suspend fun savePrivacyMode(mode: PrivacyMode)
    suspend fun seedPrivacyModeOnce(default: PrivacyMode)
    suspend fun saveCleanupBackend(backend: CleanupBackend)
    suspend fun setDeviceRegistered(value: Boolean)
}
