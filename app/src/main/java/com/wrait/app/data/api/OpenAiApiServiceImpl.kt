package com.wrait.app.data.api

import android.util.Log
import com.wrait.app.BuildConfig
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.engine.android.Android
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.HttpRequestTimeoutException
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import javax.inject.Inject

class OpenAiApiServiceImpl @Inject constructor() : OpenAiApiService {

    private val client = HttpClient(Android) {
        install(ContentNegotiation) {
            json(Json { ignoreUnknownKeys = true })
        }
        install(HttpTimeout) {
            requestTimeoutMillis = 30_000
            connectTimeoutMillis = 10_000
        }
    }

    override suspend fun cleanupTranscript(rawText: String): CleanupResult {
        val truncated = if (rawText.length > 3000) rawText.take(3000) + "…" else rawText

        return try {
            val response: OpenAiResponse = client.post("https://api.openai.com/v1/chat/completions") {
                header(HttpHeaders.Authorization, "Bearer ${BuildConfig.OPENAI_API_KEY}")
                contentType(ContentType.Application.Json)
                setBody(
                    OpenAiRequest(
                        model = "gpt-4o-mini",
                        maxTokens = 1024,
                        temperature = 0.3,
                        messages = listOf(
                            OpenAiMessage("system", CLEANUP_PROMPT),
                            OpenAiMessage("user", truncated)
                        )
                    )
                )
            }.body()

            val text = response.choices.firstOrNull()?.message?.content
            if (text.isNullOrBlank()) {
                Log.w(TAG, "OpenAI returned empty choices")
                CleanupResult.Failure("empty response")
            } else {
                CleanupResult.Success(text.trim())
            }

        } catch (e: HttpRequestTimeoutException) {
            Log.w(TAG, "OpenAI request timed out")
            CleanupResult.Failure("timeout")
        } catch (e: io.ktor.client.plugins.ClientRequestException) {
            val code = e.response.status.value
            Log.w(TAG, "OpenAI client error: $code")
            when (code) {
                401 -> CleanupResult.Failure("invalid api key")
                429 -> CleanupResult.Failure("rate limit")
                else -> CleanupResult.Failure("api error $code")
            }
        } catch (e: Exception) {
            Log.w(TAG, "OpenAI network error: ${e.javaClass.simpleName}")
            CleanupResult.Failure("network error")
        }
    }

    private companion object {
        const val TAG = "OpenAiApiService"

        // ── Prompt history ────────────────────────────────────────────────
        // v1 — initial prompt (s-010)
        const val CLEANUP_PROMPT = """You are a transcription editor for a personal voice diary app.
The user has spoken a diary entry out loud and you have received the raw
speech-to-text transcript.

Your task:
- Remove filler words: um, uh, like, you know, so, right, basically
- Fix punctuation and capitalisation
- Correct obvious speech recognition errors
- Add paragraph breaks where the speaker clearly shifts topic
- Preserve the speaker's exact language — do not translate under any circumstances
- Preserve their voice and personal tone — do not rewrite sentences, only tidy them
- Do not summarise
- Do not add anything the speaker did not say
- Do not expand or elaborate on anything said

Return only the cleaned text. No preamble, no explanation, no quotes around the result."""
    }
}
