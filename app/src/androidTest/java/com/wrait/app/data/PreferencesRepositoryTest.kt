package com.wrait.app.data

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.wrait.app.data.repository.PreferencesRepositoryImpl
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.model.SUPPORTED_LANGUAGE_CODES
import com.wrait.app.domain.repository.PreferencesRepository
import java.io.File
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class PreferencesRepositoryTest {

    private val testDispatcher = UnconfinedTestDispatcher()
    private val testScope = TestScope(testDispatcher)

    private lateinit var prefsFile: File
    private lateinit var dataStore: DataStore<Preferences>
    private lateinit var repository: PreferencesRepository

    @Before
    fun setUp() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        prefsFile = File(context.filesDir, "test_prefs_${System.nanoTime()}.preferences_pb")
        dataStore = PreferenceDataStoreFactory.create(
            scope = testScope,
            produceFile = { prefsFile },
        )
        repository = PreferencesRepositoryImpl(dataStore)
    }

    @After
    fun tearDown() {
        testScope.cancel()
        prefsFile.delete()
    }

    @Test
    fun selectedLanguage_defaultsToSupportedCode_onFreshStore() = runTest(testDispatcher) {
        val language = repository.selectedLanguage.first()
        assertTrue(
            "Default language '$language' must be in SUPPORTED_LANGUAGE_CODES",
            language in SUPPORTED_LANGUAGE_CODES,
        )
    }

    @Test
    fun setLanguage_persistsAcrossRead() = runTest(testDispatcher) {
        repository.setLanguage("de-DE")
        val language = repository.selectedLanguage.first()
        assertEquals("de-DE", language)
    }

    @Test
    fun legacySelectedLanguage_migratesOnRead() = runTest(testDispatcher) {
        val legacyKey = stringPreferencesKey("selected_language")
        dataStore.edit { preferences ->
            preferences[legacyKey] = "fr-FR"
        }

        assertEquals("fr-FR", repository.selectedLanguage.first())
    }

    @Test
    fun legacyPrimaryLanguage_migratesOnRead_whenSelectedLanguageMissing() = runTest(testDispatcher) {
        val primaryLanguageKey = stringPreferencesKey("primary_language")
        dataStore.edit { preferences ->
            preferences[primaryLanguageKey] = "de-DE"
        }

        assertEquals("de-DE", repository.selectedLanguage.first())
    }

    @Test
    fun legacySelectedLanguages_migratesFirstValidLanguage_whenNewerKeysMissing() = runTest(testDispatcher) {
        val selectedLanguagesKey = stringPreferencesKey("selected_languages")
        dataStore.edit { preferences ->
            preferences[selectedLanguagesKey] = "xx-YY,fr-FR,de-DE"
        }

        assertEquals("fr-FR", repository.selectedLanguage.first())
    }

    @Test
    fun invalidStoredLanguages_fallBackToSupportedDefault() = runTest(testDispatcher) {
        val selectedLanguageKey = stringPreferencesKey("selected_language")
        val primaryLanguageKey = stringPreferencesKey("primary_language")
        val selectedLanguagesKey = stringPreferencesKey("selected_languages")
        dataStore.edit { preferences ->
            preferences[selectedLanguageKey] = "xx-YY"
            preferences[primaryLanguageKey] = "zz-ZZ"
            preferences[selectedLanguagesKey] = "aa-AA,bb-BB"
        }

        val language = repository.selectedLanguage.first()
        assertTrue(language in SUPPORTED_LANGUAGE_CODES)
    }

    @Test
    fun setLanguage_clearsLegacyMultiLanguageKeys() = runTest(testDispatcher) {
        val primaryLanguageKey = stringPreferencesKey("primary_language")
        val selectedLanguagesKey = stringPreferencesKey("selected_languages")
        dataStore.edit { preferences ->
            preferences[primaryLanguageKey] = "fr-FR"
            preferences[selectedLanguagesKey] = "fr-FR,de-DE"
        }

        repository.setLanguage("en-US")

        val rawPreferences = dataStore.data.first()
        assertEquals("en-US", rawPreferences[stringPreferencesKey("selected_language")])
        assertFalse(rawPreferences.contains(primaryLanguageKey))
        assertFalse(rawPreferences.contains(selectedLanguagesKey))
    }

    @Test
    fun hasEverRecorded_defaultsFalse_onFreshStore() = runTest(testDispatcher) {
        assertFalse(repository.hasEverRecorded.first())
    }

    @Test
    fun setHasEverRecorded_true_persists() = runTest(testDispatcher) {
        repository.setHasEverRecorded(true)
        assertTrue(repository.hasEverRecorded.first())
    }

    @Test
    fun setHasEverRecorded_false_persists() = runTest(testDispatcher) {
        repository.setHasEverRecorded(true)
        repository.setHasEverRecorded(false)
        assertFalse(repository.hasEverRecorded.first())
    }

    @Test
    fun privacyMode_defaultsToModeBest_onFreshStore() = runTest(testDispatcher) {
        assertEquals(PrivacyMode.MODE_BEST, repository.privacyMode.first())
    }

    @Test
    fun savePrivacyMode_modeOffline_persists() = runTest(testDispatcher) {
        repository.savePrivacyMode(PrivacyMode.MODE_OFFLINE)
        assertEquals(PrivacyMode.MODE_OFFLINE, repository.privacyMode.first())
    }

    @Test
    fun savePrivacyMode_roundTrip_modeBestAfterPrivate() = runTest(testDispatcher) {
        repository.savePrivacyMode(PrivacyMode.MODE_OFFLINE)
        repository.savePrivacyMode(PrivacyMode.MODE_BEST)
        assertEquals(PrivacyMode.MODE_BEST, repository.privacyMode.first())
    }

    @Test
    fun seedPrivacyModeOnce_setsValue_whenKeyAbsent() = runTest(testDispatcher) {
        repository.seedPrivacyModeOnce(PrivacyMode.MODE_OFFLINE)
        assertEquals(PrivacyMode.MODE_OFFLINE, repository.privacyMode.first())
    }

    @Test
    fun seedPrivacyModeOnce_doesNotOverwrite_existingValue() = runTest(testDispatcher) {
        repository.savePrivacyMode(PrivacyMode.MODE_BEST)
        repository.seedPrivacyModeOnce(PrivacyMode.MODE_OFFLINE)
        assertEquals(PrivacyMode.MODE_BEST, repository.privacyMode.first())
    }

    @Test
    fun seedPrivacyModeOnce_isIdempotent_firstCallWins() = runTest(testDispatcher) {
        repository.seedPrivacyModeOnce(PrivacyMode.MODE_OFFLINE)
        repository.seedPrivacyModeOnce(PrivacyMode.MODE_BEST)
        repository.seedPrivacyModeOnce(PrivacyMode.MODE_OFFLINE)
        assertEquals(PrivacyMode.MODE_OFFLINE, repository.privacyMode.first())
    }

    @Test
    fun seedPrivacyModeOnce_removesLegacyTranscriptionBackendKey() = runTest(testDispatcher) {
        val legacyKey = stringPreferencesKey("transcription_backend")
        dataStore.edit { preferences ->
            preferences[legacyKey] = "DIRECT"
        }

        repository.seedPrivacyModeOnce(PrivacyMode.MODE_BEST)

        val rawPreferences = dataStore.data.first()
        assertFalse(rawPreferences.contains(legacyKey))
    }
}
