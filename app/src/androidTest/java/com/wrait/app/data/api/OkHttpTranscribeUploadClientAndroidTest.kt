package com.wrait.app.data.api

import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
@OptIn(ExperimentalCoroutinesApi::class)
class OkHttpTranscribeUploadClientAndroidTest {

    @Test
    fun transcribe_sendsBinaryBodyAndHeaders_onDevice() = runTest {
        MockWebServer().use { server ->
            server.enqueue(
                MockResponse()
                    .setResponseCode(200)
                    .setHeader("Content-Type", "application/json")
                    .setBody("""{"transcript":"hello","detected_language":"en-US"}"""),
            )
            val client = OkHttpTranscribeUploadClient(
                okHttpClient = OkHttpClient(),
                overrideDeviceId = "device-android-test",
                overrideBaseUrl = server.url("/").toString(),
                overrideProxySecret = TEST_PROXY_SECRET,
                ioDispatcher = StandardTestDispatcher(testScheduler),
            )
            val audioFile = createAudioFile(byteArrayOf(4, 5, 6))

            audioFile.useAndDelete {
                client.transcribe(it)
            }

            val request = server.takeRequest()
            assertEquals("/api/transcribe", request.path)
            assertEquals("device-android-test", request.getHeader("X-Device-Id"))
            assertEquals(TEST_PROXY_SECRET, request.getHeader("X-Proxy-Secret"))
            assertEquals("audio/mp4", request.getHeader("Content-Type"))
            assertArrayEquals(byteArrayOf(4, 5, 6), request.body.readByteArray())
        }
    }

    private fun createAudioFile(bytes: ByteArray): File {
        return File.createTempFile("transcribe-android-test", ".m4a").apply {
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
