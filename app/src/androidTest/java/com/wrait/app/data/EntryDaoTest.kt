package com.wrait.app.data

import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class EntryDaoTest {

    private lateinit var db: WraitDatabase
    private lateinit var dao: EntryDao

    @Before
    fun setUp() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        db = Room.inMemoryDatabaseBuilder(context, WraitDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        dao = db.entryDao()
    }

    @After
    fun tearDown() {
        db.close()
    }

    private fun entity(
        id: Long = 0,
        rawTranscript: String = "hello world",
        cleanedText: String? = null,
        isDraft: Boolean = true,
        language: String = "en-US",
        createdAt: Long = 1_000L,
        wordCount: Int = 2,
        audioPath: String? = null,
    ) = EntryEntity(
        id = id,
        rawTranscript = rawTranscript,
        cleanedText = cleanedText,
        isDraft = isDraft,
        language = language,
        createdAt = createdAt,
        wordCount = wordCount,
        audioPath = audioPath,
    )

    @Test
    fun insert_returnsGeneratedId_greaterThanZero() = runTest {
        val id = dao.insert(entity())
        assertTrue("Generated id must be > 0", id > 0)
    }

    @Test
    fun insert_replacesOnConflict_withSameExplicitId() = runTest {
        val original = entity(id = 42L, rawTranscript = "original")
        val replacement = entity(id = 42L, rawTranscript = "replacement")
        dao.insert(original)
        dao.insert(replacement)

        val all = dao.getAllEntries().first()
        assertEquals(1, all.size)
        assertEquals("replacement", all.first().rawTranscript)
    }

    @Test
    fun update_modifiesExistingRow() = runTest {
        val id = dao.insert(entity(rawTranscript = "before"))
        val updated = entity(id = id, rawTranscript = "after", isDraft = false)
        dao.update(updated)

        val all = dao.getAllEntries().first()
        assertEquals(1, all.size)
        assertEquals("after", all.first().rawTranscript)
        assertFalse(all.first().isDraft)
    }

    @Test
    fun getAllEntries_emitsOnChange() = runTest {
        dao.insert(entity(rawTranscript = "first", createdAt = 1_000L))
        val first = dao.getAllEntries().first()
        assertEquals(1, first.size)

        dao.insert(entity(rawTranscript = "second", createdAt = 2_000L))
        val second = dao.getAllEntries().first()
        assertEquals(2, second.size)
        // Newest first
        assertEquals("second", second[0].rawTranscript)
        assertEquals("first", second[1].rawTranscript)
    }

    @Test
    fun getPendingDrafts_returnsEmpty_whenNoDrafts() = runTest {
        dao.insert(entity(isDraft = false, cleanedText = "clean1", createdAt = 1_000L))
        dao.insert(entity(isDraft = false, cleanedText = "clean2", createdAt = 2_000L))
        dao.insert(entity(isDraft = false, cleanedText = "clean3", createdAt = 3_000L))

        val drafts = dao.getPendingDrafts()
        assertTrue("No drafts should be returned", drafts.isEmpty())
    }

    @Test
    fun updateCleanedText_returns1_onExistingEntry() = runTest {
        val id = dao.insert(entity(isDraft = true))
        val affected = dao.updateCleanedText(id, "cleaned text", 2)
        assertEquals(1, affected)
    }

    @Test
    fun updateCleanedText_returns0_forMissingId() = runTest {
        val affected = dao.updateCleanedText(999L, "cleaned", 1)
        assertEquals(0, affected)
    }

    @Test
    fun updateCleanedText_clearsAudioPath() = runTest {
        val id = dao.insert(entity(audioPath = "file://audio.m4a"))
        dao.updateCleanedText(id, "cleaned", 1)

        val entry = dao.getEntryById(id).first()
        assertNotNull(entry)
        assertNull("audioPath should be NULL after updateCleanedText", entry!!.audioPath)
    }

    @Test
    fun updateCleanedText_setsDraftFalse() = runTest {
        val id = dao.insert(entity(isDraft = true))
        dao.updateCleanedText(id, "cleaned", 1)

        val entry = dao.getEntryById(id).first()
        assertNotNull(entry)
        assertFalse("isDraft should be false after updateCleanedText", entry!!.isDraft)
    }

    @Test
    fun updateDraftTranscript_updatesTextAndWordCount_andClearsAudioPath() = runTest {
        val id = dao.insert(entity(rawTranscript = "", wordCount = 0, audioPath = "file://x.m4a"))
        val affected = dao.updateDraftTranscript(id, "hello world", 2)

        assertEquals(1, affected)
        val entry = dao.getEntryById(id).first()
        assertNotNull(entry)
        assertEquals("hello world", entry!!.rawTranscript)
        assertEquals(2, entry.wordCount)
        assertNull("audioPath should be cleared", entry.audioPath)
        // isDraft stays true
        assertTrue("isDraft should remain true", entry.isDraft)
    }

    @Test
    fun updateDraftTranscript_returns0_forMissingId() = runTest {
        val affected = dao.updateDraftTranscript(999L, "text", 1)
        assertEquals(0, affected)
    }

    @Test
    fun finalizeDraftWithCleanedText_setsAllFields() = runTest {
        val id = dao.insert(entity(rawTranscript = "", audioPath = "file://audio.m4a", isDraft = true))
        val affected = dao.finalizeDraftWithCleanedText(
            id = id,
            rawTranscript = "raw text here",
            cleanedText = "cleaned text",
            wordCount = 3,
        )

        assertEquals(1, affected)
        val entry = dao.getEntryById(id).first()
        assertNotNull(entry)
        assertEquals("raw text here", entry!!.rawTranscript)
        assertEquals("cleaned text", entry.cleanedText)
        assertEquals(3, entry.wordCount)
        assertFalse("isDraft should be false after finalize", entry.isDraft)
        assertNull("audioPath should be NULL after finalize", entry.audioPath)
    }

    @Test
    fun getEntryById_emitsNull_forMissingId() = runTest {
        val entry = dao.getEntryById(999L).first()
        assertNull("Should emit null for unknown id", entry)
    }

    @Test
    fun getEntryById_emitsUpdatedValue_afterUpdate() = runTest {
        val id = dao.insert(entity(rawTranscript = "before"))
        val initial = dao.getEntryById(id).first()
        assertEquals("before", initial!!.rawTranscript)

        dao.updateCleanedText(id, "after cleaned", 2)
        val updated = dao.getEntryById(id).first()
        assertEquals("after cleaned", updated!!.cleanedText)
    }

    @Test
    fun deleteDraftsOlderThan_leavesNonDrafts() = runTest {
        val cutoff = 10_000L
        dao.insert(entity(isDraft = false, cleanedText = "finalized", createdAt = 1_000L))
        dao.insert(entity(isDraft = true, createdAt = 1_000L))

        dao.deleteDraftsOlderThan(cutoff)

        val remaining = dao.getAllEntries().first()
        assertEquals(1, remaining.size)
        assertFalse("Non-draft should survive", remaining.first().isDraft)
    }

    @Test
    fun deleteDraftsOlderThan_boundaryIsExclusive() = runTest {
        val cutoff = 5_000L
        dao.insert(entity(isDraft = true, createdAt = cutoff)) // exactly at cutoff — should be kept

        dao.deleteDraftsOlderThan(cutoff)

        val remaining = dao.getAllEntries().first()
        assertEquals("Draft exactly at cutoff should be kept", 1, remaining.size)
    }

    @Test
    fun deleteEntries_removesAllListedIds() = runTest {
        val id1 = dao.insert(entity(createdAt = 1_000L))
        val id2 = dao.insert(entity(createdAt = 2_000L))
        val id3 = dao.insert(entity(createdAt = 3_000L))

        dao.deleteEntries(listOf(id1, id2))

        val remaining = dao.getAllEntries().first()
        assertEquals(1, remaining.size)
        assertEquals(id3, remaining.first().id)
    }

    @Test
    fun deleteEntries_emptyList_isNoOp() = runTest {
        dao.insert(entity(createdAt = 1_000L))
        // Room expands @Query("DELETE FROM entries WHERE id IN (:ids)") to SQL at compile time.
        // SQLite's behaviour for an empty IN list is version-dependent: some versions throw
        // android.database.sqlite.SQLiteException, others treat it as a no-op.
        // At the repository layer, EntryRepositoryImpl guards with `if (ids.isEmpty()) return`
        // so this path should never be reached in production. We test it here solely to
        // document the DAO contract: regardless of whether an exception is thrown, no rows
        // should be silently deleted.
        try {
            dao.deleteEntries(emptyList())
        } catch (_: Exception) {
            // SQLiteException on some devices — acceptable; the repository guards prevent this
        }
        val all = dao.getAllEntries().first()
        assertTrue("No rows should be deleted by an empty-list call", all.isNotEmpty())
    }

    @Test
    fun getAudioPathsByIds_returnsOnlyNonNull() = runTest {
        val id1 = dao.insert(entity(audioPath = "file://a.m4a", createdAt = 1_000L))
        val id2 = dao.insert(entity(audioPath = null, createdAt = 2_000L))

        val paths = dao.getAudioPathsByIds(listOf(id1, id2))
        assertEquals(1, paths.size)
        assertEquals("file://a.m4a", paths.first())
    }

    @Test
    fun getDraftAudioPathsOlderThan_filtersCorrectly() = runTest {
        val cutoff = 10_000L
        // Old draft with audio — should be returned
        dao.insert(entity(isDraft = true, createdAt = 1_000L, audioPath = "file://old_draft.m4a"))
        // Recent draft with audio — should NOT be returned (newer than cutoff)
        dao.insert(entity(isDraft = true, createdAt = 20_000L, audioPath = "file://recent_draft.m4a"))
        // Old finalized with audio — should NOT be returned (not a draft)
        dao.insert(entity(isDraft = false, cleanedText = "clean", createdAt = 1_000L, audioPath = "file://old_clean.m4a"))
        // Old draft without audio — not in results (no audioPath)
        dao.insert(entity(isDraft = true, createdAt = 1_000L, audioPath = null))

        val paths = dao.getDraftAudioPathsOlderThan(cutoff)
        assertEquals(1, paths.size)
        assertEquals("file://old_draft.m4a", paths.first())
    }
}
