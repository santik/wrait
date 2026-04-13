package com.wrait.app.ui.entries

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import org.junit.Ignore
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.wrait.app.MainActivity
import com.wrait.app.data.EntryDao
import com.wrait.app.data.EntryEntity
import com.wrait.app.data.api.OpenAiApiService
import com.wrait.app.data.speech.TranscriptionService
import com.wrait.app.test.fake.FakeOpenAiApiService
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
class EntryDetailScreenTest {

    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Inject lateinit var entryDao: EntryDao
    @Inject lateinit var openAiApiService: OpenAiApiService
    @Inject lateinit var transcriptionService: TranscriptionService

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

    private fun insertFinalized(text: String): Long = runBlocking {
        entryDao.insert(EntryEntity(
            rawTranscript = text,
            cleanedText = text,
            isDraft = false,
            language = "en-US",
            createdAt = System.currentTimeMillis(),
            wordCount = text.split(" ").size,
        ))
    }

    private fun insertDraft(rawTranscript: String): Long = runBlocking {
        entryDao.insert(EntryEntity(
            rawTranscript = rawTranscript,
            cleanedText = null,
            isDraft = true,
            language = "en-US",
            createdAt = System.currentTimeMillis(),
            wordCount = rawTranscript.split(" ").size,
        ))
    }

    private fun navigateToEntry(entryText: String) {
        // Wait for stats, then navigate to list, then tap the entry
        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithContentDescription("Navigate back to recording screen")
                    .assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText(entryText).performClick()
        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithContentDescription("Navigate back to entry list")
                    .assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
    }

    @Test
    @Ignore
    fun entryDetail_displaysCleanedText_forFinalizedEntry() {
        insertFinalized("Unique cleaned entry content for detail test")

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        navigateToEntry("Unique cleaned entry content for detail test")
        composeRule.onNodeWithText("Unique cleaned entry content for detail test").assertIsDisplayed()
    }

    @Test
    @Ignore
    fun entryDetail_displaysRawTranscript_andDraftNotice_forDraft() {
        insertDraft("Draft raw transcript content here")

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        navigateToEntry("Draft raw transcript content here")

        composeRule.onNodeWithText("Draft raw transcript content here").assertIsDisplayed()
        composeRule.onNodeWithText("not yet cleaned up — will update automatically").assertIsDisplayed()
    }

    @Test
    @Ignore
    fun entryDetail_deleteButton_tap_showsDialog() {
        insertFinalized("Entry for delete dialog test")

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        navigateToEntry("Entry for delete dialog test")

        composeRule.onNodeWithContentDescription("Delete entry").performClick()

        composeRule.waitUntil(timeoutMillis = 2_000) {
            runCatching {
                composeRule.onNodeWithText("Delete this entry?").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText("Delete this entry?").assertIsDisplayed()
        composeRule.onNodeWithText("This cannot be undone.").assertIsDisplayed()
    }

    @Test
    @Ignore
    fun entryDetail_deleteConfirm_navigatesBackToList() {
        insertFinalized("Entry to confirm delete from detail")

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        navigateToEntry("Entry to confirm delete from detail")

        composeRule.onNodeWithContentDescription("Delete entry").performClick()
        composeRule.waitUntil(timeoutMillis = 2_000) {
            runCatching { composeRule.onNodeWithText("Delete this entry?").assertIsDisplayed(); true }.getOrDefault(false)
        }
        composeRule.onNodeWithText("Delete").performClick()

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithContentDescription("Navigate back to recording screen")
                    .assertIsDisplayed()
                true
            }.getOrDefault(false) ||
            runCatching {
                composeRule.onNodeWithText("your entries will appear here").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
    }

    @Test
    @Ignore
    fun entryDetail_deleteCancel_dismissesDialog() {
        insertFinalized("Entry cancel delete from detail")

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        navigateToEntry("Entry cancel delete from detail")

        composeRule.onNodeWithContentDescription("Delete entry").performClick()
        composeRule.waitUntil(timeoutMillis = 2_000) {
            runCatching { composeRule.onNodeWithText("Delete this entry?").assertIsDisplayed(); true }.getOrDefault(false)
        }
        composeRule.onNodeWithText("Cancel").performClick()

        composeRule.waitUntil(timeoutMillis = 2_000) {
            runCatching {
                composeRule.onNodeWithText("Delete this entry?").assertDoesNotExist()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText("Entry cancel delete from detail").assertIsDisplayed()
    }

    @Test
    @Ignore
    fun entryDetail_backButton_navigatesToList() {
        insertFinalized("Back navigation from detail test")

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        navigateToEntry("Back navigation from detail test")

        composeRule.onNodeWithContentDescription("Navigate back to entry list").performClick()

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
