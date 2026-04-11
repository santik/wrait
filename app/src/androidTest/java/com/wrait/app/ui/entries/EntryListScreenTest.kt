package com.wrait.app.ui.entries

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeRight
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
class EntryListScreenTest {

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

    private fun insertEntry(
        text: String,
        createdAt: Long = System.currentTimeMillis(),
    ) = runBlocking {
        entryDao.insert(EntryEntity(
            rawTranscript = text,
            cleanedText = text,
            isDraft = false,
            language = "en-US",
            createdAt = createdAt,
            wordCount = text.split(" ").size,
        ))
    }

    private fun navigateToList(statsText: String) {
        composeRule.onNodeWithText(statsText).performClick()
        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithContentDescription("Navigate back to recording screen")
                    .assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
    }

    @Test
    fun entryList_displaysInsertedEntries() {
        insertEntry("Alpha entry content here", createdAt = System.currentTimeMillis() - 2_000)
        insertEntry("Beta entry content here", createdAt = System.currentTimeMillis() - 1_000)

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("2 entries").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        navigateToList("2 entries")

        composeRule.onNodeWithText("Alpha entry content here").assertIsDisplayed()
        composeRule.onNodeWithText("Beta entry content here").assertIsDisplayed()
    }

    @Test
    fun entryList_audioDraftCard_isDisabledAndDoesNotNavigate() {
        // Insert an audio-only draft (no transcript, no cleaned text, has audioPath).
        // The card should be non-tappable and tapping it must not navigate to the detail screen.
        runBlocking {
            entryDao.insert(EntryEntity(
                rawTranscript = "",
                cleanedText   = null,
                isDraft       = true,
                language      = "en-US",
                createdAt     = System.currentTimeMillis(),
                wordCount     = 0,
                audioPath     = "/tmp/pending.m4a"
            ))
        }

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        navigateToList("1 entry")

        // The audio-draft preview text is defined in R.string.entry_list_audio_draft_preview
        composeRule.onNodeWithText("pending · will retry").assertIsDisplayed()

        // Verify the card is semantically disabled
        composeRule.onNodeWithText("pending · will retry").assertIsNotEnabled()

        // Tapping must not navigate to the detail screen
        composeRule.onNodeWithText("pending · will retry").performClick()
        composeRule.mainClock.advanceTimeBy(500)
        composeRule.onNodeWithContentDescription("Navigate back to recording screen")
            .assertIsDisplayed() // still on list screen, not detail
    }

    @Test
    fun swipeDelete_confirmDialog_removesCard() {
        val text = "Entry to be deleted"
        insertEntry(text)

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        navigateToList("1 entry")

        composeRule.onNodeWithText(text).performTouchInput { swipeRight() }

        composeRule.waitUntil(timeoutMillis = 2_000) {
            runCatching {
                composeRule.onNodeWithText("Delete entry?").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        composeRule.onNodeWithText("Delete").performClick()
        composeRule.mainClock.advanceTimeBy(500)
        composeRule.onNodeWithText(text).assertDoesNotExist()
    }

    @Test
    fun swipeDelete_cancelDialog_cardSnapsBack() {
        val text = "Entry to keep"
        insertEntry(text)

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        navigateToList("1 entry")

        composeRule.onNodeWithText(text).performTouchInput { swipeRight() }

        composeRule.waitUntil(timeoutMillis = 2_000) {
            runCatching {
                composeRule.onNodeWithText("Delete entry?").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        composeRule.onNodeWithText("Cancel").performClick()
        composeRule.mainClock.advanceTimeBy(500)
        composeRule.onNodeWithText(text).assertIsDisplayed()
    }

    @Test
    fun entryList_tapEntry_navigatesToDetail() {
        insertEntry("Detail navigation entry text")

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        navigateToList("1 entry")

        composeRule.onNodeWithText("Detail navigation entry text").performClick()

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithContentDescription("Navigate back to entry list")
                    .assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithContentDescription("Navigate back to entry list").assertIsDisplayed()
    }

    @Test
    fun swipeDelete_audioDraftCard_showsDialog() {
        // Audio drafts are non-tappable but should still be swipeable for deletion.
        runBlocking {
            entryDao.insert(EntryEntity(
                rawTranscript = "",
                cleanedText   = null,
                isDraft       = true,
                language      = "en-US",
                createdAt     = System.currentTimeMillis(),
                wordCount     = 0,
                audioPath     = "/tmp/pending.m4a"
            ))
        }

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        navigateToList("1 entry")

        composeRule.onNodeWithText("pending · will retry").performTouchInput { swipeRight() }

        composeRule.waitUntil(timeoutMillis = 2_000) {
            runCatching {
                composeRule.onNodeWithText("Delete entry?").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithText("Delete entry?").assertIsDisplayed()
    }

    @Test
    fun entryList_backButton_navigatesBackToMain() {
        insertEntry("Entry for back navigation test")

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        navigateToList("1 entry")

        composeRule.onNodeWithContentDescription("Navigate back to recording screen").performClick()

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithContentDescription("Main action button").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithContentDescription("Main action button").assertIsDisplayed()
    }
}
