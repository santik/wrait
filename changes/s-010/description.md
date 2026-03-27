# S-010 — OpenAI API Service: Changes Description

## What was built

A standalone HTTP service that sends raw voice transcript text to the OpenAI Chat Completions API (`gpt-4o-mini`) and returns a cleaned version. The service has no knowledge of recording state, UI, or the database — it is pure infrastructure: text in, cleaned text out.

---

## Files created

### `app/src/main/java/com/wrait/app/data/api/OpenAiModels.kt`
Four `@Serializable` data classes that map to the OpenAI Chat Completions request/response JSON shape:
- `OpenAiRequest` — model, maxTokens (`@SerialName("max_tokens")`), temperature, messages list
- `OpenAiMessage` — role + content
- `OpenAiResponse` — choices list
- `OpenAiChoice` — message

### `app/src/main/java/com/wrait/app/data/api/OpenAiApiService.kt`
Interface with a single suspend function:
```kotlin
suspend fun cleanupTranscript(rawText: String): CleanupResult
```
`CleanupResult` is a sealed class with two cases:
- `Success(cleanedText: String)` — cleaned transcript ready for display
- `Failure(reason: String)` — short reason string; caller decides how to handle

### `app/src/main/java/com/wrait/app/data/api/OpenAiApiServiceImpl.kt`
Ktor `HttpClient(Android)` implementation with:
- `ContentNegotiation` plugin (`kotlinx.serialization` JSON, `ignoreUnknownKeys = true`)
- `HttpTimeout` plugin (30 s request / 10 s connect)
- Input truncated to 3 000 chars before sending
- Cleanup prompt in a `private companion object` `const val`; old prompt versions live in a comment block above the active version for easy rollback (per spec)
- All log lines that could contain transcript content are guarded or omitted — no transcript text appears in logcat on any build
- All failure paths return `CleanupResult.Failure` — no exceptions escape the function

Error mapping:

| Condition | `Failure` reason |
|-----------|-----------------|
| HTTP 401 | `"invalid api key"` |
| HTTP 429 | `"rate limit"` |
| Other 4xx/5xx | `"api error <code>"` |
| `HttpRequestTimeoutException` | `"timeout"` |
| Any other `Exception` | `"network error"` |
| Empty `choices[0].message.content` | `"empty response"` |

### `app/src/main/java/com/wrait/app/di/ApiModule.kt`
Hilt `@Binds @Singleton` abstract module binding `OpenAiApiServiceImpl` to `OpenAiApiService`. Uses `@Binds` (not `@Provides`) because the implementation has an `@Inject` constructor — consistent with `RepositoryModule`.

---

## Files modified

### `gradle/libs.versions.toml`
Added `kotlin-serialization` plugin alias to `[plugins]`:
```toml
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
```
Reuses the existing `kotlin = "2.3.20"` version — no version bump needed.

### `app/build.gradle.kts`
Three changes:
1. Applied `alias(libs.plugins.kotlin.serialization)` in the plugins block — required for `@Serializable` annotation processing
2. Added `local.properties` read at the top of the file using `java.util.Properties`
3. Replaced the placeholder `buildConfigField("String", "API_KEY", "\"YOUR_API_KEY_HERE\"")` with `buildConfigField("String", "OPENAI_API_KEY", "\"$openAiApiKey\"")` read from `local.properties`

### `local.properties`
Added `OPENAI_API_KEY=` placeholder with a comment explaining where to get the key. This file is already in `.gitignore` — the real key must never be committed.

---

## Dependencies

No new library dependencies were added. All four required Ktor modules were already present at 3.4.1:
- `ktor-client-core`
- `ktor-client-android`
- `ktor-client-content-negotiation`
- `ktor-serialization-kotlinx-json`

`HttpTimeout` is part of `ktor-client-core` — no extra module needed.

---

## Design decisions

**`@Binds` over `@Provides` in `ApiModule`** — `OpenAiApiServiceImpl` has an `@Inject` constructor so Hilt can construct it directly. `@Binds` is the correct pattern and avoids an unnecessary factory method.

**Prompt versioning via comments** — The cleanup prompt will be refined in S-020 after real-world testing. Previous versions are preserved in a comment block directly above the active constant so they can be restored without digging through git history.

**`ignoreUnknownKeys = true`** — The OpenAI response contains many fields not needed by this service (usage stats, finish reason, etc.). Ignoring unknown keys keeps the model minimal and avoids breakage if the API adds new fields.

**No Ktor logging plugin** — Adding `Logging` plugin would risk leaking transcript content to logcat. Individual `Log.w` calls at specific points (error paths only, never transcript content) give enough observability without the risk.

---

## How to test

1. Add your OpenAI API key to `local.properties`: `OPENAI_API_KEY=sk-...`
2. Build: `./gradlew assembleDebug`
3. Inject `OpenAiApiService` in a debug ViewModel and call `cleanupTranscript("So um today I went to the store and like it was really busy")` — expect `Success` with filler words removed
4. Wrong key test: temporarily set a bad key → expect `Failure("invalid api key")`
5. Privacy check: run logcat on a release build — no transcript content should appear
