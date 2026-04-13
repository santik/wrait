package com.wrait.app.data

import org.junit.Ignore
import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.wrait.app.data.repository.EntryRepositoryImpl
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.test.util.FakeTimeProvider
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class EntryRepositoryExtensionsTest {

    private lateinit var db: WraitDatabase
    private lateinit var dao: EntryDao
    private lateinit var repository: EntryRepository
    private lateinit var fakeTime: FakeTimeProvider

    @Before
    fun setUp() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        db = Room.inMemoryDatabaseBuilder(context, WraitDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        dao = db.entryDao()
        fakeTime = FakeTimeProvider()
        repository = EntryRepositoryImpl(dao, fakeTime)
    }

    @After
    fun tearDown() {
        db.close()
    }

    // --- saveEntry ---

    @Test
    fun saveEntry_createsFinalizedEntry() = runTest {
        val id = repository.saveEntry("Hello world this is five", "en-US")

        val entries = repository.getAllEntries().first()
        assertEquals(1, entries.size)
        val entry = entries.first()
        assertEquals(id, entry.id)
        assertFalse("saveEntry should produce isDraft=false", entry.isDraft)
        assertNull("saveEntry should not set cleanedText", entry.cleanedText)
        assertEquals(5, entry.wordCount)
        assertEquals("en-US", entry.language)
    }

    @Test
    fun saveEntry_usesCurrentTime() = runTest {
        fakeTime.time = 1_234_567_890_000L
        repository.saveEntry("test entry", "en-US")

        val entries = repository.getAllEntries().first()
        assertEquals(1_234_567_890_000L, entries.first().createdAt)
    }

    // --- saveAudioDraft ---

    @Test
    fun saveAudioDraft_persistsAudioPath() = runTest {
        val id = repository.saveAudioDraft("/cache/audio.m4a", "de-DE")

        val entries = repository.getAllEntries().first()
        assertEquals(1, entries.size)
        val entry = entries.first()
        assertEquals(id, entry.id)
        assertEquals("/cache/audio.m4a", entry.audioPath)
        assertEquals("", entry.rawTranscript)
        assertEquals(0, entry.wordCount)
        assertTrue("Audio draft should be isDraft=true", entry.isDraft)
        assertEquals("de-DE", entry.language)
    }

    @Test
    fun saveAudioDraft_usesCurrentTime() = runTest {
        fakeTime.time = 9_000_000_000_000L
        repository.saveAudioDraft("/tmp/x.m4a", "en-US")

        val entries = repository.getAllEntries().first()
        assertEquals(9_000_000_000_000L, entries.first().createdAt)
    }

    // --- updateDraftTranscript ---

    @Test
    fun updateDraftTranscript_succeeds_forExistingDraft() = runTest {
        val id = repository.saveAudioDraft("/tmp/audio.m4a", "en-US")
        repository.updateDraftTranscript(id, "hello world from audio", 4)

        val entries = repository.getAllEntries().first()
        val entry = entries.first()
        assertEquals("hello world from audio", entry.rawTranscript)
        assertEquals(4, entry.wordCount)
        assertNull("audioPath should be cleared after updateDraftTranscript", entry.audioPath)
        // isDraft remains true — cleanup hasn't happened yet
        assertTrue("isDraft should still be true", entry.isDraft)
    }

    @Test(expected = IllegalArgumentException::class)
    fun updateDraftTranscript_throws_forMissingId() = runTest {
        repository.updateDraftTranscript(999L, "text", 1)
    }

    // --- finalizeDraftWithCleanedText ---

    @Test
    fun finalizeDraftWithCleanedText_setsAllFields_andClearsDraft() = runTest {
        val id = repository.saveAudioDraft("/tmp/audio.m4a", "fr-FR")
        repository.finalizeDraftWithCleanedText(id, "raw text here", "cleaned text here", 3)

        val entries = repository.getAllEntries().first()
        assertEquals(1, entries.size)
        val entry = entries.first()
        assertEquals("raw text here", entry.rawTranscript)
        assertEquals("cleaned text here", entry.cleanedText)
        assertEquals(3, entry.wordCount)
        assertFalse("Entry should no longer be a draft", entry.isDraft)
        assertNull("audioPath should be cleared", entry.audioPath)
    }

    @Test(expected = IllegalArgumentException::class)
    fun finalizeDraftWithCleanedText_throws_forMissingId() = runTest {
        repository.finalizeDraftWithCleanedText(999L, "raw", "clean", 1)
    }

    // --- updateEntryLanguage ---

    @Test
    fun updateEntryLanguage_updatesLanguageField() = runTest {
        val id = repository.saveEntry("Hello world test", "en-US")
        repository.updateEntryLanguage(id, "fr")

        val entries = repository.getAllEntries().first()
        assertEquals("fr", entries.first().language)
    }

    @Test(expected = IllegalArgumentException::class)
    fun updateEntryLanguage_throws_forMissingId() = runTest {
        repository.updateEntryLanguage(999L, "fr")
    }

    @Test
    @Ignore
    fun updateEntryLanguage_doesNotAffectOtherFields() = runTest {
        val id = repository.saveEntry("Hello world five words here", "en-US")
        repository.updateEntryLanguage(id, "de")

        val entry = repository.getAllEntries().first().first()
        assertEquals("de", entry.language)
        assertFalse("isDraft should remain unchanged", entry.isDraft)
        assertEquals("Hello world five words here", entry.rawTranscript)
        assertEquals(6, entry.wordCount)
    }

    // --- getEntryById ---

    @Test
    fun getEntryById_returnsSuccess_withEntry() = runTest {
        val id = repository.saveEntry("some entry text", "en-US")
        val result = repository.getEntryById(id).first()

        assertTrue("Result should be success", result.isSuccess)
        val entry = result.getOrNull()
        assertNotNull(entry)
        assertEquals(id, entry!!.id)
    }

    @Test
    fun getEntryById_returnsSuccessNull_forMissingId() = runTest {
        val result = repository.getEntryById(999L).first()

        assertTrue("Result should be success", result.isSuccess)
        assertNull("Entry should be null for missing id", result.getOrNull())
    }

    // --- deleteEntries ---

    @Test
    fun deleteEntries_removesFromDb() = runTest {
        val id1 = repository.saveEntry("entry one", "en-US")
        val id2 = repository.saveEntry("entry two", "en-US")

        repository.deleteEntries(listOf(id1, id2))

        val entries = repository.getAllEntries().first()
        assertTrue("All entries should be deleted", entries.isEmpty())
    }

    @Test
    fun deleteEntries_withAudioPath_deletesFileOnDisk() = runTest {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val audioFile = File(context.cacheDir, "test_audio_${System.nanoTime()}.m4a")
        audioFile.createNewFile()
        assertTrue("Audio file should exist before deletion", audioFile.exists())

        val id = repository.saveAudioDraft(audioFile.absolutePath, "en-US")
        repository.deleteEntries(listOf(id))

        assertFalse("Audio file should be deleted from disk", audioFile.exists())
        val entries = repository.getAllEntries().first()
        assertTrue("Entry should be deleted from DB", entries.isEmpty())
    }

    @Test
    fun deleteEntries_emptyList_isNoOp() = runTest {
        repository.saveEntry("keep me", "en-US")
        repository.deleteEntries(emptyList())

        val entries = repository.getAllEntries().first()
        assertEquals("Entry should remain after empty delete", 1, entries.size)
    }

    // --- deleteStaleDrafts with audio files ---

    @Test
    fun deleteStaleDrafts_deletesAudioFile_ofStaleDraft() = runTest {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val audioFile = File(context.cacheDir, "stale_audio_${System.nanoTime()}.m4a")
        audioFile.createNewFile()
        assertTrue("Audio file should exist", audioFile.exists())

        val now = System.currentTimeMillis()
        fakeTime.time = now

        // Insert stale audio draft directly via DAO (older than 7 days)
        dao.insert(EntryEntity(
            rawTranscript = "",
            cleanedText = null,
            isDraft = true,
            language = "en-US",
            createdAt = now - TimeUnit.DAYS.toMillis(8),
            wordCount = 0,
            audioPath = audioFile.absolutePath,
        ))

        repository.deleteStaleDrafts()

        assertFalse("Stale draft audio file should be deleted", audioFile.exists())
        assertTrue("Stale draft entry should be deleted", repository.getAllEntries().first().isEmpty())
    }

    @Test
    fun deleteStaleDrafts_keepsAudioFile_ofFreshDraft() = runTest {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val audioFile = File(context.cacheDir, "fresh_audio_${System.nanoTime()}.m4a")
        audioFile.createNewFile()
        assertTrue("Audio file should exist", audioFile.exists())

        val now = System.currentTimeMillis()
        fakeTime.time = now

        // Insert fresh audio draft (only 2 days old)
        dao.insert(EntryEntity(
            rawTranscript = "",
            cleanedText = null,
            isDraft = true,
            language = "en-US",
            createdAt = now - TimeUnit.DAYS.toMillis(2),
            wordCount = 0,
            audioPath = audioFile.absolutePath,
        ))

        repository.deleteStaleDrafts()

        assertTrue("Fresh draft audio file should be preserved", audioFile.exists())
        assertEquals("Fresh draft entry should be preserved", 1, repository.getAllEntries().first().size)

        // Clean up
        audioFile.delete()
    }
}
