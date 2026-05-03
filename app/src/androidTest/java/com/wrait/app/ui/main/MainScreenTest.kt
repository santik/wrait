package com.wrait.app.ui.main

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performClick
import androidx.test.rule.GrantPermissionRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.wrait.app.MainActivity
import com.wrait.app.data.EntryDao
import com.wrait.app.data.api.CleanupResult
import com.wrait.app.data.api.TranscriptCleanupService
import com.wrait.app.data.speech.TranscriptionService
import com.wrait.app.test.fake.FakeTranscriptCleanupService
import com.wrait.app.test.fake.FakeTranscriptionService
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import kotlinx.coroutines.flow.first
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
    @Inject lateinit var transcriptCleanupService: TranscriptCleanupService
    @Inject lateinit var transcriptionService: TranscriptionService

    private val fakeApi get() = transcriptCleanupService as FakeTranscriptCleanupService
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
    fun mainScreen_noEntries_showsTapToWrite() {
        // On first launch with an empty database the main screen shows "tap to write".
        // The entry-list empty state ("your entries will appear here") is only reachable once at
        // least one entry exists (stats must be non-zero to show the tappable stats line).
        composeRule.waitUntil(timeoutMillis = 2_000) {
            runCatching {
                composeRule.onNodeWithText("tap button to write").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText("tap button to write").assertIsDisplayed()
    }

    @Test
    fun recordingSuccess_shows_tapToRead() {
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

        // Verify the list screen is now showing (back button visible)
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
