package com.wrait.app.data.api

import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.wrait.app.data.api.generated.api.DefaultApi
import com.wrait.app.data.api.generated.auth.ApiKeyAuth
import com.wrait.app.data.api.generated.infrastructure.ApiClient
import com.wrait.app.data.api.generated.infrastructure.Serializer
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import retrofit2.converter.scalars.ScalarsConverterFactory
import java.io.File
import com.wrait.app.data.speech.TranscriptionResult

@RunWith(AndroidJUnit4::class)
@OptIn(ExperimentalCoroutinesApi::class)
class WraitBackendClientAndroidTest {

    @Test
    fun transcribeAudio_sendsMultipartBodyAndHeaders_onDevice() = runTest {
        MockWebServer().use { server ->
            server.enqueue(
                MockResponse()
                    .setResponseCode(200)
                    .setHeader("Content-Type", "application/json")
                    .setBody("""{"transcript":"hello","detected_language":"en-US"}"""),
            )
            val client = WraitBackendClientTestFactory.create(createRealApi(server), "a".repeat(64))
            val audioFile = createAudioFile("android-audio".toByteArray())

            val response = audioFile.useAndDelete {
                client.transcribeAudio(audioFile = it)
            }

            val request = server.takeRequest()
            val multipartBody = request.body.readUtf8()
            assertEquals("/api/transcribe", request.path)
            assertEquals("a".repeat(64), request.getHeader("X-Device-Id"))
            assertEquals(TEST_PROXY_SECRET, request.getHeader("X-Proxy-Secret"))
            assertTrue(request.getHeader("Content-Type")!!.startsWith("multipart/form-data; boundary="))
            assertTrue(multipartBody.contains("name=\"audio\""))
            assertTrue(multipartBody.contains("filename=\"${audioFile.name}\""))
            assertTrue(multipartBody.contains("Content-Type: audio/mp4"))
            assertTrue(multipartBody.contains("android-audio"))
            assertEquals(
                TranscriptionResult.Success(
                    transcript = "hello",
                    detectedLanguage = "en-US",
                ),
                response,
            )
        }
    }

    @Test
    fun transcribeAudio_sendsRealBinaryAudioFixture_onDevice() = runTest {
        MockWebServer().use { server ->
            server.enqueue(
                MockResponse()
                    .setResponseCode(200)
                    .setHeader("Content-Type", "application/json")
                    .setBody("""{"transcript":"fixture","detected_language":"en-US"}"""),
            )
            val client = WraitBackendClientTestFactory.create(createRealApi(server), "b".repeat(64))
            val audioFile = createFixtureAudioFile()

            val response = audioFile.useAndDelete {
                client.transcribeAudio(audioFile = it)
            }

            val request = server.takeRequest()
            val multipartBody = request.body.readByteArray()
            val multipartText = String(multipartBody, Charsets.ISO_8859_1)
            assertEquals("/api/transcribe", request.path)
            assertEquals("b".repeat(64), request.getHeader("X-Device-Id"))
            assertEquals(TEST_PROXY_SECRET, request.getHeader("X-Proxy-Secret"))
            assertTrue(request.getHeader("Content-Type")!!.startsWith("multipart/form-data; boundary="))
            assertTrue(multipartText.contains("Content-Type: audio/wav"))
            assertTrue(multipartText.contains("filename=\"${audioFile.name}\""))
            assertTrue(multipartBody.size > fixtureAudioBytes().size)
            assertEquals(
                TranscriptionResult.Success(
                    transcript = "fixture",
                    detectedLanguage = "en-US",
                ),
                response,
            )
        }
    }

    private fun createRealApi(server: MockWebServer): DefaultApi {
        return ApiClient(
            baseUrl = server.url("/").toString(),
            okHttpClientBuilder = OkHttpClient.Builder(),
            converterFactories = listOf(
                ScalarsConverterFactory.create(),
                Serializer.kotlinxSerializationJson.asConverterFactory("application/json".toMediaType()),
            ),
        ).apply {
            addAuthorization(
                authName = "ProxySecretHeader",
                authorization = ApiKeyAuth(
                    location = "header",
                    paramName = "X-Proxy-Secret",
                    apiKey = TEST_PROXY_SECRET,
                ),
            )
        }.createService(DefaultApi::class.java)
    }

    private fun createAudioFile(bytes: ByteArray): File {
        return File.createTempFile(
            "transcribe-android-test",
            ".${BackendAudioUploadConfig.RECORDED_AUDIO_FILE_EXTENSION}",
        ).apply {
            writeBytes(bytes)
        }
    }

    private fun createFixtureAudioFile(): File {
        return File.createTempFile("fixture-tone", ".wav").apply {
            writeBytes(fixtureAudioBytes())
        }
    }

    private fun fixtureAudioBytes(): ByteArray {
        return InstrumentationRegistry.getInstrumentation()
            .context
            .assets
            .open("audio/fixture-tone.wav")
            .use { it.readBytes() }
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
