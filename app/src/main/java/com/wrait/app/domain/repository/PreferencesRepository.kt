package com.wrait.app.domain.repository

import kotlinx.coroutines.flow.Flow

interface PreferencesRepository {
    val selectedLanguage: Flow<String>
    val hasEverRecorded: Flow<Boolean>
    suspend fun setLanguage(language: String)
    suspend fun setHasEverRecorded(value: Boolean)
}
