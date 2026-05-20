package com.wrait.app

import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.wrait.app.data.EntryDao
import com.wrait.app.data.WraitDatabase
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.device.NetworkAvailability
import com.wrait.app.data.repository.EntryRepositoryImpl
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.data.speech.TranscriptionFailureReason
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.usecase.CleanupTranscriptUseCase
import com.wrait.app.test.fake.FakeAnalyticsTracker
import com.wrait.app.test.fake.FakeTranscriptCleanupService
import com.wrait.app.test.fake.FakePreferencesRepository
import com.wrait.app.test.fake.FakeNetworkAvailability
import com.wrait.app.test.fake.FakeTranscriptionService
import com.wrait.app.test.util.FakeTimeProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Ignore
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainRecordingControllerTest {

    private val testDispatcher = UnconfinedTestDispatcher()
    private val testScope = TestScope(testDispatcher)

    private lateinit var db: WraitDatabase
    private lateinit var entryDao: EntryDao
    private lateinit var entryRepository: EntryRepository
    private lateinit var fakeOpenApi: FakeTranscriptCleanupService
    private lateinit var fakeTranscription: FakeTranscriptionService
    private lateinit var fakePrefs: FakePreferencesRepository
    private lateinit var fakeNetworkAvailability: FakeNetworkAvailability
    private lateinit var fakeAnalytics: FakeAnalyticsTracker
    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        db = Room.inMemoryDatabaseBuilder(context, WraitDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        entryDao = db.entryDao()
        entryRepository = EntryRepositoryImpl(entryDao, FakeTimeProvider())
        fakeOpenApi = FakeTranscriptCleanupService()
        fakeTranscription = FakeTranscriptionService()
        fakePrefs = FakePreferencesRepository()
        fakeNetworkAvailability = FakeNetworkAvailability()
        fakeAnalytics = FakeAnalyticsTracker()
    }

    @After
    fun tearDown() {
        testScope.cancel()
        Dispatchers.resetMain()
        db.close()
    }

    private fun buildController(
        prefs: FakePreferencesRepository = fakePrefs,
        api: FakeTranscriptCleanupService = fakeOpenApi,
        transcription: FakeTranscriptionService = fakeTranscription,
        networkAvailability: NetworkAvailability = fakeNetworkAvailability,
        analytics: FakeAnalyticsTracker = fakeAnalytics,
        language: StateFlow<String> = MutableStateFlow(prefs.currentSelectedLanguage()),
        scope: CoroutineScope = testScope,
    ): MainRecordingController = MainRecordingController(
        selectedLanguageState = language,
        entryRepository = entryRepository,
        preferencesRepository = prefs,
        transcriptionService = transcription,
        networkAvailability = networkAvailability,
        cleanupTranscriptUseCase = CleanupTranscriptUseCase(
            transcriptCleanupService = api,
        ),
        analyticsTracker = analytics,
        ioDispatcher = testDispatcher,
        scope = scope,
    )

    @Test
    fun initialState_isIdle() = runTest(testDispatcher) {
        val controller = buildController()
        assertEquals(RecordingState.Idle, controller.recordingState.value)
    }

    @Test
    fun tapFromIdle_transitionsToListening() = runTest(testDispatcher) {
        // Configure transcription to not return immediately so we can observe Listening state
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("hello world test one two")
        fakeTranscription.transcribeGate = CompletableDeferred()
        val controller = buildController()
        try {
            controller.onMainButtonTapped()
            assertEquals(RecordingState.Listening, controller.recordingState.value)
        } finally {
            fakeTranscription.transcribeGate?.complete(Unit)
        }
        advanceUntilIdle()
    }

    @Test
    fun recordingStarted_exposesCountdownWhileListening() = runTest(testDispatcher) {
        fakeTranscription.recordingStartDeadlineElapsedRealtime = 123_456L
        fakeTranscription.transcribeGate = CompletableDeferred()
        val controller = buildController()

        try {
            controller.onMainButtonTapped()

            assertEquals(
                RecordingCountdownState(hardCapDeadlineElapsedRealtime = 123_456L),
                controller.recordingCountdown.value,
            )
        } finally {
            fakeTranscription.transcribeGate?.complete(Unit)
        }
        advanceUntilIdle()
    }

    @Test
    fun manualStop_clearsCountdownImmediately() = runTest(testDispatcher) {
        fakeTranscription.recordingStartDeadlineElapsedRealtime = 123_456L
        fakeTranscription.transcribeGate = CompletableDeferred()
        val controller = buildController()

        try {
            controller.onMainButtonTapped()
            assertNotNull(controller.recordingCountdown.value)

            controller.onMainButtonTapped()

            assertNull(controller.recordingCountdown.value)
        } finally {
            fakeTranscription.transcribeGate?.complete(Unit)
        }
        advanceUntilIdle()
    }

    @Test
    fun permissionRevoked_clearsCountdownImmediately() = runTest(testDispatcher) {
        fakeTranscription.recordingStartDeadlineElapsedRealtime = 123_456L
        fakeTranscription.transcribeGate = CompletableDeferred()
        val controller = buildController()

        try {
            controller.onMainButtonTapped()
            assertNotNull(controller.recordingCountdown.value)

            controller.onPermissionRevoked()

            assertNull(controller.recordingCountdown.value)
            assertEquals(RecordingState.Idle, controller.recordingState.value)
        } finally {
            fakeTranscription.transcribeGate?.complete(Unit)
        }
        advanceUntilIdle()
    }

    @Test
    fun recordingCompletion_clearsCountdown() = runTest(testDispatcher) {
        fakeTranscription.recordingStartDeadlineElapsedRealtime = 123_456L
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("one two three four five")
        val controller = buildController()

        controller.onMainButtonTapped()
        advanceUntilIdle()

        assertNull(controller.recordingCountdown.value)
    }

    @Test
    fun bestMode_offline_emitsImmediateError_withoutStartingRecording() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_BEST)
        fakeNetworkAvailability.isAvailable = false
        val controller = buildController(prefs = fakePrefs)

        controller.onMainButtonTapped()
        advanceUntilIdle()

        val state = controller.recordingState.value
        assertTrue(
            "Offline best mode should show a connection-required error before recording",
            (state is RecordingState.Error && state.error == RecognizerError.ConnectionRequired) ||
                state is RecordingState.Idle,
        )
        assertEquals(
            "Recording should not start when best mode is offline",
            0,
            fakeTranscription.transcribeCallCount,
        )
        assertTrue(
            "No draft or entry should be created when recording never starts",
            entryRepository.getAllEntries().first().isEmpty(),
        )
    }

    @Test
    fun bestMode_online_startsRecording() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_BEST)
        fakeNetworkAvailability.isAvailable = true
        fakeTranscription.transcribeGate = CompletableDeferred()
        val controller = buildController(prefs = fakePrefs)

        try {
            controller.onMainButtonTapped()
            assertEquals(RecordingState.Listening, controller.recordingState.value)
            assertEquals(1, fakeTranscription.transcribeCallCount)
        } finally {
            fakeTranscription.transcribeGate?.complete(Unit)
        }
        advanceUntilIdle()
    }

    @Test
    fun bestMode_online_tracksRecordingStarted() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_BEST)
        fakeTranscription.transcribeGate = CompletableDeferred()
        val controller = buildController(prefs = fakePrefs)

        try {
            controller.onMainButtonTapped()
            assertTrue(
                fakeAnalytics.events.any {
                    it is FakeAnalyticsTracker.Event.RecordingStarted &&
                        it.privacyMode == PrivacyMode.MODE_BEST &&
                        it.selectedLanguage == fakePrefs.currentSelectedLanguage()
                }
            )
        } finally {
            fakeTranscription.transcribeGate?.complete(Unit)
        }
        advanceUntilIdle()
    }

    @Test
    fun cleanupSuccess_tracksTranscriptionCleanupAndEntrySaved() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_BEST)
        fakeOpenApi.result = CleanupResult.Success("Cleaned text")
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("one two three four five")
        val controller = buildController(prefs = fakePrefs)

        controller.onMainButtonTapped()
        controller.recordingState.first { it is RecordingState.Saved }
        advanceUntilIdle()

        assertTrue(fakeAnalytics.events.any { it is FakeAnalyticsTracker.Event.TranscriptionSucceeded })
        assertTrue(fakeAnalytics.events.any { it is FakeAnalyticsTracker.Event.CleanupSucceeded })
        assertTrue(fakeAnalytics.events.any { it is FakeAnalyticsTracker.Event.EntrySaved })
    }

    @Test
    fun cleanupFailure_tracksCleanupFailureWithoutEntrySaved() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_BEST)
        fakeOpenApi.result = CleanupResult.Failure("network error")
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("one two three four five")
        val controller = buildController(prefs = fakePrefs)

        controller.onMainButtonTapped()
        controller.recordingState.first { it is RecordingState.Error }
        advanceUntilIdle()

        assertTrue(fakeAnalytics.events.any { it is FakeAnalyticsTracker.Event.TranscriptionSucceeded })
        assertTrue(
            fakeAnalytics.events.any {
                it is FakeAnalyticsTracker.Event.CleanupFailed && it.reason == "network error"
            }
        )
        assertFalse(fakeAnalytics.events.any { it is FakeAnalyticsTracker.Event.EntrySaved })
    }

    @Test
    fun analyticsFailure_doesNotBreakRecordingFlow() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_BEST)
        fakeOpenApi.result = CleanupResult.Success("Cleaned text")
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("one two three four five")
        val controller = buildController(
            prefs = fakePrefs,
            analytics = FakeAnalyticsTracker(shouldThrow = true),
        )

        controller.onMainButtonTapped()
        controller.recordingState.first { it is RecordingState.Saved }
        advanceTimeBy(3_000)
        advanceUntilIdle()

        assertTrue(
            controller.recordingState.value !is RecordingState.Error,
        )
        assertEquals(1, entryRepository.getAllEntries().first().size)
    }

    @Test
    fun bestMode_retryAfterConnectionRestored_startsRecording() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_BEST)
        fakeNetworkAvailability.isAvailable = false
        val controller = buildController(prefs = fakePrefs)

        controller.onMainButtonTapped()
        advanceUntilIdle()
        assertEquals(0, fakeTranscription.transcribeCallCount)

        fakeNetworkAvailability.isAvailable = true
        fakeTranscription.transcribeGate = CompletableDeferred()

        try {
            controller.onMainButtonTapped()
            assertEquals(RecordingState.Listening, controller.recordingState.value)
            assertEquals(1, fakeTranscription.transcribeCallCount)
        } finally {
            fakeTranscription.transcribeGate?.complete(Unit)
        }
        advanceUntilIdle()
    }

    @Test
    fun offlineMode_skipsConnectivityPreflight() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_OFFLINE)
        fakeNetworkAvailability.reset(isAvailable = false)
        fakeTranscription.transcribeGate = CompletableDeferred()
        val controller = buildController(prefs = fakePrefs)

        try {
            controller.onMainButtonTapped()
            assertEquals(RecordingState.Listening, controller.recordingState.value)
            assertEquals(
                "Offline mode should not consult connectivity before recording",
                0,
                fakeNetworkAvailability.callCount,
            )
            assertEquals(1, fakeTranscription.transcribeCallCount)
        } finally {
            fakeTranscription.transcribeGate?.complete(Unit)
        }
        advanceUntilIdle()
    }

    @Test
    fun bestMode_networkFailureAfterStart_persistsAudioDraft() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_BEST)
        fakeNetworkAvailability.isAvailable = true
        fakeTranscription.nextResult = FakeTranscriptionService.FakeResult.FailureWithAudioDraft(
            reason = TranscriptionFailureReason.NetworkError,
            audioPath = "/tmp/best_mode_network_drop.m4a",
        )
        val controller = buildController(prefs = fakePrefs)

        controller.onMainButtonTapped()
        advanceUntilIdle()

        val entries = entryRepository.getAllEntries().first()
        assertEquals(1, entries.size)
        assertEquals("/tmp/best_mode_network_drop.m4a", entries.first().audioPath)
        assertTrue(entries.first().isDraft)
    }

    @Test
    fun tapFromListening_immediately_emitsTooShort() = runTest(testDispatcher) {
        // Configure fake to return TooShort error (simulates the transcription service
        // detecting elapsed < MIN_RECORDING_MS and emitting TooShort).
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.SpeechError(RecognizerError.TooShort)
        val controller = buildController()
        controller.onMainButtonTapped()
        advanceUntilIdle()

        val state = controller.recordingState.value
        // After UnconfinedTestDispatcher runs the pipeline: Error(TooShort) or Idle (auto-reset fired)
        assertTrue(
            "TooShort should yield Error(TooShort) or Idle after auto-reset, not Saved",
            (state is RecordingState.Error && state.error == RecognizerError.TooShort) ||
            state is RecordingState.Idle
        )
        // TooShort must never persist an entry to the database
        assertTrue(
            "No entry should be saved for TooShort error",
            entryRepository.getAllEntries().first().isEmpty()
        )
    }

    @Test
    @Ignore
    fun tapFromSaved_startsNewRecording() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_OFFLINE)
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("one two three four five")
        val controller = buildController(prefs = fakePrefs)

        // First recording produces a Saved state
        controller.onMainButtonTapped()
        advanceUntilIdle()
        assertTrue(
            "State should be Saved after first recording",
            controller.recordingState.value is RecordingState.Saved
        )

        // Configure a second recording result
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("second recording six seven eight nine ten")

        // Tap the main button while Saved — should start a new recording
        controller.onMainButtonTapped()
        advanceUntilIdle()

        val entries = entryRepository.getAllEntries().first()
        assertEquals(
            "Two recordings should have produced two entries",
            2, entries.size
        )
    }

    @Test
    @Ignore
    fun resetToIdle_fromSaved_doesNotStartRecording() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_OFFLINE)
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("one two three four five")
        val controller = buildController(prefs = fakePrefs)

        // First recording produces a Saved state
        controller.onMainButtonTapped()
        advanceUntilIdle()
        assertTrue(
            "State should be Saved after recording",
            controller.recordingState.value is RecordingState.Saved
        )

        // resetToIdle should go to Idle without starting a new recording
        controller.resetToIdle()
        advanceUntilIdle()

        assertEquals(
            "State should be Idle after resetToIdle",
            RecordingState.Idle, controller.recordingState.value
        )
        val entries = entryRepository.getAllEntries().first()
        assertEquals(
            "Only one entry should exist (no new recording started)",
            1, entries.size
        )
    }

    @Test
    @Ignore
    fun errorState_autoClearsToIdle() = runTest(testDispatcher) {
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.SpeechError(RecognizerError.NoInternet)
        val controller = buildController()
        controller.onMainButtonTapped()
        advanceUntilIdle()
        assertTrue(
            "State should be Error after failed recording",
            controller.recordingState.value is RecordingState.Error
        )
        // Advance past the 1.5s auto-clear delay
        advanceTimeBy(2_000)
        assertEquals(
            "Error state should auto-clear to Idle",
            RecordingState.Idle, controller.recordingState.value
        )
    }

    @Test
    @Ignore
    fun savedState_autoClearsToIdle() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_OFFLINE)
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("one two three four five")
        val controller = buildController(prefs = fakePrefs)
        controller.onMainButtonTapped()
        advanceUntilIdle()
        assertTrue(
            "State should be Saved after recording",
            controller.recordingState.value is RecordingState.Saved
        )
        // Advance past the 1.5s auto-clear delay
        advanceTimeBy(2_000)
        assertEquals(
            "Saved state should auto-clear to Idle",
            RecordingState.Idle, controller.recordingState.value
        )
    }

    @Test
    fun tapFromError_nonPermission_restartsRecording() = runTest(testDispatcher) {
        // First trigger an error
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.SpeechError(RecognizerError.NoInternet)
        fakeOpenApi.result = CleanupResult.Success("cleaned")
        val controller = buildController()
        controller.onMainButtonTapped()
        advanceUntilIdle()
        // After 1.5s delay pipeline resets to Idle
        advanceTimeBy(2_000)
        // Now configure for success
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("second recording success")
        // The error state triggers re-start on next tap
        controller.onMainButtonTapped()
        advanceUntilIdle()
        val entries = entryRepository.getAllEntries().first()
        assertTrue("Second recording should produce an entry", entries.isNotEmpty())
    }

    @Test
    fun tapFromError_permission_goesToIdle() = runTest(testDispatcher) {
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.SpeechError(RecognizerError.InsufficientPermissions)
        val controller = buildController()
        controller.onMainButtonTapped()
        advanceUntilIdle()
        advanceTimeBy(2_000)
        assertEquals(RecordingState.Idle, controller.recordingState.value)
    }

    @Test
    @Ignore
    fun modeBest_success_savesAsDraftThenFinalizes() = runTest(testDispatcher) {
        entryDao.deleteAllEntries()
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_BEST)
        val cleanedText = "modeBest_success_savesAsDraftThenFinalizes"
        fakeOpenApi.result = CleanupResult.Success(cleanedText)
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("modeBest_success_savesAsDraftThenFinalizes one two three four five")
        val controller = buildController(prefs = fakePrefs)
        advanceUntilIdle()
        controller.onMainButtonTapped()
        advanceUntilIdle()

        val entries = entryRepository.getAllEntries().first()
        assertEquals(1, entries.size)
        assertFalse("Entry should not be a draft after cleanup", entries.first().isDraft)
        assertEquals(cleanedText, entries.first().cleanedText)
    }

    @Test
    fun modeOffline_success_savesDirectly_noDraft_noApiCall() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_OFFLINE)
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("private journal entry words")
        val controller = buildController(prefs = fakePrefs, api = fakeOpenApi)
        controller.onMainButtonTapped()
        advanceUntilIdle()

        val entries = entryRepository.getAllEntries().first()
        assertEquals(1, entries.size)
        assertFalse("MODE_OFFLINE entry should not be a draft", entries.first().isDraft)
        assertNull("MODE_OFFLINE entry should have no cleanedText", entries.first().cleanedText)
        assertEquals("OpenAI API must not be called in MODE_OFFLINE", 0, fakeOpenApi.callCount)
    }

    @Test
    fun oversizedTranscript_modeOffline_savesTruncatedText() = runTest(testDispatcher) {
        val oversizedTranscript = "a".repeat(CONTROLLER_TRANSCRIPT_LIMIT + 321)
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_OFFLINE)
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript(oversizedTranscript)
        val controller = buildController(prefs = fakePrefs, api = fakeOpenApi)

        controller.onMainButtonTapped()
        advanceUntilIdle()

        val entries = entryRepository.getAllEntries().first()
        assertEquals(1, entries.size)
        assertEquals(
            "MODE_OFFLINE should persist the controller-bounded transcript",
            oversizedTranscript.take(CONTROLLER_TRANSCRIPT_LIMIT),
            entries.first().rawTranscript,
        )
        assertEquals(CONTROLLER_TRANSCRIPT_LIMIT, entries.first().rawTranscript.length)
        assertEquals("Cleanup must not run in MODE_OFFLINE", 0, fakeOpenApi.callCount)
    }

    @Test
    fun exactLimitTranscript_modeBest_isNotTruncated() = runTest(testDispatcher) {
        val exactLimitTranscript = "c".repeat(CONTROLLER_TRANSCRIPT_LIMIT)
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_BEST)
        fakeOpenApi.result = CleanupResult.Success("Cleaned text.")
        fakeTranscription.nextResult = FakeTranscriptionService.FakeResult.FinalTranscript(
            text = exactLimitTranscript,
            detectedLanguage = "en",
        )
        val controller = buildController(prefs = fakePrefs, api = fakeOpenApi)

        controller.onMainButtonTapped()
        advanceUntilIdle()

        val entries = entryRepository.getAllEntries().first()
        assertEquals(1, entries.size)
        assertEquals(
            "A transcript at the controller limit should be stored unchanged",
            exactLimitTranscript,
            entries.first().rawTranscript,
        )
        assertEquals(
            "Cleanup should receive the unchanged transcript at the controller limit",
            exactLimitTranscript,
            fakeOpenApi.lastRawText,
        )
    }

    @Test
    @Ignore
    fun apiFailure_network_leavesEntryAsDraft() = runTest(testDispatcher) {
        fakeOpenApi.result = CleanupResult.Failure("network error")
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("one two three four five")
        val controller = buildController()
        advanceUntilIdle()
        controller.onMainButtonTapped()
        advanceUntilIdle()

        val drafts = entryDao.getPendingDrafts()
        assertEquals(1, drafts.size)
        assertTrue("Entry should remain a draft", drafts.first().isDraft)

        val state = controller.recordingState.value
        assertTrue("State should be Error or Idle after delay",
            state is RecordingState.Error || state is RecordingState.Idle)
    }

    @Test
    @Ignore
    fun apiFailure_rateLimit_emitsApiFailed() = runTest(testDispatcher) {
        fakeOpenApi.result = CleanupResult.Failure("rate limit")
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("one two three four five")
        val controller = buildController()
        controller.onMainButtonTapped()
        // Check state before the 1.5s auto-reset delay
        val stateBeforeReset = controller.recordingState.value
        // Could be Error(ApiFailed) or Idle depending on timing with UnconfinedTestDispatcher
        assertTrue(
            "State should be Error(ApiFailed) or Idle",
            stateBeforeReset is RecordingState.Idle ||
            (stateBeforeReset is RecordingState.Error &&
             stateBeforeReset.error == RecognizerError.ApiFailed)
        )
        // Draft should be in DB
        val drafts = entryDao.getPendingDrafts()
        assertEquals(1, drafts.size)
    }

    @Test
    fun transcriptionFailure_withAudioPath_savesAudioDraft() = runTest(testDispatcher) {
        fakeTranscription.nextResult = FakeTranscriptionService.FakeResult.FailureWithAudioDraft(
            reason = TranscriptionFailureReason.NetworkError,
            audioPath = "/tmp/test_audio.m4a"
        )
        val controller = buildController()
        controller.onMainButtonTapped()
        advanceUntilIdle()

        val allEntries = entryRepository.getAllEntries().first()
        assertEquals(1, allEntries.size)
        assertEquals("/tmp/test_audio.m4a", allEntries.first().audioPath)
        assertTrue("Audio draft should be a draft", allEntries.first().isDraft)
    }

    @Test
    fun transcriptionFailure_withNoAudioPath_noDbWrite() = runTest(testDispatcher) {
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.SpeechError(RecognizerError.NoMatch)
        val controller = buildController()
        controller.onMainButtonTapped()
        advanceUntilIdle()

        val entries = entryRepository.getAllEntries().first()
        assertTrue("DB should be empty for NothingCaught error", entries.isEmpty())
    }

    @Test
    fun onPermissionRevoked_cancelsRecording_returnsIdle() = runTest(testDispatcher) {
        val controller = buildController()
        // Trigger recording then revoke
        controller.onMainButtonTapped()
        controller.onPermissionRevoked()
        advanceUntilIdle()

        assertEquals(RecordingState.Idle, controller.recordingState.value)
    }

    @Test
    fun onEntriesDeleted_positive_emitsDeleted_thenIdle() = runTest(testDispatcher) {
        val controller = buildController()
        controller.onEntriesDeleted(3)

        val state = controller.recordingState.value
        assertTrue(
            "State should be Deleted(3)",
            state is RecordingState.Deleted && state.count == 3
        )

        advanceTimeBy(4_000)
        assertEquals(RecordingState.Idle, controller.recordingState.value)
    }

    @Test
    fun onEntriesDeleted_zero_isNoOp() = runTest(testDispatcher) {
        val controller = buildController()
        controller.onEntriesDeleted(0)
        assertEquals(RecordingState.Idle, controller.recordingState.value)
    }

    @Test
    fun shakeErrorKey_incrementsOnTooShort() = runTest(testDispatcher) {
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.SpeechError(RecognizerError.TooShort)
        val controller = buildController()
        val before = controller.shakeErrorKey.value
        controller.onMainButtonTapped()
        advanceUntilIdle()
        assertTrue("Shake key should increment", controller.shakeErrorKey.value > before)
    }

    @Test
    fun shakeErrorKey_incrementsOnNoMatch() = runTest(testDispatcher) {
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.SpeechError(RecognizerError.NoMatch)
        val controller = buildController()
        val before = controller.shakeErrorKey.value
        controller.onMainButtonTapped()
        advanceUntilIdle()
        assertTrue("Shake key should increment", controller.shakeErrorKey.value > before)
    }

    @Test
    @Ignore
    fun languageMismatch_modeBest_entryTaggedWithDetectedLanguage() = runTest(testDispatcher) {
        entryDao.deleteAllEntries()
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_BEST)
        val cleanedText = "modeBest_success_savesAsDraftThenFinalizes"
        fakeOpenApi.result = CleanupResult.Success(cleanedText)
        // Selected language is "en-US" but Deepgram detected "fr"
        fakeTranscription.nextResult = FakeTranscriptionService.FakeResult.FinalTranscript(
            text = "Bonjour le monde",
            detectedLanguage = "fr",
        )
        val controller = buildController(prefs = fakePrefs)
        advanceUntilIdle()
        controller.onMainButtonTapped()
        advanceUntilIdle()

        val entries = entryRepository.getAllEntries().first()
        assertEquals(1, entries.size)
        assertEquals("Entry should be tagged with detected language", "fr", entries.first().language)
        assertFalse("Entry should not be a draft", entries.first().isDraft)
    }

    @Test
    fun languageMismatch_modeOffline_keepsSelectedLanguage() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_OFFLINE)
        fakeTranscription.nextResult = FakeTranscriptionService.FakeResult.FinalTranscript(
            text = "Bonjour le monde",
            detectedLanguage = "fr",
        )
        val controller = buildController(prefs = fakePrefs)
        controller.onMainButtonTapped()
        advanceUntilIdle()

        val entries = entryRepository.getAllEntries().first()
        assertEquals(1, entries.size)
        assertEquals("Entry should keep selected language in offline mode", "en-US", entries.first().language)
        assertFalse("Entry should not be a draft", entries.first().isDraft)
    }

    @Test
    fun detectedLanguage_modeBest_entryTaggedWithDetectedLanguage() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_BEST)
        fakeOpenApi.result = CleanupResult.Success("Cleaned text.")
        fakeTranscription.nextResult = FakeTranscriptionService.FakeResult.FinalTranscript(
            text = "Hello world",
            detectedLanguage = "en",
        )
        val controller = buildController(prefs = fakePrefs)
        controller.onMainButtonTapped()
        advanceUntilIdle()

        val entries = entryRepository.getAllEntries().first()
        assertEquals(1, entries.size)
        assertEquals("Entry should use detected language in best mode", "en", entries.first().language)
    }

    @Test
    fun noDetectedLanguage_entryTaggedWithSelectedLanguage() = runTest(testDispatcher) {
        fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_BEST)
        fakeOpenApi.result = CleanupResult.Success("Cleaned text.")
        // On-device backend returns null detectedLanguage
        fakeTranscription.nextResult = FakeTranscriptionService.FakeResult.FinalTranscript(
            text = "Hello world",
            detectedLanguage = null,
        )
        val controller = buildController(prefs = fakePrefs)
        controller.onMainButtonTapped()
        advanceUntilIdle()

        val entries = entryRepository.getAllEntries().first()
        assertEquals(1, entries.size)
        assertEquals("Entry should keep selected language when no detection", "en-US", entries.first().language)
    }

    @Test
    fun oversizedTranscript_modeBest_savesTruncatedTextAndCleansBoundedTranscript() =
        runTest(testDispatcher) {
            val oversizedTranscript = "b".repeat(CONTROLLER_TRANSCRIPT_LIMIT + 777)
            val expectedTranscript = oversizedTranscript.take(CONTROLLER_TRANSCRIPT_LIMIT)
            fakePrefs = FakePreferencesRepository(initialPrivacyMode = PrivacyMode.MODE_BEST)
            fakeOpenApi.result = CleanupResult.Success("Cleaned text.")
            fakeTranscription.nextResult = FakeTranscriptionService.FakeResult.FinalTranscript(
                text = oversizedTranscript,
                detectedLanguage = "en",
            )
            val controller = buildController(prefs = fakePrefs, api = fakeOpenApi)

            controller.onMainButtonTapped()
            advanceUntilIdle()

            val entries = entryRepository.getAllEntries().first()
            assertEquals(1, entries.size)
            assertEquals(
                "MODE_BEST should persist the controller-bounded transcript in the draft/final entry",
                expectedTranscript,
                entries.first().rawTranscript,
            )
            assertEquals(CONTROLLER_TRANSCRIPT_LIMIT, entries.first().rawTranscript.length)
            assertEquals(
                "Cleanup should receive the controller-bounded transcript",
                expectedTranscript,
                fakeOpenApi.lastRawText,
            )
            assertEquals("Cleanup should run exactly once", 1, fakeOpenApi.callCount)
        }

    @Test
    fun shakeErrorKey_doesNotIncrement_onNetworkError() = runTest(testDispatcher) {
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.SpeechError(RecognizerError.NoInternet)
        val controller = buildController()
        val before = controller.shakeErrorKey.value
        controller.onMainButtonTapped()
        advanceUntilIdle()
        assertEquals("Shake key should NOT increment for network error", before, controller.shakeErrorKey.value)
    }

    private companion object {
        // Mirrors MainRecordingController's persistence cap.
        private const val CONTROLLER_TRANSCRIPT_LIMIT = 10_000
    }
}
