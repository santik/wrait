package com.wrait.app.ui.entries

import androidx.lifecycle.viewModelScope
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
class EntryListViewModelTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    private lateinit var db: WraitDatabase
    private lateinit var dao: EntryDao
    private lateinit var repository: EntryRepository
    private val createdVms = mutableListOf<EntryListViewModel>()

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

    private fun createVm(): EntryListViewModel =
        EntryListViewModel(repository).also { createdVms.add(it) }

    private suspend fun insertEntry(transcript: String = "hello world", createdAt: Long = System.currentTimeMillis()): Long =
        dao.insert(EntryEntity(
            rawTranscript = transcript,
            cleanedText = null,
            isDraft = false,
            language = "en-US",
            createdAt = createdAt,
            wordCount = transcript.split(" ").size,
        ))

    @Test
    fun initialState_hasEmptySelection_noDialog() = runTest(testDispatcher) {
        val vm = createVm()
        val state = vm.uiState.value
        assertFalse(state.selectionMode)
        assertTrue(state.selectedIds.isEmpty())
        assertFalse(state.showDeleteDialog)
        assertEquals(0, state.lastDeletedCount)
    }

    @Test
    fun enterSelectionMode_setsActiveTrueAndAddsFirstId() = runTest(testDispatcher) {
        val vm = createVm()
        vm.enterSelectionMode(42L)

        val state = vm.uiState.value
        assertTrue(state.selectionMode)
        assertEquals(setOf(42L), state.selectedIds)
    }

    @Test
    fun toggleSelection_addsId_whenNotSelected() = runTest(testDispatcher) {
        val vm = createVm()
        vm.enterSelectionMode(1L)
        vm.toggleSelection(2L)

        assertEquals(setOf(1L, 2L), vm.uiState.value.selectedIds)
    }

    @Test
    fun toggleSelection_removesId_whenAlreadySelected() = runTest(testDispatcher) {
        val vm = createVm()
        vm.enterSelectionMode(1L)
        vm.toggleSelection(1L) // deselect

        assertTrue("Selection should be empty after deselecting the only item",
            vm.uiState.value.selectedIds.isEmpty())
    }

    @Test
    fun selectAll_populatesAllIds() = runTest(testDispatcher) {
        insertEntry(createdAt = 1_000L)
        insertEntry(createdAt = 2_000L)
        insertEntry(createdAt = 3_000L)

        val vm = createVm()
        advanceUntilIdle()

        val allIds = vm.uiState.first { it.entries.size == 3 }.entries.map { it.id }
        vm.selectAll(allIds)

        assertEquals(3, vm.uiState.value.selectedIds.size)
    }

    @Test
    fun deselectAll_clearsIds_keepsSelectionModeActive() = runTest(testDispatcher) {
        val vm = createVm()
        vm.enterSelectionMode(1L)
        vm.toggleSelection(2L)
        vm.deselectAll()

        val state = vm.uiState.value
        assertTrue("selectionMode should remain active", state.selectionMode)
        assertTrue("selectedIds should be empty", state.selectedIds.isEmpty())
    }

    @Test
    fun exitSelectionMode_resetsToDefaultState() = runTest(testDispatcher) {
        val vm = createVm()
        vm.enterSelectionMode(1L)
        vm.toggleSelection(2L)
        vm.exitSelectionMode()

        val state = vm.uiState.value
        assertFalse(state.selectionMode)
        assertTrue(state.selectedIds.isEmpty())
        assertFalse(state.showDeleteDialog)
    }

    @Test
    fun onDeleteButtonTapped_showsDialog() = runTest(testDispatcher) {
        val vm = createVm()
        vm.enterSelectionMode(1L)
        vm.onDeleteButtonTapped()

        assertTrue(vm.uiState.value.showDeleteDialog)
    }

    @Test
    fun onDeleteCancelled_hidesDialog_keepsSelection() = runTest(testDispatcher) {
        val vm = createVm()
        vm.enterSelectionMode(1L)
        vm.onDeleteButtonTapped()
        vm.onDeleteCancelled()

        val state = vm.uiState.value
        assertFalse(state.showDeleteDialog)
        assertTrue("Selection mode should remain active", state.selectionMode)
        assertEquals(setOf(1L), state.selectedIds)
    }

    @Test
    fun confirmDelete_removesEntriesFromDb_andExitsSelection() = runTest(testDispatcher) {
        val id1 = insertEntry(createdAt = 1_000L)
        val id2 = insertEntry(createdAt = 2_000L)

        val vm = createVm()
        advanceUntilIdle()

        vm.enterSelectionMode(id1)
        vm.toggleSelection(id2)
        vm.confirmDelete()
        advanceUntilIdle()

        val remaining = dao.getAllEntries().first()
        assertTrue("All selected entries should be deleted", remaining.isEmpty())
        assertFalse("Selection mode should exit after delete", vm.uiState.value.selectionMode)
    }

    @Test
    fun confirmDelete_updatesLastDeletedCount() = runTest(testDispatcher) {
        val id1 = insertEntry(createdAt = 1_000L)
        val id2 = insertEntry(createdAt = 2_000L)

        val vm = createVm()
        advanceUntilIdle()

        vm.enterSelectionMode(id1)
        vm.toggleSelection(id2)
        vm.confirmDelete()
        advanceUntilIdle()

        assertEquals(2, vm.uiState.value.lastDeletedCount)
    }

    @Test
    fun confirmDelete_emptySelection_isNoOp() = runTest(testDispatcher) {
        val id = insertEntry()
        val vm = createVm()
        advanceUntilIdle()

        // Enter selection but deselect all before confirming
        vm.enterSelectionMode(id)
        vm.deselectAll()
        vm.confirmDelete()
        advanceUntilIdle()

        val remaining = dao.getAllEntries().first()
        assertEquals("No entries should be deleted when selection is empty", 1, remaining.size)
    }

    @Test
    fun clearDeletedCount_resetsToZero() = runTest(testDispatcher) {
        val id = insertEntry()
        val vm = createVm()
        advanceUntilIdle()

        vm.enterSelectionMode(id)
        vm.confirmDelete()
        advanceUntilIdle()

        assertEquals(1, vm.uiState.value.lastDeletedCount)
        vm.clearDeletedCount()
        assertEquals(0, vm.uiState.value.lastDeletedCount)
    }

    @Test
    fun uiState_entriesList_reflectsDbChanges() = runTest(testDispatcher) {
        val vm = createVm()
        val initialState = vm.uiState.first { true }
        assertTrue("Initial entries should be empty", initialState.entries.isEmpty())

        insertEntry("new entry added directly")
        advanceUntilIdle()

        val updated = vm.uiState.first { it.entries.isNotEmpty() }
        assertEquals(1, updated.entries.size)
        assertEquals("new entry added directly", updated.entries.first().rawTranscript)
    }
}
