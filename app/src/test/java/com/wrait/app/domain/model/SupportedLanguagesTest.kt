package com.wrait.app.domain.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SupportedLanguagesTest {

    @Test
    fun normalizeDetectedLanguageCode_acceptsBaseLanguage() {
        assertEquals("fr", normalizeDetectedLanguageCode("fr"))
    }

    @Test
    fun normalizeDetectedLanguageCode_acceptsLocaleTag() {
        assertEquals("pt-BR", normalizeDetectedLanguageCode("pt-BR"))
    }

    @Test
    fun normalizeDetectedLanguageCode_normalizesUnderscores() {
        assertEquals("zh-CN", normalizeDetectedLanguageCode("zh_CN"))
    }

    @Test
    fun normalizeDetectedLanguageCode_rejectsInvalidTag() {
        assertNull(normalizeDetectedLanguageCode("1234"))
    }

    @Test
    fun normalizeDetectedLanguageCode_rejectsBlankValue() {
        assertNull(normalizeDetectedLanguageCode(" "))
    }
}
