package com.wrait.app.ui.entries

import com.wrait.app.domain.model.Entry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class EntryShareLogicTest {

    @Test
    fun shareableText_usesCleanedTextWhenPresent() {
        val entry = testEntry(
            cleanedText = "cleaned",
            rawTranscript = "raw",
            isDraft = false,
        )

        assertEquals("cleaned", entry.shareableTextForShare())
    }

    @Test
    fun shareableText_fallsBackToRawTranscriptWhenCleanedMissing() {
        val entry = testEntry(
            cleanedText = null,
            rawTranscript = "raw",
            isDraft = false,
        )

        assertEquals("raw", entry.shareableTextForShare())
    }

    @Test
    fun shareableText_returnsNullForDraftEntries() {
        val entry = testEntry(
            cleanedText = "cleaned",
            rawTranscript = "raw",
            isDraft = true,
        )

        assertNull(entry.shareableTextForShare())
    }

    @Test
    fun shareableText_returnsNullWhenNoText() {
        val entry = testEntry(
            cleanedText = "   ",
            rawTranscript = "",
            isDraft = false,
        )

        assertNull(entry.shareableTextForShare())
    }

    @Test
    fun buildShareMessage_formatsDateAndBodyWithBlankLine() {
        val message = buildShareMessage(
            formattedDate = "Wednesday, 9 April · 14:23",
            body = "The meeting was difficult.",
        )

        assertEquals(
            "Wednesday, 9 April · 14:23\n\nThe meeting was difficult.",
            message,
        )
    }

    private fun testEntry(
        cleanedText: String?,
        rawTranscript: String,
        isDraft: Boolean,
    ) = Entry(
        id = 1L,
        rawTranscript = rawTranscript,
        cleanedText = cleanedText,
        isDraft = isDraft,
        language = "en-US",
        createdAt = 1_700_000_000_000L,
        wordCount = 1,
        audioPath = null,
    )
}
