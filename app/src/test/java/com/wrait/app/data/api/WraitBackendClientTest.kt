package com.wrait.app.data.api

import com.wrait.app.data.api.generated.api.DefaultApi
import com.wrait.app.data.api.generated.auth.ApiKeyAuth
import com.wrait.app.data.api.generated.infrastructure.ApiClient
import com.wrait.app.data.api.generated.infrastructure.Serializer
import com.wrait.app.data.api.generated.model.CleanupRequest
import com.wrait.app.data.api.generated.model.CleanupResponse
import com.wrait.app.data.api.generated.model.RecordQuota
import com.wrait.app.data.api.generated.model.RegisterResponse
import com.wrait.app.data.api.generated.model.TranscribeResponse
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.ResponseBody.Companion.toResponseBody
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import retrofit2.Response
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import retrofit2.converter.scalars.ScalarsConverterFactory
import java.io.File
import java.io.IOException
import java.net.SocketTimeoutException
import java.time.OffsetDateTime
import com.wrait.app.data.speech.TranscriptionFailureReason
import com.wrait.app.data.speech.TranscriptionResult

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class WraitBackendClientTest {

    private fun TestScope.createClient(
        api: DefaultApi,
        deviceId: String = "a".repeat(64),
    ): WraitBackendClient = WraitBackendClientTestFactory.create(api, deviceId)

    @Test
    fun register_201_returnsSuccess() = runTest {
        val client = createClient(
            api = fakeApi(
                register = { Response.success(RegisterResponse(ok = true)) },
            ),
        )

        val result = client.register("a".repeat(64))

        assertEquals(RegistrationResult.Success(), result)
    }

    @Test
    fun register_200_returnsSuccess() = runTest {
        val client = createClient(
            api = fakeApi(
                register = { Response.success(RegisterResponse(ok = true)) },
            ),
        )

        val result = client.register("a".repeat(64))

        assertEquals(RegistrationResult.Success(), result)
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
        assertEquals(RegistrationResult.Success(), result)
    }

    @Test
    fun register_successWithQuota_returnsMappedQuota() = runTest {
        val client = createClient(
            api = fakeApi(
                register = {
                    Response.success(
                        RegisterResponse(
                            ok = true,
                            quota = createGeneratedQuota(limit = 10, count = 3, remaining = 7),
                        ),
                    )
                },
            ),
        )

        val result = client.register("a".repeat(64))

        assertEquals(
            RegistrationResult.Success(
                quota = RecordQuotaState(
                    limit = 10,
                    count = 3,
                    remaining = 7,
                    resetAt = OffsetDateTime.parse(TEST_RESET_AT),
                ),
            ),
            result,
        )
    }

    @Test
    fun register_successWithInvalidQuota_ignoresQuota() = runTest {
        val client = createClient(
            api = fakeApi(
                register = {
                    Response.success(
                        RegisterResponse(
                            ok = true,
                            quota = createGeneratedQuota(limit = 10, count = 11, remaining = 7),
                        ),
                    )
                },
            ),
        )

        val result = client.register("a".repeat(64))

        assertEquals(RegistrationResult.Success(quota = null), result)
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
    fun cleanupTranscript_successWithQuota_returnsMappedQuota() = runTest {
        val client = createClient(
            api = fakeApi(
                cleanup = { _, _ ->
                    Response.success(
                        CleanupResponse(
                            cleanedText = "hello world",
                            wasTruncated = false,
                            quota = createGeneratedQuota(limit = 10, count = 4, remaining = 6),
                        ),
                    )
                },
            ),
        )

        val result = client.cleanupTranscript(
            transcript = "um hello world",
            language = "en-US",
            deviceId = "a".repeat(64),
        )

        assertEquals(
            CleanupResult.Success(
                cleanedText = "hello world",
                quota = RecordQuotaState(
                    limit = 10,
                    count = 4,
                    remaining = 6,
                    resetAt = OffsetDateTime.parse(TEST_RESET_AT),
                ),
            ),
            result,
        )
    }

    @Test
    fun cleanupTranscript_successWithZeroRemaining_keepsQuota() = runTest {
        val client = createClient(
            api = fakeApi(
                cleanup = { _, _ ->
                    Response.success(
                        CleanupResponse(
                            cleanedText = "hello world",
                            wasTruncated = false,
                            quota = createGeneratedQuota(limit = 10, count = 10, remaining = 0),
                        ),
                    )
                },
            ),
        )

        val result = client.cleanupTranscript(
            transcript = "um hello world",
            language = "en-US",
            deviceId = "a".repeat(64),
        )

        assertEquals(
            CleanupResult.Success(
                cleanedText = "hello world",
                quota = RecordQuotaState(
                    limit = 10,
                    count = 10,
                    remaining = 0,
                    resetAt = OffsetDateTime.parse(TEST_RESET_AT),
                ),
            ),
            result,
        )
    }

    @Test
    fun cleanupTranscript_successWithInvalidQuota_ignoresQuota() = runTest {
        val client = createClient(
            api = fakeApi(
                cleanup = { _, _ ->
                    Response.success(
                        CleanupResponse(
                            cleanedText = "hello world",
                            wasTruncated = false,
                            quota = createGeneratedQuota(limit = 10, count = 4, remaining = 12),
                        ),
                    )
                },
            ),
        )

        val result = client.cleanupTranscript(
            transcript = "um hello world",
            language = "en-US",
            deviceId = "a".repeat(64),
        )

        assertEquals(
            CleanupResult.Success(
                cleanedText = "hello world",
                quota = null,
            ),
            result,
        )
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
    fun cleanupTranscript_429_returnsFailureWithQuota() = runTest {
        val client = createClient(
            api = fakeApi(
                cleanup = { _, _ ->
                    errorResponse(
                        code = 429,
                        body = """
                            {"error":"Daily record limit exceeded","quota":{"limit":10,"count":10,"remaining":0,"resetAt":"$TEST_RESET_AT"}}
                        """.trimIndent(),
                    )
                },
            ),
        )

        val result = client.cleanupTranscript(
            transcript = "hello world",
            language = "en-US",
            deviceId = "a".repeat(64),
        )

        assertEquals(
            CleanupResult.Failure(
                reason = "http 429",
                quota = RecordQuotaState(
                    limit = 10,
                    count = 10,
                    remaining = 0,
                    resetAt = OffsetDateTime.parse(TEST_RESET_AT),
                ),
            ),
            result,
        )
    }

    @Test
    fun cleanupTranscript_429_withInvalidQuota_ignoresQuota() = runTest {
        val client = createClient(
            api = fakeApi(
                cleanup = { _, _ ->
                    errorResponse(
                        code = 429,
                        body = """
                            {"error":"Daily record limit exceeded","quota":{"limit":10,"count":10,"remaining":11,"resetAt":"$TEST_RESET_AT"}}
                        """.trimIndent(),
                    )
                },
            ),
        )

        val result = client.cleanupTranscript(
            transcript = "hello world",
            language = "en-US",
            deviceId = "a".repeat(64),
        )

        assertEquals(
            CleanupResult.Failure(
                reason = "http 429",
                quota = null,
            ),
            result,
        )
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

    @Test
    fun transcribeAudio_200_returnsParsedResponse() = runTest {
        MockWebServer().use { server ->
            server.enqueue(
                MockResponse()
                    .setResponseCode(200)
                    .setHeader("Content-Type", "application/json")
                    .setBody("""{"transcript":"hello","detected_language":"en-US"}"""),
            )
            val client = createClient(
                api = createRealApi(server),
                deviceId = "a".repeat(64),
            )
            val audioFile = createAudioFile("hello-audio".toByteArray())

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
            assertTrue(multipartBody.contains("hello-audio"))
            assertEquals(
                TranscriptionResult.Success(
                    transcript = "hello",
                    detectedLanguage = "en-US",
                    quota = null,
                ),
                response,
            )
        }
    }

    @Test
    fun transcribeAudio_usesMultipartPartNamedAudio() = runTest {
        MockWebServer().use { server ->
            server.enqueue(
                MockResponse()
                    .setResponseCode(200)
                    .setHeader("Content-Type", "application/json")
                    .setBody("""{"transcript":"hello","detected_language":"en-US"}"""),
            )
            val client = createClient(
                api = createRealApi(server),
                deviceId = "b".repeat(64),
            )
            val audioFile = createAudioFile("bytes".toByteArray())

            audioFile.useAndDelete {
                client.transcribeAudio(audioFile = it)
            }

            val request = server.takeRequest()
            val contentDispositionLine = request.body.readUtf8()
                .lineSequence()
                .firstOrNull { it.startsWith("Content-Disposition:") }
            assertNotNull(contentDispositionLine)
            assertTrue(contentDispositionLine!!.contains("name=\"audio\""))
        }
    }

    @Test
    fun transcribeAudio_m4aUsesAudioMp4ContentType() = runTest {
        assertMultipartContentTypeForExtension(
            extension = ".m4a",
            expectedContentType = "Content-Type: audio/mp4",
        )
    }

    @Test
    fun transcribeAudio_wavUsesAudioWavContentType() = runTest {
        assertMultipartContentTypeForExtension(
            extension = ".wav",
            expectedContentType = "Content-Type: audio/wav",
        )
    }

    @Test
    fun transcribeAudio_webmUsesAudioWebmContentType() = runTest {
        assertMultipartContentTypeForExtension(
            extension = ".webm",
            expectedContentType = "Content-Type: audio/webm",
        )
    }

    @Test
    fun transcribeAudio_unknownExtensionFallsBackToAudioMp4() = runTest {
        assertMultipartContentTypeForExtension(
            extension = ".bin",
            expectedContentType = "Content-Type: audio/mp4",
        )
    }

    @Test
    fun transcribeAudio_blankTranscript_returnsNothingCaught() = runTest {
        val client = createClient(
            api = fakeApi(
                transcribe = { _, _ ->
                    Response.success(
                        TranscribeResponse(
                            transcript = "   ",
                            detectedLanguage = "en-US",
                        ),
                    )
                },
            ),
            deviceId = "c".repeat(64),
        )

        val result = createAudioFile("bytes".toByteArray()).useAndDelete {
            client.transcribeAudio(it)
        }

        assertEquals(
            TranscriptionResult.Failure(TranscriptionFailureReason.NothingCaught),
            result,
        )
    }

    @Test
    fun transcribeAudio_successWithQuota_returnsMappedQuota() = runTest {
        val client = createClient(
            api = fakeApi(
                transcribe = { _, _ ->
                    Response.success(
                        TranscribeResponse(
                            transcript = "hello",
                            detectedLanguage = "en-US",
                            quota = createGeneratedQuota(limit = 10, count = 2, remaining = 8),
                        ),
                    )
                },
            ),
        )

        val result = createAudioFile("bytes".toByteArray()).useAndDelete {
            client.transcribeAudio(it)
        }

        assertEquals(
            TranscriptionResult.Success(
                transcript = "hello",
                detectedLanguage = "en-US",
                quota = RecordQuotaState(
                    limit = 10,
                    count = 2,
                    remaining = 8,
                    resetAt = OffsetDateTime.parse(TEST_RESET_AT),
                ),
            ),
            result,
        )
    }

    @Test
    fun transcribeAudio_successWithZeroRemaining_keepsQuota() = runTest {
        val client = createClient(
            api = fakeApi(
                transcribe = { _, _ ->
                    Response.success(
                        TranscribeResponse(
                            transcript = "hello",
                            detectedLanguage = "en-US",
                            quota = createGeneratedQuota(limit = 10, count = 10, remaining = 0),
                        ),
                    )
                },
            ),
        )

        val result = createAudioFile("bytes".toByteArray()).useAndDelete {
            client.transcribeAudio(it)
        }

        assertEquals(
            TranscriptionResult.Success(
                transcript = "hello",
                detectedLanguage = "en-US",
                quota = RecordQuotaState(
                    limit = 10,
                    count = 10,
                    remaining = 0,
                    resetAt = OffsetDateTime.parse(TEST_RESET_AT),
                ),
            ),
            result,
        )
    }

    @Test
    fun transcribeAudio_successWithInvalidQuota_ignoresQuota() = runTest {
        val client = createClient(
            api = fakeApi(
                transcribe = { _, _ ->
                    Response.success(
                        TranscribeResponse(
                            transcript = "hello",
                            detectedLanguage = "en-US",
                            quota = createGeneratedQuota(limit = -1, count = 0, remaining = 0),
                        ),
                    )
                },
            ),
        )

        val result = createAudioFile("bytes".toByteArray()).useAndDelete {
            client.transcribeAudio(it)
        }

        assertEquals(
            TranscriptionResult.Success(
                transcript = "hello",
                detectedLanguage = "en-US",
                quota = null,
            ),
            result,
        )
    }

    @Test
    fun transcribeAudio_invalidDetectedLanguage_returnsSuccessWithNullDetectedLanguage() = runTest {
        val client = createClient(
            api = fakeApi(
                transcribe = { _, _ ->
                    Response.success(
                        TranscribeResponse(
                            transcript = "hello",
                            detectedLanguage = "und",
                        ),
                    )
                },
            ),
        )

        val result = createAudioFile("bytes".toByteArray()).useAndDelete {
            client.transcribeAudio(it)
        }

        assertEquals(
            TranscriptionResult.Success(
                transcript = "hello",
                detectedLanguage = null,
                quota = null,
            ),
            result,
        )
    }

    @Test
    fun transcribeAudio_401_returnsProxyAuthFailed() = runTest {
        val client = createClient(
            api = fakeApi(
                transcribe = { _, _ -> errorResponse(401) },
            ),
            deviceId = "d".repeat(64),
        )

        val result = createAudioFile("bytes".toByteArray()).useAndDelete {
            client.transcribeAudio(it)
        }

        assertEquals(
            TranscriptionResult.Failure(TranscriptionFailureReason.ProxyAuthFailed),
            result,
        )
    }

    @Test
    fun transcribeAudio_503_returnsBackendUnavailable() = runTest {
        val client = createClient(
            api = fakeApi(
                transcribe = { _, _ -> errorResponse(503) },
            ),
            deviceId = "e".repeat(64),
        )

        val result = createAudioFile("bytes".toByteArray()).useAndDelete {
            client.transcribeAudio(it)
        }

        assertEquals(
            TranscriptionResult.Failure(TranscriptionFailureReason.BackendUnavailable),
            result,
        )
    }

    @Test
    fun transcribeAudio_429_returnsFailureWithQuota() = runTest {
        val client = createClient(
            api = fakeApi(
                transcribe = { _, _ ->
                    errorResponse(
                        code = 429,
                        body = """
                            {"error":"Daily record limit exceeded","quota":{"limit":10,"count":10,"remaining":0,"resetAt":"$TEST_RESET_AT"}}
                        """.trimIndent(),
                    )
                },
            ),
        )

        val result = createAudioFile("bytes".toByteArray()).useAndDelete {
            client.transcribeAudio(it)
        }

        assertEquals(
            TranscriptionResult.Failure(
                reason = TranscriptionFailureReason.ApiError,
                quota = RecordQuotaState(
                    limit = 10,
                    count = 10,
                    remaining = 0,
                    resetAt = OffsetDateTime.parse(TEST_RESET_AT),
                ),
            ),
            result,
        )
    }

    @Test
    fun transcribeAudio_429_withInvalidQuota_ignoresQuota() = runTest {
        val client = createClient(
            api = fakeApi(
                transcribe = { _, _ ->
                    errorResponse(
                        code = 429,
                        body = """
                            {"error":"Daily record limit exceeded","quota":{"limit":10,"count":12,"remaining":0,"resetAt":"$TEST_RESET_AT"}}
                        """.trimIndent(),
                    )
                },
            ),
        )

        val result = createAudioFile("bytes".toByteArray()).useAndDelete {
            client.transcribeAudio(it)
        }

        assertEquals(
            TranscriptionResult.Failure(
                reason = TranscriptionFailureReason.ApiError,
                quota = null,
            ),
            result,
        )
    }

    @Test
    fun transcribeAudio_retriesNetworkErrorsAndEventuallySucceeds() = runTest {
        var attempts = 0
        val client = createClient(
            api = fakeApi(
                transcribe = { _, _ ->
                    attempts += 1
                    if (attempts < 3) {
                        throw IOException("no route to host")
                    }
                    Response.success(
                        TranscribeResponse(
                            transcript = "hello",
                            detectedLanguage = "en-US",
                        ),
                    )
                },
            ),
            deviceId = "f".repeat(64),
        )

        val result = createAudioFile("bytes".toByteArray()).useAndDelete {
            client.transcribeAudio(it)
        }

        assertEquals(3, attempts)
        assertEquals(
            TranscriptionResult.Success(
                transcript = "hello",
                detectedLanguage = "en-US",
                quota = null,
            ),
            result,
        )
    }

    @Test
    fun transcribeAudio_timeoutAfterRetries_returnsBackendUnavailable() = runTest {
        val client = createClient(
            api = fakeApi(
                transcribe = { _, _ -> throw SocketTimeoutException("timeout") },
            ),
            deviceId = "1".repeat(64),
        )

        val result = createAudioFile("bytes".toByteArray()).useAndDelete {
            client.transcribeAudio(it)
        }

        assertEquals(
            TranscriptionResult.Failure(TranscriptionFailureReason.BackendUnavailable),
            result,
        )
    }

    @Test
    fun transcribeAudio_400_returnsApiError() = runTest {
        val client = createClient(
            api = fakeApi(
                transcribe = { _, _ -> errorResponse(400) },
            ),
            deviceId = "2".repeat(64),
        )

        val result = createAudioFile("bytes".toByteArray()).useAndDelete {
            client.transcribeAudio(it)
        }

        assertEquals(
            TranscriptionResult.Failure(TranscriptionFailureReason.ApiError),
            result,
        )
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
        transcribe: suspend (String, MultipartBody.Part) -> Response<TranscribeResponse> =
            { _, _ -> Response.success(TranscribeResponse(transcript = "hello", detectedLanguage = "en-US")) },
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
                audio: MultipartBody.Part,
            ): Response<TranscribeResponse> = transcribe(xDeviceId, audio)
        }
    }

    private fun <T> errorResponse(
        code: Int,
        body: String = """{"error":"boom"}""",
    ): Response<T> {
        return Response.error(
            code,
            body.toResponseBody("application/json".toMediaType()),
        )
    }

    private fun createGeneratedQuota(
        limit: Int,
        count: Int,
        remaining: Int,
        resetAt: String = TEST_RESET_AT,
    ): RecordQuota {
        return RecordQuota(
            limit = limit,
            count = count,
            remaining = remaining,
            resetAt = OffsetDateTime.parse(resetAt),
        )
    }

    private fun createAudioFile(bytes: ByteArray): File {
        return File.createTempFile(
            "transcribe-test",
            ".${BackendAudioUploadConfig.RECORDED_AUDIO_FILE_EXTENSION}",
        ).apply {
            writeBytes(bytes)
        }
    }

    private suspend fun TestScope.assertMultipartContentTypeForExtension(
        extension: String,
        expectedContentType: String,
    ) {
        MockWebServer().use { server ->
            server.enqueue(
                MockResponse()
                    .setResponseCode(200)
                    .setHeader("Content-Type", "application/json")
                    .setBody("""{"transcript":"hello","detected_language":"en-US"}"""),
            )
            val client = createClient(
                api = createRealApi(server),
                deviceId = "a".repeat(64),
            )
            val audioFile = File.createTempFile("transcribe-test", extension).apply {
                writeBytes("bytes".toByteArray())
            }

            audioFile.useAndDelete {
                client.transcribeAudio(it)
            }

            val request = server.takeRequest()
            val multipartBody = request.body.readUtf8()
            assertTrue(multipartBody.contains(expectedContentType))
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
        const val TEST_RESET_AT = "2026-05-28T00:00:00Z"
    }
}
