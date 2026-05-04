package com.wrait.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.test.fake.FakePreferencesRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class PrimaryRecordingFlowTest {

    private lateinit var fakePrefs: FakePreferencesRepository
    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        fakePrefs = FakePreferencesRepository(
            initialPrivacyMode = PrivacyMode.MODE_BEST,
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun selectLanguage_savesPreference() = runTest(testDispatcher) {
        fakePrefs.setLanguage("es-ES")

        val savedLanguage = fakePrefs.selectedLanguage.first()
        assertEquals("Spanish should be saved", "es-ES", savedLanguage)
    }

    @Test
    fun language_canBeChangedMultipleTimes() = runTest(testDispatcher) {
        fakePrefs.setLanguage("es-ES")
        fakePrefs.setLanguage("fr-FR")
        fakePrefs.setLanguage("de-DE")

        val finalLanguage = fakePrefs.selectedLanguage.first()
        assertEquals("Final language should be German", "de-DE", finalLanguage)
    }

    @Test
    fun selectedLanguage_isExposedAsFlow() = runTest(testDispatcher) {
        val language = fakePrefs.selectedLanguage.first()
        assertEquals("Default language should be en-US", "en-US", language)
    }

    @Test
    fun togglePrivacyMode_updatesPreference() = runTest(testDispatcher) {
        fakePrefs.savePrivacyMode(PrivacyMode.MODE_OFFLINE)
        assertEquals(PrivacyMode.MODE_OFFLINE, fakePrefs.privacyMode.first())

        fakePrefs.savePrivacyMode(PrivacyMode.MODE_BEST)
        assertEquals(PrivacyMode.MODE_BEST, fakePrefs.privacyMode.first())
    }

    @Test
    fun privacyMode_isExposedAsFlow() = runTest(testDispatcher) {
        assertEquals(PrivacyMode.MODE_BEST, fakePrefs.privacyMode.first())
    }

    @Test
    fun hasEverRecorded_canBeSet() = runTest(testDispatcher) {
        fakePrefs.setHasEverRecorded(true)
        assertTrue(fakePrefs.hasEverRecorded.first())

        fakePrefs.setHasEverRecorded(false)
        assertFalse(fakePrefs.hasEverRecorded.first())
    }

    @Test
    fun hasEverRecorded_initiallyFalse() = runTest(testDispatcher) {
        assertFalse(fakePrefs.hasEverRecorded.first())
    }

    @Test
    fun seedPrivacyMode_onlyWorksOnce() = runTest(testDispatcher) {
        fakePrefs.seedPrivacyModeOnce(PrivacyMode.MODE_OFFLINE)
        fakePrefs.seedPrivacyModeOnce(PrivacyMode.MODE_BEST)

        val mode = fakePrefs.privacyMode.first()
        assertEquals("Should remain Offline from first seed", PrivacyMode.MODE_OFFLINE, mode)
    }
}
