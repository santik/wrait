package com.wrait.app.data.api

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.InterruptedIOException
import java.net.SocketTimeoutException

class BackendErrorParserTest {

    @Test
    fun parseRaw_returnsBackendErrorMessage() {
        assertEquals("missing proxy secret", BackendErrorParser.parseRaw("""{"error":"missing proxy secret"}"""))
    }

    @Test
    fun parseRaw_returnsNullForInvalidPayload() {
        assertNull(BackendErrorParser.parseRaw("""{"message":"oops"}"""))
        assertNull(BackendErrorParser.parseRaw("not-json"))
        assertNull(BackendErrorParser.parseRaw(null))
    }

    @Test
    fun isNetworkTimeout_matchesTimeoutTypes() {
        assertTrue(SocketTimeoutException("timeout").isNetworkTimeout())
        assertTrue(InterruptedIOException("timeout").isNetworkTimeout())
    }
}
