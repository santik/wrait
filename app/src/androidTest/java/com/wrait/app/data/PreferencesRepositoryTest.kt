package com.wrait.app.data

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.wrait.app.data.repository.PreferencesRepositoryImpl
import com.wrait.app.domain.model.LanguagePreferences
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.model.SUPPORTED_LANGUAGE_CODES
import com.wrait.app.domain.repository.PreferencesRepository
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

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
            produceFile = { prefsFile }
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
        // On a fresh store with no saved value the repository falls back to the device locale,
        // then validates it against SUPPORTED_LANGUAGE_CODES (returns "en-US" if not supported).
        // We cannot force the device locale in an instrumented test, but we can assert the
        // returned value is always one of the supported codes — never an arbitrary or empty string.
        val language = repository.selectedLanguage.first()
        assertTrue(
            "Default language '$language' must be in SUPPORTED_LANGUAGE_CODES",
            language in SUPPORTED_LANGUAGE_CODES
        )
    }

    @Test
    fun languagePreferences_defaultsToPrimaryWithinSelectedLanguages() = runTest(testDispatcher) {
        val languagePreferences = repository.languagePreferences.first()
        assertTrue(languagePreferences.primaryLanguage in SUPPORTED_LANGUAGE_CODES)
        assertTrue(languagePreferences.selectedLanguages.isNotEmpty())
        assertTrue(languagePreferences.primaryLanguage in languagePreferences.selectedLanguages)
    }

    @Test
    fun setLanguage_persistsAcrossRead() = runTest(testDispatcher) {
        repository.setLanguage("de-DE")
        val language = repository.selectedLanguage.first()
        assertEquals("de-DE", language)
    }

    @Test
    fun saveLanguagePreferences_persistsSelectedLanguagesAndPrimary() = runTest(testDispatcher) {
        repository.saveLanguagePreferences(
            LanguagePreferences(
                selectedLanguages = listOf("en-US", "fr-FR", "de-DE"),
                primaryLanguage = "fr-FR",
            )
        )

        val languagePreferences = repository.languagePreferences.first()
        assertEquals(listOf("en-US", "fr-FR", "de-DE"), languagePreferences.selectedLanguages)
        assertEquals("fr-FR", languagePreferences.primaryLanguage)
        assertEquals("fr-FR", repository.selectedLanguage.first())
    }

    @Test
    fun setLanguage_supportedCodes_allPersistCorrectly() = runTest(testDispatcher) {
        val codes = listOf("en-US", "nl-NL", "ru-RU", "uk-UA", "de-DE", "es-ES",
            "fr-FR", "it-IT", "pl-PL", "pt-PT", "tr-TR")
        for (code in codes) {
            repository.setLanguage(code)
            assertEquals("Language '$code' should persist", code, repository.selectedLanguage.first())
        }
    }

    @Test
    fun legacySelectedLanguage_migratesToLanguagePreferencesOnRead() = runTest(testDispatcher) {
        val legacyKey = stringPreferencesKey("selected_language")
        dataStore.edit { preferences ->
            preferences[legacyKey] = "fr-FR"
        }

        val languagePreferences = repository.languagePreferences.first()
        assertEquals(listOf("fr-FR"), languagePreferences.selectedLanguages)
        assertEquals("fr-FR", languagePreferences.primaryLanguage)
    }

    @Test
    fun invalidStoredLanguagePreferences_fallBackToSupportedDefaults() = runTest(testDispatcher) {
        val selectedLanguagesKey = stringPreferencesKey("selected_languages")
        val primaryLanguageKey = stringPreferencesKey("primary_language")
        dataStore.edit { preferences ->
            preferences[selectedLanguagesKey] = "xx-YY,zz-ZZ"
            preferences[primaryLanguageKey] = "xx-YY"
        }

        val languagePreferences = repository.languagePreferences.first()
        assertTrue(languagePreferences.selectedLanguages.isNotEmpty())
        assertTrue(languagePreferences.primaryLanguage in SUPPORTED_LANGUAGE_CODES)
        assertTrue(languagePreferences.primaryLanguage in languagePreferences.selectedLanguages)
    }

    @Test
    fun hasEverRecorded_defaultsFalse_onFreshStore() = runTest(testDispatcher) {
        val value = repository.hasEverRecorded.first()
        assertFalse("hasEverRecorded should default to false", value)
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
        val mode = repository.privacyMode.first()
        assertEquals(PrivacyMode.MODE_BEST, mode)
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
        // Seeding should not override the already-saved MODE_BEST
        assertEquals(PrivacyMode.MODE_BEST, repository.privacyMode.first())
    }

    @Test
    fun seedPrivacyModeOnce_isIdempotent_firstCallWins() = runTest(testDispatcher) {
        repository.seedPrivacyModeOnce(PrivacyMode.MODE_OFFLINE)
        repository.seedPrivacyModeOnce(PrivacyMode.MODE_BEST)
        repository.seedPrivacyModeOnce(PrivacyMode.MODE_OFFLINE)
        // The DataStore-backed impl checks if key is absent, so subsequent calls are no-ops
        // First seeded value (MODE_OFFLINE) should persist
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
