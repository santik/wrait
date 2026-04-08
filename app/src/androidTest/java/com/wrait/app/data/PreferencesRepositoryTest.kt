package com.wrait.app.data

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.wrait.app.data.repository.PreferencesRepositoryImpl
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
    private lateinit var repository: PreferencesRepository

    @Before
    fun setUp() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        prefsFile = File(context.filesDir, "test_prefs_${System.nanoTime()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
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
    fun setLanguage_persistsAcrossRead() = runTest(testDispatcher) {
        repository.setLanguage("de-DE")
        val language = repository.selectedLanguage.first()
        assertEquals("de-DE", language)
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
    fun savePrivacyMode_modePrivate_persists() = runTest(testDispatcher) {
        repository.savePrivacyMode(PrivacyMode.MODE_PRIVATE)
        assertEquals(PrivacyMode.MODE_PRIVATE, repository.privacyMode.first())
    }

    @Test
    fun savePrivacyMode_roundTrip_modeBestAfterPrivate() = runTest(testDispatcher) {
        repository.savePrivacyMode(PrivacyMode.MODE_PRIVATE)
        repository.savePrivacyMode(PrivacyMode.MODE_BEST)
        assertEquals(PrivacyMode.MODE_BEST, repository.privacyMode.first())
    }

    @Test
    fun seedPrivacyModeOnce_setsValue_whenKeyAbsent() = runTest(testDispatcher) {
        repository.seedPrivacyModeOnce(PrivacyMode.MODE_PRIVATE)
        assertEquals(PrivacyMode.MODE_PRIVATE, repository.privacyMode.first())
    }

    @Test
    fun seedPrivacyModeOnce_doesNotOverwrite_existingValue() = runTest(testDispatcher) {
        repository.savePrivacyMode(PrivacyMode.MODE_BEST)
        repository.seedPrivacyModeOnce(PrivacyMode.MODE_PRIVATE)
        // Seeding should not override the already-saved MODE_BEST
        assertEquals(PrivacyMode.MODE_BEST, repository.privacyMode.first())
    }

    @Test
    fun seedPrivacyModeOnce_isIdempotent_firstCallWins() = runTest(testDispatcher) {
        repository.seedPrivacyModeOnce(PrivacyMode.MODE_PRIVATE)
        repository.seedPrivacyModeOnce(PrivacyMode.MODE_BEST)
        repository.seedPrivacyModeOnce(PrivacyMode.MODE_PRIVATE)
        // The DataStore-backed impl checks if key is absent, so subsequent calls are no-ops
        // First seeded value (MODE_PRIVATE) should persist
        assertEquals(PrivacyMode.MODE_PRIVATE, repository.privacyMode.first())
    }
}
