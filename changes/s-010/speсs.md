# S-010 — OpenAI API service and cleanup prompt

| Field | Value |
|---|---|
| Type | Feature |
| Status | Not started |
| Effort | 1–2 days |
| Depends on | S-001 (OpenAI API key must exist) |
| Phase | 2 |

## Context

This story implements the HTTP layer that calls the OpenAI Chat Completions API to clean up raw voice transcripts. It is a standalone service — no knowledge of recording state, UI, or the database. Text in, cleaned text out.

**Model choice:** Use `gpt-4o-mini`. It is priced at $0.15 per million input tokens and $0.60 per million output tokens — a 2-minute diary entry produces roughly 400 input tokens and 300 output tokens, making each cleanup call approximately **$0.0002** (less than a cent). Fast (~1–2s response), excellent multilingual quality, and ideal for this use case. Upgrade to `gpt-4o` only if beta feedback says cleanup quality is insufficient.

**Privacy note (flagged for later implementation):** The OpenAI API is stateless — inputs are not used for model training by default on API (non-consumer) usage. Confirm this in the README. Do not add any logging, analytics, or secondary storage of transcript content anywhere in this service.

## API details

- **Endpoint:** `POST https://api.openai.com/v1/chat/completions`
- **Model:** `gpt-4o-mini`
- **Auth header:** `Authorization: Bearer YOUR_OPENAI_API_KEY`
- **Content-Type:** `application/json`

### Request body structure

```json
{
  "model": "gpt-4o-mini",
  "max_tokens": 1024,
  "temperature": 0.3,
  "messages": [
    {
      "role": "system",
      "content": "<system prompt — see below>"
    },
    {
      "role": "user",
      "content": "<raw transcript>"
    }
  ]
}
```

### Response — extract the cleaned text from

```
response.choices[0].message.content
```

### Verify with curl before writing any code

```bash
curl https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o-mini",
    "max_tokens": 1024,
    "messages": [
      {"role": "system", "content": "Clean up this voice transcript."},
      {"role": "user", "content": "So um today I went to the uh store and like it was really busy"}
    ]
  }'
```

## Cleanup prompt — starting version (system message)

```
You are a transcription editor for a personal voice diary app.
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

Return only the cleaned text. No preamble, no explanation, no quotes around the result.
```

**Temperature is set to 0.3** — lower than the default 1.0. This reduces creative rewriting and keeps the model closer to the literal input. Do not set it to 0 — a small amount of variance helps with punctuation naturalness.

This prompt will be refined in S-020 after real testing. Keep previous versions in a comment block above the current version so you can roll back.

## S-001 update — OpenAI instead of Anthropic

> **Note:** S-001 was originally written for Anthropic. It must be updated to use OpenAI.

When doing S-001, use these steps instead:

- [ ] Create account at platform.openai.com
- [ ] Add payment method at platform.openai.com/settings/billing
- [ ] Set a hard **usage limit** of €20/month at platform.openai.com/settings/billing — this is your abuse backstop
- [ ] Create an API key at platform.openai.com/api-keys — name it `wrait-beta`
- [ ] Store in password manager immediately
- [ ] Add to `local.properties`: `OPENAI_API_KEY=sk-...`
- [ ] Verify `local.properties` is in `.gitignore`
- [ ] Test with the curl command above

## Ktor implementation

### Dependencies

No new dependencies needed beyond what S-011 will use. Ktor Client is already in the stack. Confirm `ktor-client-android`, `ktor-client-content-negotiation`, and `ktor-serialization-kotlinx-json` are present in `libs.versions.toml`.

### Data classes

```kotlin
@Serializable
data class OpenAiRequest(
    val model: String,
    @SerialName("max_tokens") val maxTokens: Int,
    val temperature: Double,
    val messages: List<OpenAiMessage>
)

@Serializable
data class OpenAiMessage(
    val role: String,
    val content: String
)

@Serializable
data class OpenAiResponse(
    val choices: List<OpenAiChoice>
)

@Serializable
data class OpenAiChoice(
    val message: OpenAiMessage
)
```

### Service interface and implementation

```kotlin
interface OpenAiApiService {
    suspend fun cleanupTranscript(rawText: String): CleanupResult
}

sealed class CleanupResult {
    data class Success(val cleanedText: String) : CleanupResult()
    data class Failure(val reason: String) : CleanupResult()
}
```

