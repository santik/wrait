package com.wrait.app

import androidx.lifecycle.viewModelScope
import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.wrait.app.analytics.AnalyticsDraftType
import com.wrait.app.analytics.AnalyticsErrorType
import com.wrait.app.analytics.AnalyticsRetryFailureStage
import com.wrait.app.data.EntryDao
import com.wrait.app.data.EntryEntity
import com.wrait.app.data.WraitDatabase
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.device.NetworkAvailability
import com.wrait.app.data.device.DeviceIdProvider
import com.wrait.app.test.fake.FakeAnalyticsTracker
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.usecase.CleanupTranscriptUseCase
import com.wrait.app.data.repository.EntryRepositoryImpl
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.data.speech.TranscriptionFailureReason
import com.wrait.app.domain.usecase.RegisterDeviceUseCase
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.test.fake.FakeDeviceRegistrationService
import com.wrait.app.test.fake.FakeTranscriptCleanupService
import com.wrait.app.test.fake.FakePreferencesRepository
import com.wrait.app.test.fake.FakeNetworkAvailability
import com.wrait.app.test.fake.FakeTranscriptionService
import com.wrait.app.test.util.FakeTimeProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.launch
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
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
@OptIn(ExperimentalCoroutinesApi::class)
class MainViewModelTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    private lateinit var db: WraitDatabase
    private lateinit var entryDao: EntryDao
    private lateinit var entryRepository: EntryRepository
    private lateinit var fakeApi: FakeTranscriptCleanupService
    private lateinit var fakeTranscription: FakeTranscriptionService
    private lateinit var fakeNetworkAvailability: FakeNetworkAvailability
    private lateinit var fakeTime: FakeTimeProvider
    private lateinit var fakeAnalytics: FakeAnalyticsTracker
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
        fakeNetworkAvailability = FakeNetworkAvailability()
        fakeAnalytics = FakeAnalyticsTracker()
    }

    @After
    fun tearDown() {
        runBlocking {
            createdVms.forEach { vm ->
                vm.viewModelScope.coroutineContext[Job]?.cancelAndJoin()
            }
        }
        createdVms.clear()
        Dispatchers.resetMain()
        db.close()
    }

    private fun createViewModel(
        fakePrefs: FakePreferencesRepository = FakePreferencesRepository(),
        fakeRegistration: FakeDeviceRegistrationService = FakeDeviceRegistrationService(),
        networkAvailability: NetworkAvailability = fakeNetworkAvailability,
        entryRepo: EntryRepository = entryRepository,
        analytics: FakeAnalyticsTracker = fakeAnalytics,
    ): MainViewModel {
        val deviceIdProvider = DeviceIdProvider(
            InstrumentationRegistry.getInstrumentation().targetContext
        )
        return MainViewModel(
            preferencesRepository = fakePrefs,
            entryRepository = entryRepo,
            transcriptionService = fakeTranscription,
            networkAvailability = networkAvailability,
            cleanupTranscriptUseCase = CleanupTranscriptUseCase(
                transcriptCleanupService = fakeApi,
            ),
            registerDeviceUseCase = RegisterDeviceUseCase(
                preferencesRepository = fakePrefs,
                deviceIdProvider = deviceIdProvider,
                registrationService = fakeRegistration,
                ioDispatcher = testDispatcher,
            ),
            analyticsTracker = analytics,
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

    @Test
    fun init_tracksAppOpened() = runTest(testDispatcher) {
        val vm = createViewModel()

        vm.initJob.join()

        assertTrue(fakeAnalytics.events.any { it is FakeAnalyticsTracker.Event.AppOpened })
    }

    @Test
    fun permissionRequested_tracksEvent() = runTest(testDispatcher) {
        val vm = createViewModel()
        vm.initJob.join()

        vm.onMicrophonePermissionRequested()

        assertTrue(
            fakeAnalytics.events.any { it is FakeAnalyticsTracker.Event.MicrophonePermissionRequested }
        )
    }

    @Test
    fun permissionDenied_tracksEvent() = runTest(testDispatcher) {
        val vm = createViewModel()
        vm.initJob.join()

        vm.onMicrophonePermissionResult(granted = false, permanentlyDenied = false)

        assertTrue(
            fakeAnalytics.events.any { it is FakeAnalyticsTracker.Event.MicrophonePermissionDenied }
        )
        assertFalse(
            fakeAnalytics.events.any {
                it is FakeAnalyticsTracker.Event.MicrophonePermissionPermanentlyDenied
            }
        )
    }

    @Test
    fun permissionPermanentlyDenied_tracksEvent() = runTest(testDispatcher) {
        val vm = createViewModel()
        vm.initJob.join()

        vm.onMicrophonePermissionResult(granted = false, permanentlyDenied = true)

        assertTrue(
            fakeAnalytics.events.any {
                it is FakeAnalyticsTracker.Event.MicrophonePermissionPermanentlyDenied
            }
        )
        assertFalse(
            fakeAnalytics.events.any { it is FakeAnalyticsTracker.Event.MicrophonePermissionDenied }
        )
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

    @Test
    fun retrySuccess_tracksTranscriptionCleanupAndEntrySaved() = runTest(testDispatcher) {
        fakeTime.time = System.currentTimeMillis()
        entryDao.insert(
            EntryEntity(
                rawTranscript = "",
                cleanedText = null,
                isDraft = true,
                language = "en-US",
                createdAt = fakeTime.currentTimeMillis(),
                wordCount = 0,
                audioPath = "/tmp/audio-draft.m4a",
            )
        )
        fakeTranscription.nextAudioDraftResult =
            com.wrait.app.data.speech.TranscriptionResult.Success(
                transcript = "alpha beta gamma delta epsilon",
                detectedLanguage = "en",
            )
        fakeApi.result = CleanupResult.Success("cleaned on retry")

        val vm = createViewModel()
        vm.initJob.join()

        assertTrue(fakeAnalytics.events.any { it is FakeAnalyticsTracker.Event.TranscriptionSucceeded })
        assertTrue(fakeAnalytics.events.any { it is FakeAnalyticsTracker.Event.CleanupSucceeded })
        assertTrue(fakeAnalytics.events.any { it is FakeAnalyticsTracker.Event.EntrySaved })
        assertTrue(
            fakeAnalytics.events.any {
                it is FakeAnalyticsTracker.Event.DraftRetryStarted &&
                    it.draftType == AnalyticsDraftType.Audio
            }
        )
        assertTrue(
            fakeAnalytics.events.any {
                it is FakeAnalyticsTracker.Event.DraftRetrySucceeded &&
                    it.draftType == AnalyticsDraftType.Audio
            }
        )
    }

    @Test
    fun retryCleanupFailure_tracksDraftRetryFailure() = runTest(testDispatcher) {
        fakeTime.time = System.currentTimeMillis()
        entryDao.insert(
            EntryEntity(
                rawTranscript = "alpha beta gamma",
                cleanedText = null,
                isDraft = true,
                language = "en-US",
                createdAt = fakeTime.currentTimeMillis(),
                wordCount = 3,
            )
        )
        fakeApi.result = CleanupResult.Failure("network error")

        val vm = createViewModel()
        vm.initJob.join()

        assertTrue(
            fakeAnalytics.events.any {
                it is FakeAnalyticsTracker.Event.DraftRetryStarted &&
                    it.draftType == AnalyticsDraftType.Text
            }
        )
        assertTrue(
            fakeAnalytics.events.any {
                it is FakeAnalyticsTracker.Event.DraftRetryFailed &&
                    it.draftType == AnalyticsDraftType.Text &&
                    it.failureStage == AnalyticsRetryFailureStage.Cleanup &&
                    it.errorType == AnalyticsErrorType.Network
            }
        )
    }

    @Test
    fun retryTranscriptionFailure_tracksDraftRetryFailure() = runTest(testDispatcher) {
        fakeTime.time = System.currentTimeMillis()
        entryDao.insert(
            EntryEntity(
                rawTranscript = "",
                cleanedText = null,
                isDraft = true,
                language = "en-US",
                createdAt = fakeTime.currentTimeMillis(),
                wordCount = 0,
                audioPath = "/tmp/audio-draft.m4a",
            )
        )
        fakeTranscription.nextAudioDraftResult =
            com.wrait.app.data.speech.TranscriptionResult.Failure(
                reason = TranscriptionFailureReason.ApiError,
                audioDraftPath = null,
            )

        val vm = createViewModel()
        vm.initJob.join()

        assertTrue(
            fakeAnalytics.events.any {
                it is FakeAnalyticsTracker.Event.DraftRetryFailed &&
                    it.draftType == AnalyticsDraftType.Audio &&
                    it.failureStage == AnalyticsRetryFailureStage.Transcription &&
                    it.errorType == AnalyticsErrorType.ApiFailed
            }
        )
    }

    @Test
    fun analyticsFailure_doesNotBreakInit() = runTest(testDispatcher) {
        val vm = createViewModel(analytics = FakeAnalyticsTracker(shouldThrow = true))

        vm.initJob.join()

        assertTrue(vm.privacyMode.first() == PrivacyMode.MODE_BEST || vm.privacyMode.first() == PrivacyMode.MODE_OFFLINE)
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
    fun audioDraftRetry_detectedLanguage_overridesStoredLanguage() = runTest(testDispatcher) {
        fakeTime.time = System.currentTimeMillis()

        entryDao.insert(
            EntryEntity(
                rawTranscript = "",
                cleanedText = null,
                isDraft = true,
                language = "en-US",
                createdAt = fakeTime.currentTimeMillis(),
                wordCount = 0,
                audioPath = "/fake/audio/path.m4a",
            ),
        )

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
        assertEquals("Language should follow detection", "en", entries.first().language)
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
    fun entryStats_usesSingleUpstreamEntriesCollection() = runTest(testDispatcher) {
        val countingRepository = CountingEntryRepository()
        val vm = createViewModel(
            fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_OFFLINE),
            entryRepo = countingRepository,
        )
        vm.initJob.join()
        advanceUntilIdle()

        assertEquals(1, countingRepository.collectionCount)

        val statsCollector = backgroundScope.launch(testDispatcher) {
            vm.entryStats.collect { }
        }
        advanceUntilIdle()

        assertEquals(2, countingRepository.collectionCount)

        vm.entryStats.first()
        advanceUntilIdle()

        assertEquals(2, countingRepository.collectionCount)
        statsCollector.cancel()
    }

    @Test
    fun statsUpdate_reactsAfterStartup() = runTest(testDispatcher) {
        val vm = createViewModel()
        vm.initJob.join()
        advanceUntilIdle()

        assertEquals(0, vm.entryStats.first().entryCount)
        assertEquals(0, vm.entryStats.first().activeDays)

        val day1 = 1_700_000_000_000L
        val day2 = day1 + TimeUnit.HOURS.toMillis(26)
        listOf(day1, day2).forEach { ts ->
            entryDao.insert(
                EntryEntity(
                    rawTranscript = "word one two three four",
                    cleanedText = "cleaned",
                    isDraft = false,
                    language = "en-US",
                    createdAt = ts,
                    wordCount = 5,
                ),
            )
        }
        advanceUntilIdle()

        val stats = vm.entryStats.first { it.entryCount == 2 }
        assertEquals(2, stats.entryCount)
        assertEquals(2, stats.activeDays)
    }

    @Test
    fun setLanguage_updatesSelectedLanguage() = runTest(testDispatcher) {
        val fakePrefs = FakePreferencesRepository(initialLanguage = "en-US")
        val vm = createViewModel(fakePrefs = fakePrefs)
        vm.initJob.join()

        vm.setLanguage("fr-FR")
        advanceUntilIdle()

        assertEquals("fr-FR", vm.selectedLanguage.first { it == "fr-FR" })
    }

    @Test
    fun setLanguage_overwritesPreviousSelection() = runTest(testDispatcher) {
        val fakePrefs = FakePreferencesRepository(initialLanguage = "en-US")
        val vm = createViewModel(fakePrefs = fakePrefs)
        vm.initJob.join()

        vm.setLanguage("fr-FR")
        vm.setLanguage("de-DE")
        advanceUntilIdle()

        assertEquals("de-DE", vm.selectedLanguage.first { it == "de-DE" })
    }

    @Test
    fun selectedLanguage_defaultsToInitialRepositoryValue() = runTest(testDispatcher) {
        val fakePrefs = FakePreferencesRepository(initialLanguage = "en-US")
        val vm = createViewModel(fakePrefs = fakePrefs)
        vm.initJob.join()

        assertEquals("en-US", vm.selectedLanguage.first())
    }

    @Test
    fun onOpenSettings_doesNothingWhileRecordingIsActive() = runTest(testDispatcher) {
        fakeTranscription.transcribeGate = CompletableDeferred()
        val vm = createViewModel()
        vm.initJob.join()

        vm.onMainButtonTapped()
        vm.recordingState.first { it is RecordingState.Listening }

        vm.onOpenSettings()

        assertFalse(vm.showSettingsPanel.first())
        fakeTranscription.transcribeGate?.complete(Unit)
    }

    private class CountingEntryRepository(
        initialEntries: List<Entry> = emptyList(),
    ) : EntryRepository {
        private val entries = MutableStateFlow(initialEntries)
        var collectionCount: Int = 0
            private set

        override suspend fun saveDraft(transcript: String, language: String): Long = 0L

        override suspend fun saveEntry(transcript: String, language: String): Long = 0L

        override suspend fun saveAudioDraft(audioPath: String, language: String): Long = 0L

        override suspend fun updateWithCleanedText(id: Long, text: String, wordCount: Int) = Unit

        override suspend fun updateDraftTranscript(id: Long, rawTranscript: String, wordCount: Int) = Unit

        override suspend fun finalizeDraftWithCleanedText(
            id: Long,
            rawTranscript: String,
            cleanedText: String,
            wordCount: Int,
        ) = Unit

        override suspend fun updateEntryLanguage(id: Long, language: String) = Unit

        override fun getAllEntries(): Flow<List<Entry>> = entries.onStart {
            collectionCount += 1
        }

        override fun getEntryById(id: Long): Flow<Result<Entry?>> = flowOf(Result.success(null))

        override suspend fun getEntryByIdOnce(id: Long): Result<Entry?> = Result.success(
            entries.value.firstOrNull { it.id == id }
        )

        override suspend fun getPendingDrafts(): List<Entry> = emptyList()

        override suspend fun deleteStaleDrafts(daysOld: Int) = Unit

        override suspend fun deleteStaleDrafts() = Unit

        override suspend fun deleteEntries(ids: List<Long>) = Unit
    }
}
