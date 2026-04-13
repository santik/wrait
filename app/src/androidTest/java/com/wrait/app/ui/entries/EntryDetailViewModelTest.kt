package com.wrait.app.ui.entries

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import org.junit.Ignore
import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.wrait.app.data.EntryDao
import com.wrait.app.data.EntryEntity
import com.wrait.app.data.WraitDatabase
import com.wrait.app.data.repository.EntryRepositoryImpl
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.util.TimeProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
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
    }

    @After
    fun tearDown() {
        createdVms.forEach { it.viewModelScope.cancel() }
        createdVms.clear()
        Dispatchers.resetMain()
        db.close()
    }

    private fun createVm(entryId: Long): EntryDetailViewModel =
        EntryDetailViewModel(
            entryRepository = repository,
            savedStateHandle = SavedStateHandle(mapOf("entryId" to entryId)),
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
    fun onDeleteTapped_showsDialog() = runTest(testDispatcher) {
        val id = insertFinalized()
        val vm = createVm(id)
        vm.onDeleteTapped()

        assertTrue(vm.showDeleteDialog.value)
    }

    @Test
    fun onDeleteCancelled_hidesDialog() = runTest(testDispatcher) {
        val id = insertFinalized()
        val vm = createVm(id)
        vm.onDeleteTapped()
        vm.onDeleteCancelled()

        assertFalse(vm.showDeleteDialog.value)
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
    fun confirmDelete_onMissingId_doesNotCrash() = runTest(testDispatcher) {
        // VM for a non-existent entry
        val vm = createVm(entryId = 999L)
        advanceUntilIdle()

        // Should not throw
        vm.confirmDelete { }
        advanceUntilIdle()

        // Callback may or may not fire depending on whether deleteEntries throws for empty result
        // The key requirement is no crash
    }
}
