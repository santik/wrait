package com.wrait.app.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "entries")
data class EntryEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val rawTranscript: String,
    val cleanedText: String?,
    val isDraft: Boolean,
    val language: String,
    val createdAt: Long,
    val wordCount: Int
)
