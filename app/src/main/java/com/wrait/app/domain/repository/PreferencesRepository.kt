package com.wrait.app.domain.repository

import kotlinx.coroutines.flow.Flow

interface PreferencesRepository {
    val selectedLanguage: Flow<String>
    suspend fun setLanguage(language: String)
}