### HTTP client setup

```kotlin
private val client = HttpClient(Android) {
    install(ContentNegotiation) {
        json(Json { ignoreUnknownKeys = true })
    }
    install(HttpTimeout) {
        requestTimeoutMillis = 30_000
        connectTimeoutMillis = 10_000
    }
}
```

### Implementation sketch

```kotlin
override suspend fun cleanupTranscript(rawText: String): CleanupResult {
    val truncated = if (rawText.length > 3000)
        rawText.take(3000) + "…" else rawText

    return try {
        val response: OpenAiResponse = client.post("https://api.openai.com/v1/chat/completions") {
            header(HttpHeaders.Authorization, "Bearer ${BuildConfig.OPENAI_API_KEY}")
            contentType(ContentType.Application.Json)
            setBody(OpenAiRequest(
                model = "gpt-4o-mini",
                maxTokens = 1024,
                temperature = 0.3,
                messages = listOf(
                    OpenAiMessage("system", CLEANUP_PROMPT),
                    OpenAiMessage("user", truncated)
                )
            ))
        }.body()

        val text = response.choices.firstOrNull()?.message?.content
        if (text.isNullOrBlank()) CleanupResult.Failure("empty response")
        else CleanupResult.Success(text.trim())

    } catch (e: HttpRequestTimeoutException) {
        CleanupResult.Failure("timeout")
    } catch (e: ClientRequestException) {
        when (e.response.status.value) {
            401 -> CleanupResult.Failure("invalid api key")
            429 -> CleanupResult.Failure("rate limit")
            else -> CleanupResult.Failure("api error ${e.response.status.value}")
        }
    } catch (e: Exception) {
        CleanupResult.Failure("network error")
    }
}
```

## Error handling

| HTTP status | Meaning | Return |
|---|---|---|
| 200 | Success | `CleanupResult.Success` |
| 401 | Invalid API key | `Failure("invalid api key")` |
| 429 | Rate limit hit | `Failure("rate limit")` |
| 500/503 | OpenAI server error | `Failure("api error 5xx")` |
| Timeout | No response in 30s | `Failure("timeout")` |
| No network | Can't connect | `Failure("network error")` |

All failures map to leaving the entry as a draft. The ViewModel (S-011) handles retry logic — this service just reports success or failure.

## Privacy

- Zero logging of transcript content in release builds
- Gate any debug logging behind `if (BuildConfig.DEBUG)`
- The service is stateless — no caching, no secondary storage, text enters and leaves via function parameters only
- OpenAI API usage does not train models by default — confirm this is documented in the README (S-021)

## Hilt module

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object ApiModule {
    @Provides
    @Singleton
    fun provideOpenAiApiService(): OpenAiApiService = OpenAiApiServiceImpl()
}
```

## Claude Code prompt

```
Create an OpenAI API service for Android using Ktor HttpClient.
Interface: OpenAiApiService with suspend fun cleanupTranscript(rawText: String): CleanupResult.
CleanupResult is a sealed class: Success(cleanedText: String) and Failure(reason: String).
Endpoint: POST https://api.openai.com/v1/chat/completions
Model: gpt-4o-mini, max_tokens: 1024, temperature: 0.3
Auth header: Authorization: Bearer BuildConfig.OPENAI_API_KEY
System message: [paste cleanup prompt]
User message: the rawText parameter (truncated to 3000 chars if longer)
Parse response from choices[0].message.content
Handle 401, 429, 5xx, timeout, and network errors — all return CleanupResult.Failure with a short reason string
Zero logging of transcript content in release builds.
Provide via Hilt @Singleton module.
Use Kotlin with kotlinx.serialization.
```

## Definition of done

- [ ] `cleanupTranscript()` returns `Success` with cleaned Dutch text for a test transcript
- [ ] Returns `Success` with cleaned English text for a test transcript
- [ ] Returns `Failure("invalid api key")` when called with a wrong key
- [ ] Returns `Failure` gracefully on timeout (test by temporarily pointing at a non-responsive host)
- [ ] No transcript content appears in logcat on a release build
- [ ] Hilt injection works — service available in ViewModel via `@Inject`
- [ ] Total cost of 10 test calls is less than €0.01 (verify in OpenAI usage dashboard)