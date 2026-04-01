package com.wrait.app.data

import androidx.room.Database
import androidx.room.migration.Migration
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(entities = [EntryEntity::class], version = 2, exportSchema = true)
abstract class WraitDatabase : RoomDatabase() {
    abstract fun entryDao(): EntryDao

    companion object {
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE entries ADD COLUMN audioPath TEXT")
            }
        }
    }
}
