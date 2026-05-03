package com.wrait.app

import androidx.lifecycle.viewModelScope
import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.wrait.app.data.EntryDao
import com.wrait.app.data.EntryEntity
import com.wrait.app.data.WraitDatabase
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.device.DeviceIdProvider
import com.wrait.app.domain.usecase.CleanupTranscriptUseCase
import com.wrait.app.data.repository.EntryRepositoryImpl
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.domain.usecase.RegisterDeviceUseCase
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.test.fake.FakeDeviceRegistrationService
import com.wrait.app.test.fake.FakeTranscriptCleanupService
import com.wrait.app.test.fake.FakePreferencesRepository
import com.wrait.app.test.fake.FakeTranscriptionService
import com.wrait.app.test.util.FakeTimeProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class MainViewModelTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    private lateinit var db: WraitDatabase
    private lateinit var entryDao: EntryDao
    private lateinit var entryRepository: EntryRepository
    private lateinit var fakeApi: FakeTranscriptCleanupService
    private lateinit var fakeTranscription: FakeTranscriptionService
    private lateinit var fakeTime: FakeTimeProvider
    private val createdVms = mutableListOf<MainViewModel>()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        db = Room.inMemoryDatabaseBuilder(context, WraitDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        entryDao = db.entryDao()
        fakeTime = FakeTimeProvider()
        entryRepository = EntryRepositoryImpl(entryDao, fakeTime)
        fakeApi = FakeTranscriptCleanupService()
        fakeTranscription = FakeTranscriptionService()
    }

    @After
    fun tearDown() {
        createdVms.forEach { it.viewModelScope.cancel() }
        createdVms.clear()
        Dispatchers.resetMain()
        db.close()
    }

    private fun createViewModel(
        fakePrefs: FakePreferencesRepository = FakePreferencesRepository(),
        fakeRegistration: FakeDeviceRegistrationService = FakeDeviceRegistrationService(),
    ): MainViewModel {
        val deviceIdProvider = DeviceIdProvider(
            InstrumentationRegistry.getInstrumentation().targetContext
        )
        return MainViewModel(
            preferencesRepository = fakePrefs,
            entryRepository = entryRepository,
            transcriptionService = fakeTranscription,
            cleanupTranscriptUseCase = CleanupTranscriptUseCase(
                transcriptCleanupService = fakeApi,
            ),
            registerDeviceUseCase = RegisterDeviceUseCase(
                preferencesRepository = fakePrefs,
                deviceIdProvider = deviceIdProvider,
                registrationService = fakeRegistration,
                ioDispatcher = testDispatcher,
            ),
            ioDispatcher = testDispatcher
        ).also { createdVms.add(it) }
    }

    // 1 — Happy path
    @Test
    fun happyPath_transcriptSaved_withCleanedText() = runTest(testDispatcher) {
        fakeApi.result = CleanupResult.Success("This is cleaned text.")
        fakeTranscription.nextResult = FakeTranscriptionService.FakeResult.FinalTranscript(
            "one two three four five"
        )
        val vm = createViewModel()
        vm.initJob.join()

        vm.onMainButtonTapped()
        // recordingState reaches Saved only after both saveDraft + updateWithCleanedText complete
        vm.recordingState.first { it is RecordingState.Saved || it is RecordingState.Error }

        val entries = entryRepository.getAllEntries().first()
        assertEquals(1, entries.size)
        val entry = entries.first()
        assertFalse(entry.isDraft)
        assertNotNull(entry.cleanedText)
        assertTrue(entry.wordCount > 0)
    }

    // 2 — API failure path
    @Test
    fun apiFailure_entryRemainsAsDraft_uiStateShowsError() = runTest(testDispatcher) {
        fakeApi.result = CleanupResult.Failure("network error")
        fakeTranscription.nextResult = FakeTranscriptionService.FakeResult.FinalTranscript(
            "one two three four five"
        )
        val vm = createViewModel()
        vm.initJob.join()

        vm.onMainButtonTapped()
        vm.recordingState.first { it is RecordingState.Saved || it is RecordingState.Error }

        val drafts = entryDao.getPendingDrafts()
        assertEquals(1, drafts.size)
        assertTrue(drafts.first().isDraft)
        assertNull(drafts.first().cleanedText)
    }

    // 3 — Draft retry on init
    @Test
    fun draftRetry_onInit_upgradesDraftToEntry() = runTest(testDispatcher) {
        fakeTime.time = System.currentTimeMillis()
        entryDao.insert(
            EntryEntity(
                rawTranscript = "alpha beta gamma delta epsilon zeta",
                cleanedText = null,
                isDraft = true,
                language = "en-US",
                createdAt = fakeTime.currentTimeMillis(),
                wordCount = 6
            )
        )
        fakeApi.result = CleanupResult.Success("cleaned on retry")

        val vm = createViewModel()
        vm.initJob.join() // suspends until deleteStaleDrafts + retryPendingDrafts complete

        val entries = entryRepository.getAllEntries().first()
        assertEquals(1, entries.size)
        assertFalse("Entry should no longer be a draft", entries.first().isDraft)
        assertEquals("cleaned on retry", entries.first().cleanedText)
    }

    // 4 — Too-short transcript
    @Test
    fun tooShortTranscript_noDbWrite_uiStateError() = runTest(testDispatcher) {
        fakeTranscription.nextResult = FakeTranscriptionService.FakeResult.SpeechError(
            RecognizerError.TooShort
        )
        val vm = createViewModel()
        vm.initJob.join()

        vm.onMainButtonTapped()
        vm.recordingState.first { it is RecordingState.Error }

        val entries = entryRepository.getAllEntries().first()
        assertTrue("No entry should be saved for too-short transcript", entries.isEmpty())
    }

    // 5 — Draft expiry
    @Test
    fun staleDraft_deletedOnInit_notRetried() = runTest(testDispatcher) {
        val now = System.currentTimeMillis()
        fakeTime.time = now
        entryDao.insert(
            EntryEntity(
                rawTranscript = "stale old transcript here forever",
                cleanedText = null,
                isDraft = true,
                language = "en-US",
                createdAt = now - TimeUnit.DAYS.toMillis(8),
                wordCount = 5
            )
        )

        val vm = createViewModel()
        vm.initJob.join() // suspends until deleteStaleDrafts completes

        val drafts = entryDao.getPendingDrafts()
        assertTrue("Stale draft should have been deleted", drafts.isEmpty())
        assertTrue("No entries should remain", entryRepository.getAllEntries().first().isEmpty())
    }

    // 7 — Audio draft retry with language mismatch
    @Test
    fun audioDraftRetry_languageMismatch_retagsEntry() = runTest(testDispatcher) {
        fakeTime.time = System.currentTimeMillis()
        
        // Insert an audio draft with English language (will mismatch with detected French)
        entryDao.insert(
            EntryEntity(
                rawTranscript = "",
                cleanedText = null,
                isDraft = true,
                language = "en-US",
                createdAt = fakeTime.currentTimeMillis(),
                wordCount = 0,
                audioPath = "/fake/audio/path.m4a"
            )
        )

        // Retry transcription detects French
        fakeTranscription.nextAudioDraftResult =
            com.wrait.app.data.speech.TranscriptionResult.Success(
                transcript = "Bonjour le monde",
                detectedLanguage = "fr",
            )
        fakeApi.result = CleanupResult.Success("Bonjour le monde.")

        val vm = createViewModel()
        vm.initJob.join()

        val entries = entryRepository.getAllEntries().first()
        assertEquals(1, entries.size)
        assertEquals("Entry should be re-tagged with detected language", "fr", entries.first().language)
        assertFalse("Entry should be finalized after retry", entries.first().isDraft)
    }

    @Test
    fun audioDraftRetry_noLanguageMismatch_keepsOriginalLanguage() = runTest(testDispatcher) {
        fakeTime.time = System.currentTimeMillis()
        
        // Insert an audio draft with English language (no mismatch with detected English)
        entryDao.insert(
            EntryEntity(
                rawTranscript = "",
                cleanedText = null,
                isDraft = true,
                language = "en-US",
                createdAt = fakeTime.currentTimeMillis(),
                wordCount = 0,
                audioPath = "/fake/audio/path.m4a"
            )
        )
        
        // Same base language — no mismatch
        fakeTranscription.nextAudioDraftResult =
            com.wrait.app.data.speech.TranscriptionResult.Success(
                transcript = "Hello world",
                detectedLanguage = "en",
            )
        fakeApi.result = CleanupResult.Success("Hello world.")

        val vm = createViewModel()
        vm.initJob.join()

        val entries = entryRepository.getAllEntries().first()
        assertEquals(1, entries.size)
        assertEquals("Language should remain as selected", "en-US", entries.first().language)
    }

    // 6 — Stats update
    @Test
    fun statsUpdate_countsEntriesAndActiveDays() = runTest(testDispatcher) {
        val day1 = 1_700_000_000_000L
        val day2 = day1 + TimeUnit.HOURS.toMillis(25)
        listOf(day1, day1 + TimeUnit.MINUTES.toMillis(30), day2).forEach { ts ->
            entryDao.insert(
                EntryEntity(
                    rawTranscript = "word one two three four",
                    cleanedText = "cleaned",
                    isDraft = false,
                    language = "en-US",
                    createdAt = ts,
                    wordCount = 5
                )
            )
        }

        val vm = createViewModel()
        vm.initJob.join()
        advanceUntilIdle()

        val stats = vm.entryStats.first { it.entryCount > 0 }
        assertEquals(3, stats.entryCount)
        assertEquals(2, stats.activeDays)
    }

    @Test
    fun toggleLanguage_addsSecondLanguageWithoutChangingPrimary() = runTest(testDispatcher) {
        val fakePrefs = FakePreferencesRepository(initialLanguage = "en-US")
        val vm = createViewModel(fakePrefs = fakePrefs)
        vm.initJob.join()

        vm.toggleLanguage("fr-FR")
        advanceUntilIdle()

        val languagePreferences = vm.languagePreferences.first {
            it.selectedLanguages == listOf("en-US", "fr-FR")
        }
        assertEquals(listOf("en-US", "fr-FR"), languagePreferences.selectedLanguages)
        assertEquals("en-US", languagePreferences.primaryLanguage)
    }

    @Test
    fun setPrimaryLanguage_selectsAndPromotesLanguage() = runTest(testDispatcher) {
        val fakePrefs = FakePreferencesRepository(
            initialLanguage = "en-US",
            initialSelectedLanguages = listOf("en-US", "de-DE"),
        )
        val vm = createViewModel(fakePrefs = fakePrefs)
        vm.initJob.join()

        vm.setPrimaryLanguage("fr-FR")
        advanceUntilIdle()

        val languagePreferences = vm.languagePreferences.first {
            it.primaryLanguage == "fr-FR" && "fr-FR" in it.selectedLanguages
        }
        assertEquals("fr-FR", languagePreferences.primaryLanguage)
        assertTrue(languagePreferences.selectedLanguages.containsAll(listOf("en-US", "de-DE", "fr-FR")))
    }

    @Test
    fun toggleLanguage_doesNotRemoveLastSelectedLanguage() = runTest(testDispatcher) {
        val fakePrefs = FakePreferencesRepository(initialLanguage = "en-US")
        val vm = createViewModel(fakePrefs = fakePrefs)
        vm.initJob.join()

        vm.toggleLanguage("en-US")
        advanceUntilIdle()

        val languagePreferences = vm.languagePreferences.first()
        assertEquals(listOf("en-US"), languagePreferences.selectedLanguages)
        assertEquals("en-US", languagePreferences.primaryLanguage)
    }
}
