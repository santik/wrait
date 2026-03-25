package com.wrait.app.data

import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.wrait.app.data.repository.EntryRepositoryImpl
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.util.TimeProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.asExecutor
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.TimeUnit

class FakeTimeProvider(var time: Long = 0L) : TimeProvider {
    override fun currentTimeMillis(): Long = time
}

@RunWith(AndroidJUnit4::class)
class EntryRepositoryTest {

    private lateinit var database: WraitDatabase
    private lateinit var entryDao: EntryDao
    private lateinit var repository: EntryRepository
    private lateinit var timeProvider: FakeTimeProvider

    @Before
    fun setUp() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        database = Room.inMemoryDatabaseBuilder(
            context,
            WraitDatabase::class.java
        ).setQueryExecutor(Dispatchers.IO.asExecutor())
         .setTransactionExecutor(Dispatchers.IO.asExecutor())
         .build()
        
        entryDao = database.entryDao()
        timeProvider = FakeTimeProvider(System.currentTimeMillis())
        repository = EntryRepositoryImpl(entryDao, timeProvider)
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun saveDraft_createsDraftCorrectly() = runTest {
        val now = 1700000000000L
        timeProvider.time = now
        val transcript = "Hello world this is a test"
        val language = "en-US"
        
        val id = repository.saveDraft(transcript, language)
        
        val drafts = repository.getPendingDrafts()
        assertEquals(1, drafts.size)
        
        val draft = drafts.first()
        assertEquals(id, draft.id)
        assertEquals(transcript, draft.rawTranscript)
        assertEquals(language, draft.language)
        assertTrue(draft.isDraft)
        assertNull(draft.cleanedText)
        assertEquals(6, draft.wordCount)
        assertEquals(now, draft.createdAt)
    }

    @Test
    fun updateWithCleanedText_unmarksDraftAndPopulatesWordCount() = runTest {
        val id = repository.saveDraft("Original transcript", "en-US")
        
        val cleanedText = "Cleaned transcript"
        val wordCount = 2
        
        repository.updateWithCleanedText(id, cleanedText, wordCount)
        
        val drafts = repository.getPendingDrafts()
        assertTrue(drafts.isEmpty())
        
        val allEntries = repository.getAllEntries().first()
        assertEquals(1, allEntries.size)
        
        val entry = allEntries.first()
        assertFalse(entry.isDraft)
        assertEquals("Original transcript", entry.rawTranscript)
        assertEquals(cleanedText, entry.cleanedText)
        assertEquals(wordCount, entry.wordCount)
    }

    @Test(expected = IllegalArgumentException::class)
    fun updateWithCleanedText_throwsExceptionWhenIdDoesNotExist() = runTest {
        repository.updateWithCleanedText(999L, "Cleaned", 2)
    }

    @Test
    fun getAllEntries_returnsNewestFirst() = runTest {
        val oldEntity = EntryEntity(
            rawTranscript = "Old",
            cleanedText = null,
            isDraft = true,
            language = "en-US",
            createdAt = 1000L,
            wordCount = 1
        )
        val newEntity = EntryEntity(
            rawTranscript = "New",
            cleanedText = null,
            isDraft = true,
            language = "en-US",
            createdAt = 5000L,
            wordCount = 1
        )
        
        entryDao.insert(oldEntity)
        entryDao.insert(newEntity)
        
        val allEntries = repository.getAllEntries().first()
        assertEquals(2, allEntries.size)
        assertEquals("New", allEntries[0].rawTranscript)
        assertEquals("Old", allEntries[1].rawTranscript)
    }

    @Test
    fun getPendingDrafts_returnsOnlyDrafts() = runTest {
        val draftEntity = EntryEntity(
            rawTranscript = "Draft",
            cleanedText = null,
            isDraft = true,
            language = "en-US",
            createdAt = 1000L,
            wordCount = 1
        )
        val cleanedEntity = EntryEntity(
            rawTranscript = "Clean",
            cleanedText = "Clean",
            isDraft = false,
            language = "en-US",
            createdAt = 2000L,
            wordCount = 1
        )
        
        entryDao.insert(draftEntity)
        entryDao.insert(cleanedEntity)
        
        val drafts = repository.getPendingDrafts()
        assertEquals(1, drafts.size)
        assertEquals("Draft", drafts.first().rawTranscript)
    }

    @Test
    fun deleteStaleDrafts_purgesSpecificallyOldDrafts() = runTest {
        val now = 1000000000000L
        timeProvider.time = now
        val sevenDaysMs = TimeUnit.DAYS.toMillis(7)
        
        val oldDraft = EntryEntity(
            rawTranscript = "Old Draft",
            cleanedText = null,
            isDraft = true,
            language = "en-US",
            createdAt = now - sevenDaysMs - 1000L,
            wordCount = 2
        )
        val recentDraft = EntryEntity(
            rawTranscript = "Recent Draft",
            cleanedText = null,
            isDraft = true,
            language = "en-US",
            createdAt = now - TimeUnit.DAYS.toMillis(2),
            wordCount = 2
        )
        val oldCleaned = EntryEntity(
            rawTranscript = "Old Cleaned",
            cleanedText = "Cleaned",
            isDraft = false,
            language = "en-US",
            createdAt = now - sevenDaysMs - 5000L,
            wordCount = 2
        )
        
        entryDao.insert(oldDraft)
        entryDao.insert(recentDraft)
        entryDao.insert(oldCleaned)
        
        repository.deleteStaleDrafts(7)
        
        val allEntries = repository.getAllEntries().first()
        assertEquals(2, allEntries.size)
        
        val remainingTranscripts = allEntries.map { it.rawTranscript }
        assertFalse(remainingTranscripts.contains("Old Draft"))
        assertTrue(remainingTranscripts.contains("Recent Draft"))
        assertTrue(remainingTranscripts.contains("Old Cleaned"))
    }

    @Test
    fun deleteStaleDrafts_keepsDraftsExactlyAtCutoff() = runTest {
        val now = 2000000000000L
        timeProvider.time = now
        val sevenDaysMs = TimeUnit.DAYS.toMillis(7)
        
        val boundaryDraft = EntryEntity(
            rawTranscript = "Boundary Draft",
            cleanedText = null,
            isDraft = true,
            language = "en-US",
            createdAt = now - sevenDaysMs,
            wordCount = 2
        )
        entryDao.insert(boundaryDraft)
        
        repository.deleteStaleDrafts(7)
        
        val allEntries = repository.getAllEntries().first()
        assertEquals(1, allEntries.size)
        assertEquals("Boundary Draft", allEntries[0].rawTranscript)
    }
}
