package com.wrait.app

import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.wrait.app.data.EntryDao
import com.wrait.app.data.WraitDatabase
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.repository.EntryRepositoryImpl
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.data.speech.TranscriptionFailureReason
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.usecase.CleanupTranscriptUseCase
import com.wrait.app.test.fake.FakeTranscriptCleanupService
import com.wrait.app.test.fake.FakePreferencesRepository
import com.wrait.app.test.fake.FakeTranscriptionService
import com.wrait.app.test.util.FakeTimeProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
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
        language: StateFlow<String> = MutableStateFlow(prefs.currentSelectedLanguage()),
        scope: CoroutineScope = testScope,
    ): MainRecordingController = MainRecordingController(
        selectedLanguageState = language,
        entryRepository = entryRepository,
        preferencesRepository = prefs,
        transcriptionService = transcription,
        cleanupTranscriptUseCase = CleanupTranscriptUseCase(
            transcriptCleanupService = api,
        ),
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
        val controller = buildController()
        // With UnconfinedTestDispatcher, tap immediately progresses to Processing
        // but state passes through Listening first
        controller.onMainButtonTapped()
        // After full pipeline: should be Saved or transitioned past Listening
        // We verify the pipeline ran by checking DB
        advanceUntilIdle()
        val entries = entryRepository.getAllEntries().first()
        assertTrue("Pipeline should have produced an entry", entries.isNotEmpty())
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
    fun shakeErrorKey_doesNotIncrement_onNetworkError() = runTest(testDispatcher) {
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.SpeechError(RecognizerError.NoInternet)
        val controller = buildController()
        val before = controller.shakeErrorKey.value
        controller.onMainButtonTapped()
        advanceUntilIdle()
        assertEquals("Shake key should NOT increment for network error", before, controller.shakeErrorKey.value)
    }
}
