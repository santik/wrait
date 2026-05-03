package com.wrait.app.data.api

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.Headers
import io.ktor.http.HttpStatusCode
import io.ktor.http.Url
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

class WraitBackendClientTest {

    @Test
    fun register_201_returnsSuccess() = runTest {
        val engine = MockEngine { respond("", HttpStatusCode.Created, headersOf()) }
        val client = WraitBackendClient(engine)

        val result = client.register("a".repeat(64))

        assertEquals(RegistrationResult.Success, result)
    }

    @Test
    fun register_200_returnsSuccess() = runTest {
        val engine = MockEngine { respond("", HttpStatusCode.OK, headersOf()) }
        val client = WraitBackendClient(engine)

        val result = client.register("a".repeat(64))

        assertEquals(RegistrationResult.Success, result)
    }

    @Test
    fun register_400_returnsFailure() = runTest {
        val engine = MockEngine { respond("", HttpStatusCode.BadRequest, headersOf()) }
        val client = WraitBackendClient(engine)

        val result = client.register("a".repeat(64))

        assertTrue(result is RegistrationResult.Failure)
        assertEquals("http 400", (result as RegistrationResult.Failure).reason)
    }

    @Test
    fun register_429_returnsFailure() = runTest {
        val engine = MockEngine { respond("", HttpStatusCode.TooManyRequests, headersOf()) }
        val client = WraitBackendClient(engine)

        val result = client.register("a".repeat(64))

        assertTrue(result is RegistrationResult.Failure)
        assertEquals("http 429", (result as RegistrationResult.Failure).reason)
    }

    @Test
    fun register_500_returnsFailure() = runTest {
        val engine = MockEngine { respond("", HttpStatusCode.InternalServerError, headersOf()) }
        val client = WraitBackendClient(engine)

        val result = client.register("a".repeat(64))

        assertTrue(result is RegistrationResult.Failure)
        assertEquals("http 500", (result as RegistrationResult.Failure).reason)
    }

    @Test
    fun register_networkException_returnsFailure() = runTest {
        val engine = MockEngine { throw IOException("no route to host") }
        val client = WraitBackendClient(engine)

        val result = client.register("a".repeat(64))

        assertTrue(result is RegistrationResult.Failure)
        assertEquals("network error", (result as RegistrationResult.Failure).reason)
    }

    @Test
    fun register_sendsCorrectHeaders() = runTest {
        val deviceId = "a".repeat(64)
        var capturedHeaders: Headers? = null
        val engine = MockEngine { request ->
            capturedHeaders = request.headers
            respond("", HttpStatusCode.Created, headersOf())
        }
        val client = WraitBackendClient(engine)

        client.register(deviceId)

        assertNotNull(capturedHeaders)
        val headers = requireNotNull(capturedHeaders)
        assertEquals(deviceId, headers["X-Device-Id"])
        // PROXY_SECRET is "" in test builds (no local.properties in CI)
        assertNotNull(headers["X-Proxy-Secret"])
    }

    @Test
    fun cleanupTranscript_200_returnsCleanedText() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"cleanedText":"hello world"}""",
                status = HttpStatusCode.OK,
                headers = headersOf(),
            )
        }
        val client = WraitBackendClient(engine)

        val result = client.cleanupTranscript(
            transcript = "um hello world",
            language = "en-US",
            deviceId = "a".repeat(64),
        )

        assertTrue(result is CleanupResult.Success)
        assertEquals("hello world", (result as CleanupResult.Success).cleanedText)
    }

    @Test
    fun cleanupTranscript_non2xx_returnsFailure() = runTest {
        val engine = MockEngine { respond("", HttpStatusCode.InternalServerError, headersOf()) }
        val client = WraitBackendClient(engine)

        val result = client.cleanupTranscript(
            transcript = "hello world",
            language = "en-US",
            deviceId = "a".repeat(64),
        )

        assertTrue(result is CleanupResult.Failure)
        assertEquals("http 500", (result as CleanupResult.Failure).reason)
    }

    @Test
    fun cleanupTranscript_networkException_returnsFailure() = runTest {
        val engine = MockEngine { throw IOException("no route to host") }
        val client = WraitBackendClient(engine)

        val result = client.cleanupTranscript(
            transcript = "hello world",
            language = "en-US",
            deviceId = "a".repeat(64),
        )

        assertTrue(result is CleanupResult.Failure)
        assertEquals("network error", (result as CleanupResult.Failure).reason)
    }

    @Test
    fun transcribe_usesLanguageDetectionParams_withoutLanguageOrPunctuate() = runTest {
        var capturedUrl: Url? = null
        var capturedHeaders: Headers? = null
        val engine = MockEngine { request ->
            capturedUrl = request.url
            capturedHeaders = request.headers
            respond("{}", HttpStatusCode.OK, headersOf())
        }
        val client = WraitBackendClient(engine, overrideDeviceId = "device-123")

        client.transcribe(audioBytes = byteArrayOf(1, 2, 3), selectedLanguageCode = "en-US")

        val url = requireNotNull(capturedUrl)
        assertEquals("/api/transcribe", url.encodedPath)
        assertEquals("nova-3-general", url.parameters["model"])
        assertEquals("true", url.parameters["smart_format"])
        assertEquals("true", url.parameters["detect_language"])
        assertEquals("false", url.parameters["utterances"])
        assertEquals("true", url.parameters["filler_words"])
        assertNull(url.parameters["language"])
        assertNull(url.parameters["punctuate"])

        val headers = requireNotNull(capturedHeaders)
        assertEquals("device-123", headers["X-Device-Id"])
    }
}
