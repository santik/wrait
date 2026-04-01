package com.wrait.app.domain.model

data class Entry(
    val id: Long = 0,
    val rawTranscript: String,
    val cleanedText: String? = null,
    val isDraft: Boolean,
    val language: String,
    val createdAt: Long,
    val wordCount: Int,
    /** Non-null when this entry is an audio-only draft (not yet transcribed). */
    val audioPath: String? = null,
)
