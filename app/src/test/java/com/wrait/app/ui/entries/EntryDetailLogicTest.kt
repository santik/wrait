package com.wrait.app.ui.entries

import com.wrait.app.domain.model.Entry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class EntryDetailLogicTest {

    @Test
    fun entryDetailDevDraftText_returnsDraftLineWhenEnabled() {
        val entry = entry(
            rawTranscript = "raw draft line\nnext line",
            cleanedText = "cleaned text line",
            isDraft = false,
        )

        assertEquals("draft: raw draft line", entryDetailDevDraftText(entry, showDevDraft = true))
    }

    @Test
    fun entryDetailDevDraftText_returnsNullWhenDisabled() {
        val entry = entry(
            rawTranscript = "raw draft line",
            cleanedText = "cleaned text line",
            isDraft = false,
        )

        assertNull(entryDetailDevDraftText(entry, showDevDraft = false))
    }

    @Test
    fun entryDetailDevDraftText_returnsNullForDraftEntry() {
        val entry = entry(
            rawTranscript = "draft body",
            cleanedText = null,
            isDraft = true,
        )

        assertNull(entryDetailDevDraftText(entry, showDevDraft = true))
    }

    @Test
    fun entryDetailDevDraftText_returnsDraftLineWhenCleanedMatchesRaw() {
        val entry = entry(
            rawTranscript = "same text",
            cleanedText = "same text",
            isDraft = false,
        )

        assertEquals("draft: same text", entryDetailDevDraftText(entry, showDevDraft = true))
    }

    private fun entry(
        rawTranscript: String,
        cleanedText: String?,
        isDraft: Boolean,
    ) = Entry(
        id = 1L,
        rawTranscript = rawTranscript,
        cleanedText = cleanedText,
        isDraft = isDraft,
        language = "en-US",
        createdAt = 1_700_000_000_000L,
        wordCount = 0,
        audioPath = null,
    )
}
