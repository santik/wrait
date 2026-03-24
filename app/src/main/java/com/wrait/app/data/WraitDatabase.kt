package com.wrait.app.data

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(entities = [EntryEntity::class], version = 1, exportSchema = true)
abstract class WraitDatabase : RoomDatabase() {
    abstract fun entryDao(): EntryDao
}
