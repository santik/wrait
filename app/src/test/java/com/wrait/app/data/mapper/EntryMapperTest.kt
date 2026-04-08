package com.wrait.app.data.mapper

import com.wrait.app.data.EntryEntity
import com.wrait.app.domain.model.Entry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class EntryMapperTest {

    private val fullEntity = EntryEntity(
        id = 42L,
        rawTranscript = "raw text here",
        cleanedText = "cleaned text here",
        isDraft = false,
        language = "en-US",
        createdAt = 1_700_000_000_000L,
        wordCount = 3,
        audioPath = "/cache/audio.m4a",
    )

    private val fullEntry = Entry(
        id = 42L,
        rawTranscript = "raw text here",
        cleanedText = "cleaned text here",
        isDraft = false,
        language = "en-US",
        createdAt = 1_700_000_000_000L,
        wordCount = 3,
        audioPath = "/cache/audio.m4a",
    )

    @Test
    fun entryEntity_toDomain_mapsAllFields() {
        val result = fullEntity.toDomain()
        assertEquals(42L, result.id)
        assertEquals("raw text here", result.rawTranscript)
        assertEquals("cleaned text here", result.cleanedText)
        assertEquals(false, result.isDraft)
        assertEquals("en-US", result.language)
        assertEquals(1_700_000_000_000L, result.createdAt)
        assertEquals(3, result.wordCount)
        assertEquals("/cache/audio.m4a", result.audioPath)
    }

    @Test
    fun entryEntity_toDomain_withNullCleanedText() {
        val entity = fullEntity.copy(cleanedText = null)
        val result = entity.toDomain()
        assertNull(result.cleanedText)
    }

    @Test
    fun entryEntity_toDomain_withNullAudioPath() {
        val entity = fullEntity.copy(audioPath = null)
        val result = entity.toDomain()
        assertNull(result.audioPath)
    }

    @Test
    fun entry_toEntity_mapsAllFields() {
        val result = fullEntry.toEntity()
        assertEquals(42L, result.id)
        assertEquals("raw text here", result.rawTranscript)
        assertEquals("cleaned text here", result.cleanedText)
        assertEquals(false, result.isDraft)
        assertEquals("en-US", result.language)
        assertEquals(1_700_000_000_000L, result.createdAt)
        assertEquals(3, result.wordCount)
        assertEquals("/cache/audio.m4a", result.audioPath)
    }

    @Test
    fun entity_toDomain_roundTrip() {
        val result = fullEntity.toDomain().toEntity()
        assertEquals(fullEntity, result)
    }

    @Test
    fun domain_toEntity_roundTrip() {
        val result = fullEntry.toEntity().toDomain()
        assertEquals(fullEntry, result)
    }
}
