package com.wrait.app.test.fake

import com.wrait.app.domain.repository.PreferencesRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf

class FakePreferencesRepository : PreferencesRepository {
    override val selectedLanguage: Flow<String> = flowOf("en-US")
    override suspend fun setLanguage(language: String) {}
}
