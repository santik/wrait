package com.wrait.app.ui.entries

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeRight
import androidx.compose.ui.geometry.Offset
import com.wrait.app.ui.theme.DesignTokens.Gesture
import org.junit.Ignore
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.wrait.app.MainActivity
import com.wrait.app.data.EntryDao
import com.wrait.app.data.EntryEntity
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
class EntryListScreenTest {

    companion object {
        private const val BELOW_THRESHOLD_RATIO = 0.4f
        private const val ABOVE_THRESHOLD_RATIO = 1.1f
    }

    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
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

    private fun dragDownOnNode(text: String, distancePx: Float) {
        composeRule.onNodeWithText(text)
            .performTouchInput {
                down(center)
                moveTo(Offset(center.x, center.y + distancePx))
                up()
            }
    }

    @Test
    @Ignore
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
    @Ignore
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
    @Ignore
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
    @Ignore
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
    @Ignore
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
    @Ignore
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

    // Navigate to an empty list by seeding one entry (so the stats line is tappable),
    // then deleting it via DAO after landing on the list screen.
    private fun navigateToEmptyList() {
        insertEntry("Placeholder entry")
        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        navigateToList("1 entry")
        runBlocking {
            val ids = entryDao.getAllEntries().first().map { it.id }
            entryDao.deleteEntries(ids)
        }
        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("your entries will appear here").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
    }

    @Test
    @Ignore
    fun swipeDown_emptyList_aboveThreshold_navigatesBackToMain() {
        navigateToEmptyList()
        val swipeBackThresholdPx = with(composeRule.density) { Gesture.SwipeBackThresholdDp.toPx() }

        dragDownOnNode(
            text = "your entries will appear here",
            distancePx = swipeBackThresholdPx * ABOVE_THRESHOLD_RATIO,
        )

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithContentDescription("Main action button").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithContentDescription("Main action button").assertIsDisplayed()
    }

    @Test
    @Ignore
    fun swipeDown_emptyList_belowThreshold_doesNotNavigate() {
        navigateToEmptyList()

        val swipeBackThresholdPx = with(composeRule.density) { Gesture.SwipeBackThresholdDp.toPx() }

        // Drag 40% of swipeBackThresholdPx (computed from SwipeBackThresholdDp) — well below
        // the threshold, so the gesture must not navigate away from the list screen.
        dragDownOnNode(
            text = "your entries will appear here",
            distancePx = swipeBackThresholdPx * BELOW_THRESHOLD_RATIO,
        )

        composeRule.mainClock.advanceTimeBy(500)
        composeRule.onNodeWithContentDescription("Navigate back to recording screen")
            .assertIsDisplayed()
    }

    @Test
    @Ignore
    fun swipeDown_populatedList_aboveThreshold_navigatesBackToMain() {
        val text = "Entry for populated swipe-back test"
        insertEntry(text)

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithText("1 entry").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }

        navigateToList("1 entry")

        val swipeBackThresholdPx = with(composeRule.density) { Gesture.SwipeBackThresholdDp.toPx() }
        dragDownOnNode(
            text = text,
            distancePx = swipeBackThresholdPx * ABOVE_THRESHOLD_RATIO,
        )

        composeRule.waitUntil(timeoutMillis = 3_000) {
            runCatching {
                composeRule.onNodeWithContentDescription("Main action button").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        composeRule.onNodeWithContentDescription("Main action button").assertIsDisplayed()
    }

    @Test
    @Ignore
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
