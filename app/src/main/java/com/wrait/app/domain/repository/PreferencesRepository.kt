package com.wrait.app.domain.repository

import com.wrait.app.domain.model.CleanupBackend
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.model.TranscriptionBackend
import kotlinx.coroutines.flow.Flow

interface PreferencesRepository {
    val selectedLanguage: Flow<String>
    val hasEverRecorded: Flow<Boolean>
    val privacyMode: Flow<PrivacyMode>
    val transcriptionBackend: Flow<TranscriptionBackend>
    val cleanupBackend: Flow<CleanupBackend>
    val deviceRegistered: Flow<Boolean>
    suspend fun setLanguage(language: String)
    suspend fun setHasEverRecorded(value: Boolean)
    suspend fun savePrivacyMode(mode: PrivacyMode)
    suspend fun seedPrivacyModeOnce(default: PrivacyMode)
    suspend fun saveTranscriptionBackend(backend: TranscriptionBackend)
    suspend fun saveCleanupBackend(backend: CleanupBackend)
    suspend fun setDeviceRegistered(value: Boolean)
}
