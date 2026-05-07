package com.wrait.app.ui.entries

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import org.junit.Ignore
import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.wrait.app.analytics.AnalyticsEntrySource
import com.wrait.app.data.EntryDao
import com.wrait.app.data.EntryEntity
import com.wrait.app.data.WraitDatabase
import com.wrait.app.data.repository.EntryRepositoryImpl
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.util.TimeProvider
import com.wrait.app.test.fake.FakeAnalyticsTracker
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.job
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

@RunWith(AndroidJUnit4::class)
class EntryDetailViewModelTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    private lateinit var db: WraitDatabase
    private lateinit var dao: EntryDao
    private lateinit var repository: EntryRepository
    private lateinit var analytics: FakeAnalyticsTracker
    private val createdVms = mutableListOf<EntryDetailViewModel>()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        db = Room.inMemoryDatabaseBuilder(context, WraitDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        dao = db.entryDao()
        repository = EntryRepositoryImpl(dao, object : TimeProvider {
            override fun currentTimeMillis() = System.currentTimeMillis()
        })
        analytics = FakeAnalyticsTracker()
    }

    @After
    fun tearDown() {
        runBlocking {
            createdVms.forEach { it.viewModelScope.coroutineContext.job.cancelAndJoin() }
        }
        createdVms.clear()
        Dispatchers.resetMain()
        db.close()
    }

    private fun createVm(
        entryId: Long,
        savedState: Map<String, Any?> = mapOf("entryId" to entryId),
    ): EntryDetailViewModel =
        EntryDetailViewModel(
            entryRepository = repository,
            analyticsTracker = analytics,
            ioDispatcher = testDispatcher,
            savedStateHandle = SavedStateHandle(savedState),
        ).also { createdVms.add(it) }

    private suspend fun insertFinalized(
        rawTranscript: String = "raw text here",
        cleanedText: String? = "cleaned text",
    ): Long = dao.insert(EntryEntity(
        rawTranscript = rawTranscript,
        cleanedText = cleanedText,
        isDraft = false,
        language = "en-US",
        createdAt = System.currentTimeMillis(),
        wordCount = rawTranscript.split(" ").size,
    ))

    private suspend fun insertDraft(rawTranscript: String = "draft raw"): Long =
        dao.insert(EntryEntity(
            rawTranscript = rawTranscript,
            cleanedText = null,
            isDraft = true,
            language = "en-US",
            createdAt = System.currentTimeMillis(),
            wordCount = rawTranscript.split(" ").size,
        ))

    @Test
    fun entry_loadsCorrectly_byId() = runTest(testDispatcher) {
        val id = insertFinalized()
        val vm = createVm(id)
        advanceUntilIdle()

        val result = vm.entry.first { it.getOrNull() != null }
        assertTrue(result.isSuccess)
        assertEquals(id, result.getOrNull()!!.id)
    }

    @Test
    fun entry_emitsSuccessNull_forMissingId() = runTest(testDispatcher) {
        val vm = createVm(entryId = 999L)
        advanceUntilIdle()

        val result = vm.entry.value
        assertTrue("Should be success", result.isSuccess)
        assertNull("Entry should be null for missing id", result.getOrNull())
    }

    @Test
    fun editedText_initializedFromCleanedText_whenNotDraft() = runTest(testDispatcher) {
        val id = insertFinalized(rawTranscript = "raw text", cleanedText = "cleaned text")
        val vm = createVm(id)
        advanceUntilIdle()

        val editedText = vm.editedText.first { it != null }
        assertEquals("cleaned text", editedText)
    }

    @Test
    fun editedText_initializedFromRawTranscript_whenNoCleanedText() = runTest(testDispatcher) {
        val id = insertFinalized(rawTranscript = "only raw", cleanedText = null)
        val vm = createVm(id)
        advanceUntilIdle()

        val editedText = vm.editedText.first { it != null }
        assertEquals("only raw", editedText)
    }

    @Test
    fun editedText_isNull_forDraftEntry() = runTest(testDispatcher) {
        val id = insertDraft("draft content here")
        val vm = createVm(id)
        advanceUntilIdle()

        // Draft entries should not initialize editedText
        assertNull("editedText should remain null for drafts", vm.editedText.value)
    }

    @Test
    fun entryOpened_tracksOnce() = runTest(testDispatcher) {
        val id = insertFinalized()
        val vm = createVm(id)
        val loaded = vm.entry.first { it.getOrNull()?.id == id }
        assertEquals(id, loaded.getOrNull()!!.id)

        vm.onTextChanged("updated text")
        advanceUntilIdle()

        assertEquals(
            1,
            analytics.events.count { it is FakeAnalyticsTracker.Event.EntryDetailOpened }
        )
        assertTrue(
            analytics.events.any {
                it is FakeAnalyticsTracker.Event.EntryDetailOpened && !it.isDraft
            }
        )
    }

    @Test
    fun entryOpened_retracksAfterViewModelRecreation() = runTest(testDispatcher) {
        val id = insertFinalized()
        val firstVm = createVm(entryId = id)
        val firstLoaded = firstVm.entry.first { it.getOrNull()?.id == id }
        assertEquals(id, firstLoaded.getOrNull()!!.id)

        val secondVm = createVm(entryId = id)
        val secondLoaded = secondVm.entry.first { it.getOrNull()?.id == id }
        assertEquals(id, secondLoaded.getOrNull()!!.id)

        assertEquals(
            2,
            analytics.events.count { it is FakeAnalyticsTracker.Event.EntryDetailOpened }
        )
    }

    @Test
    fun onDeleteTapped_showsDialog() = runTest(testDispatcher) {
        val id = insertFinalized()
        val vm = createVm(id)
        val loaded = vm.entry.first { it.getOrNull()?.id == id }
        assertEquals(id, loaded.getOrNull()!!.id)
        vm.onDeleteTapped()

        assertTrue(vm.showDeleteDialog.value)
        assertTrue(
            analytics.events.any {
                it is FakeAnalyticsTracker.Event.EntryDeleteInitiated &&
                    it.source == AnalyticsEntrySource.Detail &&
                    !it.isDraft
            }
        )
    }

    @Test
    fun onDeleteCancelled_hidesDialog() = runTest(testDispatcher) {
        val id = insertFinalized()
        val vm = createVm(id)
        advanceUntilIdle()
        vm.onDeleteTapped()
        vm.onDeleteCancelled()

        assertFalse(vm.showDeleteDialog.value)
    }

    @Test
    fun onShareSucceeded_tracksDetailSource() = runTest(testDispatcher) {
        val id = insertFinalized()
        val vm = createVm(id)
        val loaded = vm.entry.first { it.getOrNull()?.id == id }
        assertEquals(id, loaded.getOrNull()!!.id)

        vm.onShareSucceeded()

        assertTrue(
            analytics.events.any {
                it is FakeAnalyticsTracker.Event.EntryShared &&
                    it.source == AnalyticsEntrySource.Detail
            }
        )
    }

    @Test
    fun onShareSucceeded_skipsDraftEntries() = runTest(testDispatcher) {
        val id = insertDraft("draft content here")
        val vm = createVm(id)
        advanceUntilIdle()

        vm.onShareSucceeded()

        assertFalse(
            analytics.events.any { it is FakeAnalyticsTracker.Event.EntryShared }
        )
    }

    @Test
    @Ignore
    fun confirmDelete_removesEntryFromDb_andInvokesCallback() = runTest(testDispatcher) {
        val id = insertFinalized()
        val vm = createVm(id)
        advanceUntilIdle()

        var callbackFired = false
        vm.confirmDelete { callbackFired = true }
        advanceUntilIdle()

        assertTrue("Callback should have been invoked", callbackFired)
        val remaining = dao.getAllEntries().first()
        assertTrue("Entry should be deleted from DB", remaining.isEmpty())
    }

    @Test
    fun confirmDelete_success_tracksDeletion() = runTest(testDispatcher) {
        val id = insertFinalized()
        val vm = createVm(id)
        val loaded = vm.entry.first { it.getOrNull()?.id == id }
        assertEquals(id, loaded.getOrNull()!!.id)

        vm.confirmDelete { }
        val deleted = vm.entry.first { it.getOrNull() == null }
        assertNull(deleted.getOrNull())

        assertTrue(
            analytics.events.any {
                it is FakeAnalyticsTracker.Event.EntryDeleted &&
                    it.source == AnalyticsEntrySource.Detail &&
                    !it.isDraft
            }
        )
    }

    @Test
    fun confirmDelete_onMissingId_doesNotCrash() = runTest(testDispatcher) {
        // VM for a non-existent entry
        val vm = createVm(entryId = 999L)
        advanceUntilIdle()

        // Should not throw
        vm.confirmDelete { }
        advanceUntilIdle()

        // Callback may or may not fire depending on whether deleteEntries throws for empty result
        // The key requirement is no crash
        assertFalse(
            analytics.events.any { it is FakeAnalyticsTracker.Event.EntryDeleted }
        )
    }
}
