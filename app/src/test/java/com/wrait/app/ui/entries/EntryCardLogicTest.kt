package com.wrait.app.ui.entries

import com.wrait.app.domain.model.Entry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EntryCardLogicTest {

    @Test
    fun isAudioOnlyDraftCard_trueForAudioWithoutTranscript() {
        val entry = entry(
            rawTranscript = "",
            cleanedText = null,
            audioPath = "/tmp/audio.m4a",
        )

        assertTrue(entry.isAudioOnlyDraftCard())
    }

    @Test
    fun isAudioOnlyDraftCard_falseWhenRawTranscriptExists() {
        val entry = entry(
            rawTranscript = "hello",
            cleanedText = null,
            audioPath = "/tmp/audio.m4a",
        )

        assertFalse(entry.isAudioOnlyDraftCard())
    }

    @Test
    fun isAudioOnlyDraftCard_falseWhenCleanedTextExists() {
        val entry = entry(
            rawTranscript = "",
            cleanedText = "cleaned",
            audioPath = "/tmp/audio.m4a",
        )

        assertFalse(entry.isAudioOnlyDraftCard())
    }

    @Test
    fun entryCardDisplayText_prefersCleanedText() {
        val entry = entry(
            rawTranscript = "raw value",
            cleanedText = "cleaned value",
            audioPath = "/tmp/audio.m4a",
        )

        assertEquals("cleaned value", entryCardDisplayText(entry, "pending · will retry"))
    }

    @Test
    fun entryCardDisplayText_fallsBackToAudioDraftPreviewForAudioOnlyDraft() {
        val entry = entry(
            rawTranscript = "",
            cleanedText = null,
            audioPath = "/tmp/audio.m4a",
        )

        assertEquals("pending · will retry", entryCardDisplayText(entry, "pending · will retry"))
    }

    @Test
    fun entryCardDisplayText_usesFirstNonBlankLine() {
        val entry = entry(
            rawTranscript = "First line\nSecond line",
            cleanedText = null,
            audioPath = null,
        )

        assertEquals("First line", entryCardDisplayText(entry, "pending · will retry"))
    }

    private fun entry(
        rawTranscript: String,
        cleanedText: String?,
        audioPath: String?,
    ) = Entry(
        id = 1L,
        rawTranscript = rawTranscript,
        cleanedText = cleanedText,
        isDraft = true,
        language = "en-US",
        createdAt = 1_700_000_000_000L,
        wordCount = 0,
        audioPath = audioPath,
    )
}
