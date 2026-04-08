package com.wrait.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.wrait.app.data.EntryDao
import com.wrait.app.data.EntryEntity
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.api.OpenAiApiService
import com.wrait.app.data.speech.TranscriptionService
import com.wrait.app.test.fake.FakeOpenAiApiService
import com.wrait.app.test.fake.FakeTranscriptionService
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.repository.PreferencesRepository
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import javax.inject.Inject

@HiltAndroidTest
@RunWith(AndroidJUnit4::class)
class FullJourneyTest {

    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Inject lateinit var entryDao: EntryDao
    @Inject lateinit var openAiApiService: OpenAiApiService
    @Inject lateinit var transcriptionService: TranscriptionService
    @Inject lateinit var preferencesRepository: PreferencesRepository

    private val fakeApi get() = openAiApiService as FakeOpenAiApiService
    private val fakeTranscription get() = transcriptionService as FakeTranscriptionService

    @Before
    fun setUp() {
        hiltRule.inject()
        fakeApi.reset()
        fakeTranscription.reset()
        runBlocking {
            val ids = entryDao.getAllEntries().first().map { it.id }
            if (ids.isNotEmpty()) entryDao.deleteEntries(ids)
        }
    }

    @Test
    fun record_save_navigate_read_delete() {
        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("this is my first journal entry today")
        fakeApi.result = CleanupResult.Success("This is my first journal entry today.")

        // Step 1: Verify initial state
        composeRule.onNodeWithText("tap to write").assertIsDisplayed()

        // Step 2: Tap record button to start recording
        composeRule.onNodeWithContentDescription("Main action button").performClick()

        // Step 3: Wait for "tap to read" (recording saved)
        composeRule.waitUntil(timeoutMillis = 8_000) {
            runCatching {
                composeRule.onNodeWithText("tap to read").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText("tap to read").assertIsDisplayed()

        // Step 4: Tap "tap to read" to navigate to detail
        composeRule.onNodeWithText("tap to read").performClick()

        // Step 5: Verify entry text in detail screen
        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("This is my first journal entry today.").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText("This is my first journal entry today.").assertIsDisplayed()

        // Step 6: Delete the entry
        composeRule.onNodeWithContentDescription("Delete entry").performClick()

        // Step 7: Confirm delete in dialog
        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("Delete this entry?").assertIsDisplayed()
                true
            }.getOrDefault(false) ||
            runCatching {
                composeRule.onNodeWithText("Delete 1 entry?").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText("Delete").performClick()

        // Step 8: Should navigate back to entries list (empty)
        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("your entries will appear here").assertIsDisplayed()
                true
            }.getOrDefault(false) ||
            runCatching {
                composeRule.onNodeWithContentDescription("Navigate back to recording screen")
                    .assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
    }

    @Test
    fun multipleEntries_bulkDelete() {
        runBlocking {
            entryDao.insert(EntryEntity(
                rawTranscript = "First entry text",
                cleanedText = "First entry text",
                isDraft = false,
                language = "en-US",
                createdAt = System.currentTimeMillis() - 3_000,
                wordCount = 3,
            ))
            entryDao.insert(EntryEntity(
                rawTranscript = "Second entry text",
                cleanedText = "Second entry text",
                isDraft = false,
                language = "en-US",
                createdAt = System.currentTimeMillis() - 2_000,
                wordCount = 3,
            ))
            entryDao.insert(EntryEntity(
                rawTranscript = "Third entry text",
                cleanedText = "Third entry text",
                isDraft = false,
                language = "en-US",
                createdAt = System.currentTimeMillis() - 1_000,
                wordCount = 3,
            ))
        }

        // Wait for stats to show all 3 entries, then tap to navigate to list
        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("3 entries").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText("3 entries").performClick()

        // Wait for list screen
        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithContentDescription("Navigate back to recording screen")
                    .assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        // Verify all 3 entries visible
        composeRule.onNodeWithText("First entry text").assertIsDisplayed()
        composeRule.onNodeWithText("Second entry text").assertIsDisplayed()
        composeRule.onNodeWithText("Third entry text").assertIsDisplayed()

        // Long-press first entry to enter selection mode
        composeRule.onNodeWithText("First entry text").performTouchInput { longClick() }
        composeRule.waitUntil(timeoutMillis = 2_000) {
            runCatching { composeRule.onNodeWithText("1 selected").assertIsDisplayed(); true }.getOrDefault(false)
        }

        // Tap second and third entries to add to selection
        composeRule.onNodeWithText("Second entry text").performClick()
        composeRule.onNodeWithText("Third entry text").performClick()
        composeRule.waitUntil(timeoutMillis = 2_000) {
            runCatching { composeRule.onNodeWithText("3 selected").assertIsDisplayed(); true }.getOrDefault(false)
        }

        // Tap delete button and confirm
        composeRule.onNodeWithContentDescription("Delete selected entries").performClick()
        composeRule.waitUntil(timeoutMillis = 2_000) {
            runCatching { composeRule.onNodeWithText("Delete 3 entries?").assertIsDisplayed(); true }.getOrDefault(false)
        }
        composeRule.onNodeWithText("Delete").performClick()

        // Verify empty state is shown
        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("your entries will appear here").assertIsDisplayed()
                true
            }.getOrDefault(false) ||
            runCatching {
                composeRule.onNodeWithContentDescription("Main action button").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
    }

    @Test
    fun draftRetry_onStartup() {
        // The MainViewModel.initJob retries pending text drafts when the app starts.
        // Since the activity is already running by the time this test body executes,
        // we cannot re-trigger initJob here. Full retry behavior is verified in:
        //   MainViewModelTest.draftRetry_onInit_upgradesDraftToEntry
        //
        // This test verifies that inserting a draft directly into the DB is reflected in
        // the DB state correctly (i.e. it is a proper pending draft for the retry mechanism).
        val id = runBlocking {
            entryDao.insert(EntryEntity(
                rawTranscript = "draft text that needs cleanup",
                cleanedText = null,
                isDraft = true,
                language = "en-US",
                createdAt = System.currentTimeMillis(),
                wordCount = 5,
            ))
        }

        fakeApi.result = CleanupResult.Success("Draft text that needs cleanup.")

        val drafts = runBlocking { entryDao.getPendingDrafts() }
        assertTrue("Inserted draft should be pending", drafts.any { it.id == id })
        assertTrue("Draft should have isDraft=true", drafts.first { it.id == id }.isDraft)
        assertNull("Draft should have no cleanedText", drafts.first { it.id == id }.cleanedText)
    }

    @Test
    fun modePrivate_skips_cleanup() {
        // Set MODE_PRIVATE so the recording pipeline skips OpenAI cleanup entirely.
        // The activity is already running; updating the DataStore flow is reflected in the
        // recording controller before the button is tapped.
        runBlocking { preferencesRepository.savePrivacyMode(PrivacyMode.MODE_PRIVATE) }

        fakeTranscription.nextResult =
            FakeTranscriptionService.FakeResult.FinalTranscript("private journal entry words here")
        // fakeApi.callCount was reset to 0 in setUp — any call would be a test failure

        composeRule.onNodeWithContentDescription("Main action button").performClick()

        composeRule.waitUntil(timeoutMillis = 5_000) {
            runCatching {
                composeRule.onNodeWithText("tap to read").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText("tap to read").assertIsDisplayed()

        assertEquals("OpenAI API must not be called in MODE_PRIVATE", 0, fakeApi.callCount)

        val entries = runBlocking { entryDao.getAllEntries().first() }
        assertEquals(1, entries.size)
        assertFalse("MODE_PRIVATE entry must not be a draft", entries.first().isDraft)
        assertNull("MODE_PRIVATE entry must have no cleanedText", entries.first().cleanedText)
    }
}
