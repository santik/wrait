package com.wrait.app.data.mapper

import com.wrait.app.data.EntryEntity
import com.wrait.app.domain.model.Entry

fun EntryEntity.toDomain(): Entry {
    return Entry(
        id = id,
        rawTranscript = rawTranscript,
        cleanedText = cleanedText,
        isDraft = isDraft,
        language = language,
        createdAt = createdAt,
        wordCount = wordCount,
        audioPath = audioPath,
    )
}

fun Entry.toEntity(): EntryEntity {
    return EntryEntity(
        id = id,
        rawTranscript = rawTranscript,
        cleanedText = cleanedText,
        isDraft = isDraft,
        language = language,
        createdAt = createdAt,
        wordCount = wordCount,
        audioPath = audioPath,
    )
}
