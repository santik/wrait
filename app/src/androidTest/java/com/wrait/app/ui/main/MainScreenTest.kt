package com.wrait.app.ui.main
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeDown
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.rule.GrantPermissionRule
import com.wrait.app.MainActivity
import com.wrait.app.data.EntryDao
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.api.TranscriptCleanupService
import com.wrait.app.data.device.NetworkAvailability
import com.wrait.app.data.speech.TranscriptionService
import com.wrait.app.domain.export.EntriesExportService
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.model.displayNameForLanguage
import com.wrait.app.domain.repository.PreferencesRepository
import com.wrait.app.test.fake.FakeEntriesExportService
import com.wrait.app.test.fake.FakeNetworkAvailability
import com.wrait.app.test.fake.FakeTranscriptCleanupService
import com.wrait.app.test.fake.FakeTranscriptionService
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import javax.inject.Inject

@HiltAndroidTest
@RunWith(AndroidJUnit4::class)
class MainScreenTest {

    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val permissionRule: GrantPermissionRule =
        GrantPermissionRule.grant(android.Manifest.permission.RECORD_AUDIO)

    @get:Rule(order = 2)
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Inject lateinit var entryDao: EntryDao
    @Inject lateinit var preferencesRepository: PreferencesRepository
    @Inject lateinit var transcriptCleanupService: TranscriptCleanupService
    @Inject lateinit var transcriptionService: TranscriptionService
    @Inject lateinit var networkAvailability: NetworkAvailability
    @Inject lateinit var entriesExportService: EntriesExportService

    private val fakeApi get() = transcriptCleanupService as FakeTranscriptCleanupService
    private val fakeTranscription get() = transcriptionService as FakeTranscriptionService
    private val fakeNetworkAvailability get() = networkAvailability as FakeNetworkAvailability
    private val fakeEntriesExportService get() = entriesExportService as FakeEntriesExportService

    @Before
    fun setUp() {
        hiltRule.inject()
        fakeApi.reset()
        fakeTranscription.reset()
        fakeNetworkAvailability.reset(isAvailable = true)
        fakeEntriesExportService.reset()
        runBlocking {
            preferencesRepository.setHasEverRecorded(false)
            preferencesRepository.setLanguage("en-US")
            preferencesRepository.savePrivacyMode(PrivacyMode.MODE_BEST)
            entryDao.deleteAllEntries()
        }
    }

