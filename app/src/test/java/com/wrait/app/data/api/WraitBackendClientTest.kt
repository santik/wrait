package com.wrait.app.data.api

import com.wrait.app.data.api.generated.api.DefaultApi
import com.wrait.app.data.api.generated.auth.ApiKeyAuth
import com.wrait.app.data.api.generated.infrastructure.ApiClient
import com.wrait.app.data.api.generated.infrastructure.Serializer
import com.wrait.app.data.api.generated.model.CleanupRequest
import com.wrait.app.data.api.generated.model.CleanupResponse
import com.wrait.app.data.api.generated.model.RegisterResponse
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.ResponseBody.Companion.toResponseBody
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import retrofit2.Response
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import retrofit2.converter.scalars.ScalarsConverterFactory
import java.io.IOException
import java.net.SocketTimeoutException

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class WraitBackendClientTest {

    private fun TestScope.createClient(
        api: DefaultApi,
    ): WraitBackendClient = WraitBackendClient(api)

    @Test
    fun register_201_returnsSuccess() = runTest {
        val client = createClient(
            api = fakeApi(
                register = { Response.success(RegisterResponse(ok = true)) },
            ),
        )

        val result = client.register("a".repeat(64))

        assertEquals(RegistrationResult.Success, result)
    }

    @Test
    fun register_200_returnsSuccess() = runTest {
        val client = createClient(
            api = fakeApi(
                register = { Response.success(RegisterResponse(ok = true)) },
            ),
        )

        val result = client.register("a".repeat(64))

        assertEquals(RegistrationResult.Success, result)
    }

    @Test
    fun register_400_returnsFailure() = runTest {
        val client = createClient(
            api = fakeApi(
                register = { errorResponse(400) },
            ),
        )

        val result = client.register("a".repeat(64))

        assertTrue(result is RegistrationResult.Failure)
        assertEquals("http 400", (result as RegistrationResult.Failure).reason)
    }

    @Test
    fun register_networkException_returnsFailure() = runTest {
        val client = createClient(
            api = fakeApi(
                register = { throw IOException("no route to host") },
            ),
        )

        val result = client.register("a".repeat(64))

        assertTrue(result is RegistrationResult.Failure)
        assertEquals("network error", (result as RegistrationResult.Failure).reason)
    }

    @Test
    fun register_timeout_returnsFailure() = runTest {
        val client = createClient(
            api = fakeApi(
                register = { throw SocketTimeoutException("timeout") },
            ),
        )

        val result = client.register("a".repeat(64))

        assertTrue(result is RegistrationResult.Failure)
        assertEquals("timeout", (result as RegistrationResult.Failure).reason)
    }

    @Test
    fun register_retriesTransientHttpFailures() = runTest {
        var attempts = 0
        val client = createClient(
            api = fakeApi(
                register = {
                    attempts += 1
                    if (attempts < 3) errorResponse(503) else Response.success(RegisterResponse(ok = true))
                },
            ),
        )

        val result = client.register("a".repeat(64))

        assertEquals(3, attempts)
        assertEquals(RegistrationResult.Success, result)
    }

    @Test
    fun register_unexpectedException_returnsUnexpectedError() = runTest {
        val client = createClient(
            api = fakeApi(
                register = { throw IllegalStateException("boom") },
            ),
        )

        val result = client.register("a".repeat(64))

        assertTrue(result is RegistrationResult.Failure)
        assertEquals("unexpected error", (result as RegistrationResult.Failure).reason)
    }

    @Test
    fun register_sendsCorrectHeaders() = runTest {
        MockWebServer().use { server ->
            server.enqueue(MockResponse().setResponseCode(201).setBody("""{"ok":true}"""))
            val client = createClient(api = createRealApi(server))
            val deviceId = "a".repeat(64)

            client.register(deviceId)

            val request = server.takeRequest()
            assertEquals("/api/register", request.path)
            assertEquals(deviceId, request.getHeader("X-Device-Id"))
            assertEquals(TEST_PROXY_SECRET, request.getHeader("X-Proxy-Secret"))
        }
    }

    @Test
    fun cleanupTranscript_200_returnsCleanedText() = runTest {
        val client = createClient(
            api = fakeApi(
                cleanup = { _, request ->
                    assertEquals("um hello world", request.transcript)
                    assertEquals(CleanupRequest.Language.enMinusUS, request.language)
                    Response.success(CleanupResponse(cleanedText = "hello world", wasTruncated = false))
                },
            ),
        )

        val result = client.cleanupTranscript(
            transcript = "um hello world",
            language = "en-US",
            deviceId = "a".repeat(64),
        )

        assertTrue(result is CleanupResult.Success)
        assertEquals("hello world", (result as CleanupResult.Success).cleanedText)
    }

    @Test
    fun cleanupTranscript_unsupportedLanguage_returnsFailure() = runTest {
        val client = createClient(api = fakeApi())

        val result = client.cleanupTranscript(
            transcript = "hello world",
            language = "eo",
            deviceId = "a".repeat(64),
        )

        assertTrue(result is CleanupResult.Failure)
        assertEquals("unsupported language", (result as CleanupResult.Failure).reason)
    }

    @Test
    fun cleanupTranscript_uppercaseNorwegian_mapsToGeneratedEnum() = runTest {
        val client = createClient(
            api = fakeApi(
                cleanup = { _, request ->
                    assertEquals(CleanupRequest.Language.no, request.language)
                    Response.success(CleanupResponse(cleanedText = "hei", wasTruncated = false))
                },
            ),
        )

        val result = client.cleanupTranscript(
            transcript = "hei verden",
            language = "NO",
            deviceId = "a".repeat(64),
        )

        assertTrue(result is CleanupResult.Success)
        assertEquals("hei", (result as CleanupResult.Success).cleanedText)
    }

    @Test
    fun cleanupTranscript_non2xx_returnsFailure() = runTest {
        val client = createClient(
            api = fakeApi(
                cleanup = { _, _ -> errorResponse(500) },
            ),
        )

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
        val client = createClient(
            api = fakeApi(
                cleanup = { _, _ -> throw IOException("no route to host") },
            ),
        )

        val result = client.cleanupTranscript(
            transcript = "hello world",
            language = "en-US",
            deviceId = "a".repeat(64),
        )

        assertTrue(result is CleanupResult.Failure)
        assertEquals("network error", (result as CleanupResult.Failure).reason)
    }

    @Test
    fun cleanupTranscript_unexpectedException_returnsUnexpectedError() = runTest {
        val client = createClient(
            api = fakeApi(
                cleanup = { _, _ -> throw IllegalStateException("boom") },
            ),
        )

        val result = client.cleanupTranscript(
            transcript = "hello world",
            language = "en-US",
            deviceId = "a".repeat(64),
        )

        assertTrue(result is CleanupResult.Failure)
        assertEquals("unexpected error", (result as CleanupResult.Failure).reason)
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

    private fun fakeApi(
        register: suspend (String) -> Response<RegisterResponse> = { Response.success(RegisterResponse(ok = true)) },
        cleanup: suspend (String, CleanupRequest) -> Response<CleanupResponse> =
            { _, _ -> Response.success(CleanupResponse(cleanedText = "ok", wasTruncated = false)) },
    ): DefaultApi {
        return object : DefaultApi {
            override suspend fun cleanupTranscript(
                xDeviceId: String,
                cleanupRequest: CleanupRequest,
            ): Response<CleanupResponse> = cleanup(xDeviceId, cleanupRequest)

            override suspend fun registerDevice(
                xDeviceId: String,
            ): Response<RegisterResponse> = register(xDeviceId)

            override suspend fun transcribeAudio(
                xDeviceId: String,
                body: ByteArray,
            ): Response<com.wrait.app.data.api.generated.model.TranscribeResponse> {
                error("Transcribe is owned by OkHttpTranscribeUploadClient tests")
            }
        }
    }

    private fun <T> errorResponse(code: Int): Response<T> {
        return Response.error(
            code,
            """{"error":"boom"}""".toResponseBody("application/json".toMediaType()),
        )
    }

    private companion object {
        const val TEST_PROXY_SECRET = "proxy-secret"
    }
}
