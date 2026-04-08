package com.wrait.app.data

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import androidx.room.testing.MigrationTestHelper
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TestName
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DatabaseMigrationTest {

    @get:Rule
    val helper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        WraitDatabase::class.java,
    )

    @get:Rule
    val testName = TestName()

    @Test
    fun migrate1to2_addsAudioPathColumn() {
        // Create DB at version 1 and insert a row
        helper.createDatabase(testName.methodName, 1).apply {
            val values = ContentValues().apply {
                put("rawTranscript", "test transcript")
                put("cleanedText", "cleaned")
                put("isDraft", 0)
                put("language", "en-US")
                put("createdAt", 1_700_000_000_000L)
                put("wordCount", 2)
            }
            insert("entries", SQLiteDatabase.CONFLICT_FAIL, values)
            close()
        }

        // Run migration to version 2
        val db = helper.runMigrationsAndValidate(testName.methodName, 2, true, WraitDatabase.MIGRATION_1_2)

        // Verify the audioPath column exists and is NULL for the existing row
        db.query("SELECT audioPath FROM entries").use { cursor ->
            assertTrue("Migrated DB should have rows", cursor.moveToFirst())
            val colIdx = cursor.getColumnIndex("audioPath")
            assertTrue("audioPath column should exist", colIdx >= 0)
            assertTrue("audioPath should be NULL for pre-migration row", cursor.isNull(colIdx))
        }
    }

    @Test
    fun migrate1to2_existingRows_surviveIntact() {
        helper.createDatabase(testName.methodName, 1).apply {
            val values = ContentValues().apply {
                put("rawTranscript", "original transcript")
                put("cleanedText", "original cleaned")
                put("isDraft", 1)
                put("language", "fr-FR")
                put("createdAt", 9_999_999_999_000L)
                put("wordCount", 7)
            }
            insert("entries", SQLiteDatabase.CONFLICT_FAIL, values)
            close()
        }

        val db = helper.runMigrationsAndValidate(testName.methodName, 2, true, WraitDatabase.MIGRATION_1_2)

        db.query("SELECT * FROM entries").use { cursor ->
            assertTrue("Should have one row", cursor.moveToFirst())
            assertEquals("original transcript", cursor.getString(cursor.getColumnIndexOrThrow("rawTranscript")))
            assertEquals("original cleaned", cursor.getString(cursor.getColumnIndexOrThrow("cleanedText")))
            assertEquals(1, cursor.getInt(cursor.getColumnIndexOrThrow("isDraft")))
            assertEquals("fr-FR", cursor.getString(cursor.getColumnIndexOrThrow("language")))
            assertEquals(9_999_999_999_000L, cursor.getLong(cursor.getColumnIndexOrThrow("createdAt")))
            assertEquals(7, cursor.getInt(cursor.getColumnIndexOrThrow("wordCount")))
        }
    }

    @Test
    fun migrate1to2_newInsert_canPopulateAudioPath() {
        helper.createDatabase(testName.methodName, 1).apply { close() }

        val db = helper.runMigrationsAndValidate(testName.methodName, 2, true, WraitDatabase.MIGRATION_1_2)

        val values = ContentValues().apply {
            put("rawTranscript", "")
            put("cleanedText", null as String?)
            put("isDraft", 1)
            put("language", "en-US")
            put("createdAt", 1_000L)
            put("wordCount", 0)
            put("audioPath", "/cache/audio.m4a")
        }
        val rowId = db.insert("entries", SQLiteDatabase.CONFLICT_FAIL, values)
        assertTrue("Insert with audioPath should succeed", rowId > 0)

        db.query("SELECT audioPath FROM entries WHERE id = $rowId").use { cursor ->
            assertTrue(cursor.moveToFirst())
            assertEquals("/cache/audio.m4a", cursor.getString(cursor.getColumnIndexOrThrow("audioPath")))
        }
    }

    @Test
    fun openWithCurrentVersion_validates() {
        // Creates a fresh DB at version 2 and validates it against the exported schema
        helper.createDatabase(testName.methodName, 2).close()
        // runMigrationsAndValidate with no migrations just validates the schema
        helper.runMigrationsAndValidate(testName.methodName, 2, true)
    }
}