    @Test
    fun mainScreen_noEntries_showsTapToWrite() {
        composeRule.waitUntil(timeoutMillis = 2_000) {
            runCatching {
                composeRule.onNodeWithText("tap button to write").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText("tap button to write").assertIsDisplayed()
    }

    @Test
    fun mainScreen_showsSettingsIcon_whenIdle() {
        composeRule.onNodeWithContentDescription("Open settings").assertIsDisplayed()
    }

    @Test
    fun settingsIcon_opensSettingsPanel() {
        composeRule.onNodeWithContentDescription("Open settings").performClick()

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("Offline mode").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        composeRule.onNodeWithText("Offline mode").assertIsDisplayed()
    }

    @Test
    fun settingsPanel_showsDevExportAction() {
        composeRule.onNodeWithContentDescription("Open settings").performClick()

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("Export entries").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        composeRule.onNodeWithText("Export entries").assertIsDisplayed()
        composeRule.onNodeWithText("Save finalized entries to Downloads as CSV").assertIsDisplayed()
    }

    @Test
    fun settingsPanel_exportAction_invokesExporter() {
        composeRule.onNodeWithContentDescription("Open settings").performClick()

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("Export entries").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        composeRule.onNodeWithText("Export entries").performClick()

        composeRule.waitUntil(timeoutMillis = 3_000) {
            fakeEntriesExportService.exportCallCount == 1
        }
    }

    @Test
    fun settings_hidesOfflineLanguageRow_inBestMode() {
        composeRule.onRoot().performTouchInput { swipeDown() }

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("Offline mode").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        composeRule.onNodeWithText("Offline mode").assertIsDisplayed()
        composeRule.onAllNodesWithText("Offline transcription language").assertCountEquals(0)
    }

    @Test
    fun settings_showsOfflineLanguageRow_inOfflineMode() {
        runBlocking {
            preferencesRepository.savePrivacyMode(PrivacyMode.MODE_OFFLINE)
        }

        composeRule.onRoot().performTouchInput { swipeDown() }

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("Offline transcription language").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        composeRule.onNodeWithText("Offline transcription language").assertIsDisplayed()
        composeRule.onNodeWithText("English · used only in offline mode").assertIsDisplayed()
    }

    @Test
    fun settingsIcon_hidesWhileRecordingIsActive() {
        fakeTranscription.transcribeGate = CompletableDeferred()

        try {
            composeRule.onNodeWithContentDescription("Main action button").performClick()

            composeRule.waitUntil(timeoutMillis = 3_000) {
                runCatching {
                    composeRule.onNodeWithText("listening…").assertIsDisplayed()
                    true
                }.getOrDefault(false)
            }

            composeRule.onAllNodesWithContentDescription("Open settings").assertCountEquals(0)
        } finally {
            fakeTranscription.transcribeGate?.complete(Unit)
        }
    }

    @Test
    fun settingsIcon_hidesWhileSettingsPanelIsOpen() {
        composeRule.onNodeWithContentDescription("Open settings").performClick()

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("Offline mode").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        composeRule.onNodeWithText("Offline mode").assertIsDisplayed()
        composeRule.onAllNodesWithContentDescription("Open settings").assertCountEquals(0)
    }

    @Test
    fun offlineLanguageRow_opensSingleSelectSheet() {
        val selectedLanguage = "en-US"
        runBlocking {
            preferencesRepository.savePrivacyMode(PrivacyMode.MODE_OFFLINE)
            preferencesRepository.setLanguage(selectedLanguage)
        }

        composeRule.onRoot().performTouchInput { swipeDown() }
        composeRule.onNodeWithText("Offline transcription language").performClick()

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("Offline transcription language").assertIsDisplayed()
                composeRule.onNodeWithText(
                    "Used only for offline transcription. Cloud transcription detects language automatically.",
                ).assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        composeRule.onNodeWithText(displayNameForLanguage(selectedLanguage)).assertIsDisplayed()
        composeRule.onNodeWithTag("language_option_$selectedLanguage").assertIsSelected()
    }

    @Test
    fun recordingSuccess_showsTapToRead() {
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("one two three four five")
        fakeApi.result = CleanupResult.Success("Cleaned entry text.")

        composeRule.onNodeWithContentDescription("Main action button").performClick()

        composeRule.waitUntil(timeoutMillis = 5_000) {
            runCatching {
                composeRule.onNodeWithText("tap to read").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText("tap to read").assertIsDisplayed()
    }

    @Test
    fun apiFailure_shows_savedAsDraft() {
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("one two three four five")
        fakeApi.result = CleanupResult.Failure("network error")

        composeRule.onNodeWithContentDescription("Main action button").performClick()

        composeRule.waitUntil(timeoutMillis = 5_000) {
            runCatching {
                composeRule.onNodeWithText("no connection · saved as draft").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText("no connection · saved as draft").assertIsDisplayed()
    }

    @Test
    fun offlineBestMode_showsError_andRetryStartsRecording_whenConnectionReturns() {
        fakeNetworkAvailability.isAvailable = false

        composeRule.onNodeWithContentDescription("Main action button").performClick()

        composeRule.waitUntil(timeoutMillis = 5_000) {
            runCatching {
                composeRule.onNodeWithText("best mode needs connection").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText("best mode needs connection").assertIsDisplayed()

        fakeNetworkAvailability.isAvailable = true
        fakeTranscription.transcribeGate = CompletableDeferred()

        try {
            composeRule.onNodeWithContentDescription("Main action button").performClick()

            composeRule.waitUntil(timeoutMillis = 5_000) {
                runCatching {
                    composeRule.onNodeWithText("listening…").assertIsDisplayed()
                    true
                }.getOrDefault(false)
            }
            composeRule.onNodeWithText("listening…").assertIsDisplayed()
        } finally {
            fakeTranscription.transcribeGate?.complete(Unit)
        }
    }

    @Test
    fun statsLine_showsEntryCount_afterSave() {
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("one two three four five")
        fakeApi.result = CleanupResult.Success("Cleaned entry.")

        composeRule.onNodeWithContentDescription("Main action button").performClick()

        composeRule.waitUntil(timeoutMillis = 5_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry", substring = true).assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText("1 entry", substring = true).assertIsDisplayed()

        composeRule.waitForIdle()
        composeRule.onNodeWithText("1 entry", substring = true).performClick()

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithContentDescription("Navigate back to recording screen")
                    .assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithContentDescription("Navigate back to recording screen").assertIsDisplayed()
    }
}
