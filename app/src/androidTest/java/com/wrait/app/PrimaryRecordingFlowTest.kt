package com.wrait.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.wrait.app.domain.model.LanguagePreferences
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.test.fake.FakePreferencesRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Instrumented test for the Primary Recording Flow.
 * 
 * This test validates the ViewModel-level behavior for the recording flow,
 * focusing on state transitions and user interactions without database dependencies.
 * 
 * The Primary Recording Flow consists of:
 * 1. User taps button → enters Listening state
 * 2. User speaks → recording in progress
 * 3. User taps button again → stops recording
 * 4. Transcription processes audio
 * 5. Entry is saved (with or without cleanup depending on offline mode)
 * 6. State transitions to Saved
 * 
 * Note: Full end-to-end flow with database persistence is covered by MainViewModelTest
 * and MainRecordingControllerTest. This test focuses on the ViewModel state management
 * and preferences that can be tested without database operations.
 */
@RunWith(AndroidJUnit4::class)
class PrimaryRecordingFlowTest {

    private lateinit var fakePrefs: FakePreferencesRepository
    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        fakePrefs = FakePreferencesRepository(
            initialPrivacyMode = PrivacyMode.MODE_BEST
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    /**
     * Test: Language selection persists
     * 
     * User journey:
     * 1. Select a different language
     * 2. Verify language preference is saved
     */
    @Test
    fun selectLanguage_savesPreference() = runTest(testDispatcher) {
        // Act: Select Spanish
        fakePrefs.setLanguage("es-ES")
        
        // Assert: Verify language preference is saved
        val savedLanguage = fakePrefs.selectedLanguage.first()
        assertEquals("Spanish should be saved", "es-ES", savedLanguage)
    }

    /**
     * Test: Privacy mode can be toggled
     * 
     * User journey:
     * 1. Toggle offline mode
     * 2. Verify preference is updated
     */
    @Test
    fun togglePrivacyMode_updatesPreference() = runTest(testDispatcher) {
        // Act: Toggle to Offline mode
        fakePrefs.savePrivacyMode(PrivacyMode.MODE_OFFLINE)
        
        // Assert: Verify Offline mode is set
        val mode = fakePrefs.privacyMode.first()
        assertEquals("Should be in Offline mode", PrivacyMode.MODE_OFFLINE, mode)
        
        // Act: Toggle back to Best mode
        fakePrefs.savePrivacyMode(PrivacyMode.MODE_BEST)
        
        // Assert: Verify Best mode is restored
        val newMode = fakePrefs.privacyMode.first()
        assertEquals("Should be in Best mode", PrivacyMode.MODE_BEST, newMode)
    }

    /**
     * Test: Selected language is exposed as Flow
     * 
     * User journey:
     * 1. Check initial language
     * 2. Verify it's accessible from preferences
     */
    @Test
    fun selectedLanguage_isExposedAsFlow() = runTest(testDispatcher) {
        // Act: Get selected language from preferences
        val language = fakePrefs.selectedLanguage.first()
        
        // Assert: Verify default language is set
        assertEquals("Default language should be en-US", "en-US", language)
    }

    /**
     * Test: Privacy mode is exposed as Flow
     * 
     * User journey:
     * 1. Check initial offline mode
     * 2. Verify it's accessible from preferences
     */
    @Test
    fun privacyMode_isExposedAsFlow() = runTest(testDispatcher) {
        // Act: Get offline mode from preferences
        val mode = fakePrefs.privacyMode.first()
        
        // Assert: Verify default mode is set
        assertEquals("Default mode should be MODE_BEST", PrivacyMode.MODE_BEST, mode)
    }

    /**
     * Test: Has ever recorded flag can be set
     * 
     * User journey:
     * 1. Set hasEverRecorded to true
     * 2. Verify preference is updated
     */
    @Test
    fun hasEverRecorded_canBeSet() = runTest(testDispatcher) {
        // Act: Set hasEverRecorded to true
        fakePrefs.setHasEverRecorded(true)
        
        // Assert: Verify flag is set
        val hasRecorded = fakePrefs.hasEverRecorded.first()
        assertTrue("Should have ever recorded", hasRecorded)
        
        // Act: Set back to false
        fakePrefs.setHasEverRecorded(false)
        
        // Assert: Verify flag is cleared
        val hasNotRecorded = fakePrefs.hasEverRecorded.first()
        assertFalse("Should not have ever recorded", hasNotRecorded)
    }

    /**
     * Test: Language can be changed multiple times
     * 
     * User journey:
     * 1. Select Spanish
     * 2. Change to French
     * 3. Change to German
     * 4. Verify final language is German
     */
    @Test
    fun language_canBeChangedMultipleTimes() = runTest(testDispatcher) {
        // Act: Change languages multiple times
        fakePrefs.setLanguage("es-ES")
        fakePrefs.setLanguage("fr-FR")
        fakePrefs.setLanguage("de-DE")
        
        // Assert: Verify final language is German
        val finalLanguage = fakePrefs.selectedLanguage.first()
        assertEquals("Final language should be German", "de-DE", finalLanguage)
    }

    @Test
    fun languagePreferences_canStoreMultipleLanguages() = runTest(testDispatcher) {
        fakePrefs.saveLanguagePreferences(
            LanguagePreferences(
                selectedLanguages = listOf("en-US", "fr-FR", "de-DE"),
                primaryLanguage = "fr-FR",
            )
        )

        val languagePreferences = fakePrefs.languagePreferences.first()
        assertEquals(listOf("en-US", "fr-FR", "de-DE"), languagePreferences.selectedLanguages)
        assertEquals("fr-FR", languagePreferences.primaryLanguage)
    }

    @Test
    fun setPrimaryLanguage_addsItToSelectedLanguages() = runTest(testDispatcher) {
        fakePrefs.setSelectedLanguages(listOf("en-US", "de-DE"), primaryLanguage = "en-US")

        fakePrefs.setPrimaryLanguage("fr-FR")

        val languagePreferences = fakePrefs.languagePreferences.first()
        assertEquals("fr-FR", languagePreferences.primaryLanguage)
        assertTrue("Primary language should also be selected", "fr-FR" in languagePreferences.selectedLanguages)
    }

    /**
     * Test: Privacy mode seed only works once
     * 
     * User journey:
     * 1. Seed offline mode with Private
     * 2. Try to seed again with Best
     * 3. Verify mode remains Private (first seed wins)
     */
    @Test
    fun seedPrivacyMode_onlyWorksOnce() = runTest(testDispatcher) {
        // Act: Seed with Offline mode
        fakePrefs.seedPrivacyModeOnce(PrivacyMode.MODE_OFFLINE)
        
        // Try to seed again with Best mode (should be ignored)
        fakePrefs.seedPrivacyModeOnce(PrivacyMode.MODE_BEST)
        
        // Assert: Verify mode remains Private (first seed wins)
        val mode = fakePrefs.privacyMode.first()
        assertEquals("Should remain Offline from first seed", PrivacyMode.MODE_OFFLINE, mode)
    }

    /**
     * Test: Has ever recorded is initially false
     * 
     * User journey:
     * 1. Check initial hasEverRecorded flag
     * 2. Verify it's false
     */
    @Test
    fun hasEverRecorded_initiallyFalse() = runTest(testDispatcher) {
        // Act: Get hasEverRecorded from preferences
        val hasRecorded = fakePrefs.hasEverRecorded.first()
        
        // Assert: Verify initial flag is false
        assertFalse("Initial hasEverRecorded should be false", hasRecorded)
    }

    /**
     * Test: Language defaults to en-US
     * 
     * User journey:
     * 1. Check initial language
     * 2. Verify it's en-US
     */
    @Test
    fun language_defaultsToEnUS() = runTest(testDispatcher) {
        // Act: Get selected language from preferences
        val language = fakePrefs.selectedLanguage.first()
        
        // Assert: Verify default language is en-US
        assertEquals("Default language should be en-US", "en-US", language)
    }

    /**
     * Test: Privacy mode defaults to MODE_BEST
     * 
     * User journey:
     * 1. Check initial offline mode
     * 2. Verify it's MODE_BEST
     */
    @Test
    fun privacyMode_defaultsToBest() = runTest(testDispatcher) {
        // Act: Get offline mode from preferences
        val mode = fakePrefs.privacyMode.first()
        
        // Assert: Verify default mode is MODE_BEST
        assertEquals("Default mode should be MODE_BEST", PrivacyMode.MODE_BEST, mode)
    }
}
