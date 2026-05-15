package com.wrait.app.data.api

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

@OptIn(ExperimentalCoroutinesApi::class)
class OkHttpTranscribeUploadClientTest {

    private fun TestScope.createClient(
        okHttpClient: OkHttpClient = OkHttpClient(),
        overrideDeviceId: String = "device-123",
        overrideBaseUrl: String,
        overrideProxySecret: String = TEST_PROXY_SECRET,
    ): OkHttpTranscribeUploadClient {
        return OkHttpTranscribeUploadClient(
            okHttpClient = okHttpClient,
            overrideDeviceId = overrideDeviceId,
            overrideBaseUrl = overrideBaseUrl,
            overrideProxySecret = overrideProxySecret,
            ioDispatcher = StandardTestDispatcher(testScheduler),
        )
    }

    @Test
    fun transcribe_sendsBinaryBodyAndHeaders() = runTest {
        MockWebServer().use { server ->
            server.enqueue(
                MockResponse()
                    .setResponseCode(200)
                    .setHeader("Content-Type", "application/json")
                    .setBody("""{"transcript":"hello","detected_language":"en-US"}"""),
            )
            val client = createClient(overrideBaseUrl = server.url("/").toString())
            val audioFile = createAudioFile(byteArrayOf(1, 2, 3))

            val response = audioFile.useAndDelete {
                client.transcribe(audioFile = it)
            }

            val request = server.takeRequest()
            assertEquals("/api/transcribe", request.path)
            assertEquals("device-123", request.getHeader("X-Device-Id"))
            assertEquals(TEST_PROXY_SECRET, request.getHeader("X-Proxy-Secret"))
            assertEquals("audio/mp4", request.getHeader("Content-Type"))
            assertArrayEquals(byteArrayOf(1, 2, 3), request.body.readByteArray())
            assertEquals(200, response.statusCode)
            assertEquals("""{"transcript":"hello","detected_language":"en-US"}""", response.body)
        }
    }

    @Test
    fun transcribe_withoutDeviceIdSource_throwsSpecificException() = runTest {
        val client = OkHttpTranscribeUploadClient(
            okHttpClient = OkHttpClient(),
            overrideBaseUrl = "https://example.com",
            overrideProxySecret = TEST_PROXY_SECRET,
            ioDispatcher = StandardTestDispatcher(testScheduler),
        )
        val audioFile = createAudioFile(byteArrayOf(7, 8, 9))

        val error = runCatching {
            audioFile.useAndDelete {
                client.transcribe(audioFile = it)
            }
        }.exceptionOrNull()

        assertTrue(error is DeviceIdUnavailableException)
    }

    private fun createAudioFile(bytes: ByteArray): File {
        return File.createTempFile("transcribe-test", ".m4a").apply {
            writeBytes(bytes)
        }
    }

    private inline fun <T> File.useAndDelete(block: (File) -> T): T {
        return try {
            block(this)
        } finally {
            delete()
        }
    }

    private companion object {
        const val TEST_PROXY_SECRET = "proxy-secret"
    }
}
