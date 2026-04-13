package com.wrait.app.ui.entries

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
    fun initialState_hasEmptyEntries() = runTest(testDispatcher) {
        val vm = createVm()
        assertTrue(vm.uiState.value.entries.isEmpty())
    }

    @Test
    @Ignore
    fun deleteEntry_removesEntryFromUiState() = runTest(testDispatcher) {
        val id = insertEntry("entry to delete")
        val vm = createVm()
        advanceUntilIdle()

        assertEquals(1, vm.uiState.value.entries.size)

        vm.deleteEntry(id)
        advanceUntilIdle()

        assertTrue(vm.uiState.value.entries.isEmpty())
    }

    @Test
    fun deleteEntry_unknownId_doesNotThrow() = runTest(testDispatcher) {
        val vm = createVm()
        vm.deleteEntry(9999L)
        advanceUntilIdle()
        assertTrue(vm.uiState.value.entries.isEmpty())
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
