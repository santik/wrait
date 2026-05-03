package com.wrait.app.data.api

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DeepgramRequestParamsTest {

    @Test
    fun asPairs_matchesDetectionOnlyContract() {
        val pairs = DeepgramRequestParams.asPairs()
        val params = pairs.toMap()

        assertEquals("nova-3-general", params["model"])
        assertEquals("true", params["smart_format"])
        assertEquals("true", params["detect_language"])
        assertEquals("false", params["utterances"])
        assertEquals("true", params["filler_words"])
        assertFalse(params.containsKey("language"))
        assertFalse(params.containsKey("punctuate"))
        assertEquals(5, params.size)
        assertEquals(params.size, pairs.size)
        assertTrue(params.keys.containsAll(listOf("model", "smart_format", "detect_language", "utterances", "filler_words")))
    }
}
