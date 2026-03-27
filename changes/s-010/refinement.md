# S-010 Refinement — OpenAI API Service

## Codebase findings

All four required Ktor modules are **already present** at version 3.4.1:
- `ktor-client-core`, `ktor-client-android`, `ktor-client-content-negotiation`, `ktor-serialization-kotlinx-json`

No new library dependencies are needed.

One gap: the `kotlin.plugin.serialization` Gradle plugin is **not applied**. It is required so the compiler processes `@Serializable` annotations on the request/response data classes. It is added using the existing `kotlin = "2.3.20"` version — no version bump required.

`BuildConfig` currently has a placeholder `buildConfigField("String", "API_KEY", "\"YOUR_API_KEY_HERE\"")`. This is replaced with a proper `local.properties` read keyed as `OPENAI_API_KEY`.

Hilt module pattern follows `RepositoryModule.kt`: `@Binds` abstract class because the implementation has an `@Inject` constructor.

---

## Files to create

| File | Purpose |
|------|---------|
| `app/src/main/java/com/wrait/app/data/api/OpenAiModels.kt` | `@Serializable` request/response data classes |
| `app/src/main/java/com/wrait/app/data/api/OpenAiApiService.kt` | Interface + `CleanupResult` sealed class |
| `app/src/main/java/com/wrait/app/data/api/OpenAiApiServiceImpl.kt` | Ktor HTTP implementation |
| `app/src/main/java/com/wrait/app/di/ApiModule.kt` | Hilt `@Singleton` binding |

## Files to modify

| File | Change |
|------|--------|
| `gradle/libs.versions.toml` | Add `kotlin-serialization` plugin alias |
| `app/build.gradle.kts` | Apply serialization plugin; read `OPENAI_API_KEY` from `local.properties` |
| `local.properties` | Add `OPENAI_API_KEY=` placeholder with instructions |

---

## Step 1 — Serialization plugin

### `gradle/libs.versions.toml` — add to `[plugins]`
```toml
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
```

### `app/build.gradle.kts` — add to `plugins` block
```kotlin
alias(libs.plugins.kotlin.serialization)
```

---

## Step 2 — API key from `local.properties`

### `app/build.gradle.kts` — add before `android { }`
```kotlin
import java.util.Properties

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}
val openAiApiKey: String = localProperties.getProperty("OPENAI_API_KEY", "")
```

### `defaultConfig` block — replace placeholder field
```kotlin
// was: buildConfigField("String", "API_KEY", "\"YOUR_API_KEY_HERE\"")
buildConfigField("String", "OPENAI_API_KEY", "\"$openAiApiKey\"")
```

### `local.properties`
```
# OpenAI API key — get from platform.openai.com/api-keys
# Do NOT commit a real key — this file is in .gitignore
OPENAI_API_KEY=
```

---

## Step 3 — `OpenAiModels.kt`

Package: `com.wrait.app.data.api`

Four `@Serializable` data classes mirroring the OpenAI Chat Completions request/response shape:
- `OpenAiRequest(model, maxTokens, temperature, messages)`
- `OpenAiMessage(role, content)`
- `OpenAiResponse(choices)`
- `OpenAiChoice(message)`

`maxTokens` uses `@SerialName("max_tokens")` for JSON snake_case mapping.

---

## Step 4 — `OpenAiApiService.kt`

Package: `com.wrait.app.data.api`

```kotlin
interface OpenAiApiService {
    suspend fun cleanupTranscript(rawText: String): CleanupResult
}

sealed class CleanupResult {
    data class Success(val cleanedText: String) : CleanupResult()
    data class Failure(val reason: String) : CleanupResult()
}
```

---

## Step 5 — `OpenAiApiServiceImpl.kt`

Package: `com.wrait.app.data.api`

- `HttpClient(Android)` engine
- `ContentNegotiation` + `HttpTimeout` (30 s request / 10 s connect) plugins
- Input truncated to 3 000 chars before sending
- Cleanup prompt in `private companion object` as a `const val`; old prompt versions live in a comment block above the active version for easy rollback (per spec)
- `if (BuildConfig.DEBUG)` guard on any log that could contain transcript text
- All failure paths (`401`, `429`, `5xx`, timeout, network) return `CleanupResult.Failure` — no exceptions escape the function

Error mapping:

| Condition | `CleanupResult.Failure` reason |
|-----------|-------------------------------|
| HTTP 401 | `"invalid api key"` |
| HTTP 429 | `"rate limit"` |
| Other 4xx/5xx | `"api error <code>"` |
| `HttpRequestTimeoutException` | `"timeout"` |
| `Exception` (network) | `"network error"` |
| Empty `choices[0].message.content` | `"empty response"` |

---

## Step 6 — `ApiModule.kt`

Package: `com.wrait.app.di`

```kotlin
@Module
@InstallIn(SingletonComponent::class)
abstract class ApiModule {
    @Binds
    @Singleton
    abstract fun bindOpenAiApiService(impl: OpenAiApiServiceImpl): OpenAiApiService
}
```

Uses `@Binds` (not `@Provides`) because `OpenAiApiServiceImpl` has an `@Inject` constructor — consistent with `RepositoryModule`.

---

## New package layout

```
com/wrait/app/
├── data/
│   ├── api/
│   │   ├── OpenAiModels.kt          ← new
│   │   ├── OpenAiApiService.kt      ← new
│   │   └── OpenAiApiServiceImpl.kt  ← new
│   └── ... (existing)
├── di/
│   ├── ApiModule.kt                 ← new
│   └── ... (existing)
```

---

## Verification

1. `./gradlew assembleDebug` — no errors; no `@Serializable` warnings
2. `./gradlew kspDebugKotlin` — no missing Hilt binding errors
3. `BuildConfig.OPENAI_API_KEY` is non-empty when `local.properties` contains a real key
4. Manual call to `cleanupTranscript("So um today I went to the store")` returns `CleanupResult.Success` with filler words removed
5. Wrong key → `Failure("invalid api key")`; unreachable host → `Failure("timeout")` after 30 s
6. Logcat on release build shows no transcript content
