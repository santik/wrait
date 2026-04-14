# wrait — Issues & Findings

> **Generated**: April 14, 2026
> **Scope**: Full codebase audit — security, data flow, UX, architecture,
> dependencies, and reliability.
> **Reference**: `CODEBASE_KNOWLEDGE.md`

---

## Priority Definitions

| Priority | Definition |
|----------|-----------|
| **P0** | Critical — data loss, security breach, or crash that affects all users |
| **P1** | High — significant bug or risk that materially impacts UX or security |
| **P2** | Medium — noticeable issue, defensive gap, or architectural concern |
| **P3** | Low — minor inconsistency, code smell, or improvement opportunity |

---

## Summary Table

| # | Priority | Category | Title |
|---|----------|----------|-------|
| 1 | P0 | Security | API keys compiled into the binary are extractable |
| 2 | P0 | Data Loss | Transcript exceeding `MAX_TRANSCRIPT_LENGTH` is logged but never truncated |
| 3 | P0 | Security | `allowBackup="true"` in manifest contradicts exclusion-only rules |
| 4 | P1 | Data Flow | `shakeErrorKey` integer overflow after prolonged use |
| 5 | P1 | Security | `CleanupResult.Failure.reason` is a free-form string — cleanup error routing is fragile |
| 6 | P1 | Data Flow | `getAllEntries()` queried twice eagerly in `MainViewModel` |
| 7 | P1 | UX | No network-availability check before cloud recording in MODE_BEST |
| 8 | P1 | Reliability | `DeepgramTranscriptionService.stopSignal` is shared mutable state across recordings |
| 9 | P1 | Data Flow | `EntryDetailViewModel` debounce triggers immediate persist on initial load |
| 10 | P1 | UX | Delete from entry list doesn't notify `MainViewModel` — no "entry deleted" confirmation |
| 11 | P1 | Architecture | `Dispatchers.IO` hardcoded in `EntryDetailViewModel` and `EntryListViewModel` |
| 12 | P1 | Reliability | `onEntriesDeleted` coroutine is not tracked — can race with button taps |
| 13 | P2 | Security | No certificate pinning on API calls |
| 14 | P2 | Security | DataStore preferences are stored in plaintext |
| 15 | P2 | Architecture | `MainRecordingController` has `@Inject` annotation but is never Hilt-managed |
| 16 | P2 | Data Flow | `OpenAiApiServiceImpl` does not validate the OpenAI API key at startup |
| 17 | P2 | UX | No user feedback when draft retry succeeds or fails on startup |
| 18 | P2 | Data Flow | `listeningStartedAt` uses `System.currentTimeMillis()` instead of injected `TimeProvider` |
| 19 | P2 | Reliability | `HttpClient` instances are never closed |
| 20 | P2 | UX | Hardcoded English strings in composables bypass string resources |
| 21 | P2 | Architecture | `RecordingState` and `EntrySummary` defined in ViewModel file — wrong layer |
| 22 | P2 | UX | No loading indicator while entry detail is being fetched |
| 23 | P2 | Data Flow | `insert(onConflict = REPLACE)` can silently overwrite entries |
| 24 | P2 | Reliability | `MediaRecorder()` constructor is deprecated on API 31+ |
| 25 | P2 | Data Flow | `retryPendingDrafts` runs on IO but reads `openAiApiService` that may not be thread-safe |
| 26 | P2 | UX | Language picker does not close after selection |
| 27 | P3 | Architecture | `WhisperTranscriptionService` is compiled and shipped but unreachable |
| 28 | P3 | Code Quality | Commented-out code in `MainRecordingController` |
| 29 | P3 | Code Quality | Word count calculation duplicated in 4+ locations |
| 30 | P3 | UX | Stats count includes drafts — may mislead users |
| 31 | P3 | Code Quality | `EntryDetailViewModel` uses hardcoded `Dispatchers.IO` for persistEdit |
| 32 | P3 | UX | `SwipeBackThresholdPx` is in pixels — not density-independent |
| 33 | P3 | Architecture | No ProGuard/R8 rules for Ktor serialization models |
| 34 | P3 | Code Quality | Inconsistent TAG usage — some use string constants, some use inline strings |
| 35 | P3 | UX | `resolveActivity()` returns null on API 30+ due to package visibility |

---

## P0 — Critical

### 1. API keys compiled into the binary are extractable

**Category**: Security
**Files**: `app/build.gradle.kts` (lines 41–43), `BuildConfig`

**Issue**: `OPENAI_API_KEY` and `DEEPGRAM_API_KEY` are injected into
`BuildConfig` as string literals. Even with R8/ProGuard minification, string
constants survive in the `.dex` file and can be extracted trivially with `apktool`
or `jadx`. A leaked APK (beta testers, lost device, side-load) exposes both API
keys.

**Impact**: Unlimited API spend on the developer's accounts. Deepgram and OpenAI
keys can be harvested and used for unrelated workloads.

**Current mitigation**: "Acceptable for closed beta with spend caps" (per
`CODEBASE_KNOWLEDGE.md`). This is acknowledged but remains a P0 risk if the
beta audience expands or a build leaks.

**Recommendation**:
- Move API calls through a thin backend proxy (e.g., Cloud Functions) that holds
  the keys server-side and authenticates the app via a short-lived device token.
- If a proxy is not feasible for beta, at minimum add per-key spend alerts and
  automatic rotation capability.

---

### 2. Transcript exceeding `MAX_TRANSCRIPT_LENGTH` is logged but never truncated

**Category**: Data Loss / Data Integrity
**File**: `MainRecordingController.kt` (lines 162–164)

**Issue**: When `text.length > MAX_TRANSCRIPT_LENGTH` (10,000 chars), the code
logs a warning but proceeds to save the full untruncated text to the database
and send it to OpenAI. The comment says "truncating" but no truncation actually
occurs.

```kotlin
if (text.length > MAX_TRANSCRIPT_LENGTH) {
    Log.w(TAG, "Transcript exceeds max length (${text.length} chars), truncating")
}
// ← text is NOT truncated; continues to saveDraft(text, ...) with original value
```

**Impact**:
- Oversized text is sent to OpenAI (which separately truncates to 3,000 chars),
  creating a mismatch: the saved draft has the full text, the cleaned text only
  covers the first 3,000 chars.
- Database row sizes are unbounded.

**Recommendation**: Actually truncate the text after logging:
```kotlin
val safeText = if (text.length > MAX_TRANSCRIPT_LENGTH) text.take(MAX_TRANSCRIPT_LENGTH) else text
```

---

### 3. `allowBackup="true"` in manifest contradicts exclusion-only rules

**Category**: Security
**File**: `AndroidManifest.xml` (line 9)

**Issue**: The manifest declares `android:allowBackup="true"`. While
`backup_rules.xml` and `data_extraction_rules.xml` exclude sensitive files,
the backup system uses an **include-by-default** model. Any new file added in
the future (e.g., a new SharedPreferences file, a cache file) will be
auto-backed up unless explicitly excluded. This is a ticking time bomb for a
privacy-focused app.

**Impact**: A forgotten exclusion rule could silently back up diary content or
encryption material to Google Drive.

**Recommendation**: Set `android:allowBackup="false"` to adopt a deny-by-default
posture. If backup is desired for non-sensitive data, use an explicit
include-only rule.

---

## P1 — High

### 4. `shakeErrorKey` integer overflow after prolonged use

**Category**: Data Flow
**File**: `MainRecordingController.kt` (lines 40, 157, 232)

**Issue**: `_shakeErrorKey` is an `Int` that is monotonically incremented via
`update { it + 1 }` on every TooShort/NoMatch error. After ~2.1 billion errors,
this overflows to `Int.MIN_VALUE`, causing the `LaunchedEffect(shakeErrorKey)`
key to potentially match a previous value and skip a shake animation.

**Impact**: Extremely unlikely in a single session but theoretically reachable
over the ViewModel's lifetime. Overflow behaviour in `LaunchedEffect` keying is
undefined.

**Recommendation**: Use `Long` instead of `Int`, or wrap with modular
arithmetic.

---

### 5. `CleanupResult.Failure.reason` is a free-form string — error routing is fragile

**Category**: Security / Reliability
**File**: `MainRecordingController.kt` (lines 218–222),
`OpenAiApiServiceImpl.kt` (lines 63–74)

**Issue**: The controller checks failure reasons via string matching:
```kotlin
val isNetworkFailure = result.reason == "network error" || result.reason == "timeout"
```
But `OpenAiApiServiceImpl` also returns `"rate limit"`, `"invalid api key"`,
`"empty response"`, and `"api error $code"`. These are all treated as
non-network failures, leading to `RecognizerError.ApiFailed` and the generic
"saved as draft · will retry" message.

A rate-limit (429) or invalid-API-key (401) error will be retried on next app
launch — forever. The 401 case is especially problematic: every startup burns a
draft retry attempt against a permanently invalid key.

**Impact**: Infinite retry loop for non-recoverable errors; wasted API calls.

**Recommendation**:
- Replace `String` reason with a sealed class or enum in `CleanupResult.Failure`.
- Distinguish between retryable (network, timeout, rate-limit) and
  non-retryable (auth, empty response) failures.
- Skip retry for non-retryable failures.

---

### 6. `getAllEntries()` queried twice eagerly in `MainViewModel`

**Category**: Data Flow / Performance
**File**: `MainViewModel.kt` (lines 77–85)

**Issue**: Two separate `stateIn` flows observe `entryRepository.getAllEntries()`:
```kotlin
val entries: StateFlow<List<EntrySummary>> = entryRepository.getAllEntries()
    .map { ... }.stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

val entryStats: StateFlow<EntryStats> = entryRepository.getAllEntries()
    .map { ... }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ...)
```

Room creates two separate `Flow` collectors, both running the same
`SELECT * FROM entries ORDER BY createdAt DESC` query. Every database write
triggers two separate re-queries.

**Impact**: Doubles database read pressure; both map the full entity list.

**Recommendation**: Share a single upstream flow:
```kotlin
private val allEntries = entryRepository.getAllEntries()
    .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())
val entries = allEntries.map { ... }
val entryStats = allEntries.map { ... }
```

---

### 7. No network-availability check before cloud recording in MODE_BEST

**Category**: UX
**Files**: `MainRecordingController.kt`, `DeepgramTranscriptionService.kt`

**Issue**: In MODE_BEST, the user taps the button, records for up to 2 minutes,
and only then discovers there's no network when the upload fails. The audio is
saved as a draft, but the user's time is wasted and the UX is confusing — they
expected a transcription, not a draft.

**Impact**: Poor UX on flaky connections; user has no upfront signal that the
operation will fail.

**Recommendation**: Check `ConnectivityManager.activeNetwork` before starting a
recording in MODE_BEST. If offline, either show a warning toast/dialog or
silently fall back to MODE_PRIVATE for that session.

---

### 8. `DeepgramTranscriptionService.stopSignal` is shared mutable state across recordings

**Category**: Reliability
**File**: `DeepgramTranscriptionService.kt` (lines 45, 55, 99)

**Issue**: `stopSignal` is a class-level `@Volatile` `CompletableDeferred<Unit>`.
It is reassigned at the start of each `transcribe()` call:
```kotlin
stopSignal = CompletableDeferred()
```
And completed in `stopRecording()`:
```kotlin
override fun stopRecording() { stopSignal.complete(Unit) }
```

If `stopRecording()` is called between the old recording's completion and the
new recording's `stopSignal = CompletableDeferred()` reassignment (a race
window), the new recording's signal is pre-completed and the recording
immediately stops.

Additionally, `ModeAwareTranscriptionService.stopRecording()` calls
`deepgramService.stopRecording()` even when the Android backend is active. While
documented as "cheap no-op," it completes the `stopSignal` that will be used by
the next Deepgram recording.

**Impact**: Race condition that could cause the next cloud recording to
immediately stop (zero-length file → TooShort error).

**Recommendation**: Create the `CompletableDeferred` as a local variable inside
`transcribe()` and pass it to `record()`, or use a `Channel` / `MutableStateFlow`
pattern that is inherently safe across calls.

---

### 9. `EntryDetailViewModel` debounce triggers persist on initial load

**Category**: Data Flow
**File**: `EntryDetailViewModel.kt` (lines 44–54)

**Issue**: Two coroutines race during init:
1. `entry.collect { ... }` sets `_editedText.value` to the entry's text.
2. `_editedText.filterNotNull().debounce(500).collect { persistEdit(it) }` fires
   500ms after the value is set.

On initial load, the entry text is "edited" (set from null → text), triggering a
`persistEdit()` that calls `updateWithCleanedText()`. This is a no-op write
(same text), but it:
- Clears `isDraft = 0` and `audioPath = NULL` on the entry (the DAO query
  `updateCleanedText` does both).
- If the entry was a draft that slipped through the `!e.isDraft` guard somehow
  (e.g., a rapid state change), it would be silently finalized.

**Impact**: Unnecessary DB write on every entry view. Benign for finalized
entries but semantically wrong.

**Recommendation**: Track a `hasUserEdited` flag. Only call `persistEdit()` on
user-initiated changes, not the initial population.

---

### 10. Delete from entry list doesn't notify `MainViewModel` — no "entry deleted" confirmation

**Category**: UX
**File**: `EntryListScreen.kt`, `EntryListViewModel.kt`, `MainActivity.kt`

**Issue**: When an entry is deleted from the entry list (swipe-to-delete),
`EntryListViewModel.deleteEntry()` is called directly. It never calls
`MainViewModel.onEntriesDeleted(count)`, so:
- No `RecordingState.Deleted(1)` is emitted.
- No "entry deleted" status line confirmation is shown.
- If the user navigates back to the main screen, it's as if nothing happened.

In contrast, delete from the detail screen does navigate back to the list, but
also doesn't call `onEntriesDeleted`.

**Impact**: Inconsistent feedback. The user gets no confirmation that their
diary entry was permanently removed.

**Recommendation**: Wire `onEntriesDeleted` callback from `EntryListScreen`
and `EntryDetailScreen` back to `MainViewModel`. This may require passing the
callback through `AppNavHost`.

---

### 11. `Dispatchers.IO` hardcoded in `EntryDetailViewModel` and `EntryListViewModel`

**Category**: Architecture / Testability
**Files**: `EntryDetailViewModel.kt` (line 67), `EntryListViewModel.kt` (line 37)

**Issue**: Both ViewModels use `withContext(Dispatchers.IO)` directly instead of
the injected `@IoDispatcher` pattern used in `MainViewModel` and
`MainRecordingController`.

**Impact**: Tests cannot substitute the IO dispatcher, making coroutine testing
fragile and dependent on real thread switching. Inconsistent with the project's
established DI pattern.

**Recommendation**: Inject `@IoDispatcher` into both ViewModels, matching the
existing pattern.

---

### 12. `onEntriesDeleted` coroutine is not tracked — can race with button taps

**Category**: Reliability
**File**: `MainRecordingController.kt` (lines 77–86)

**Issue**: `onEntriesDeleted` launches an untracked coroutine via `scope.launch`:
```kotlin
scope.launch {
    _recordingState.value = RecordingState.Deleted(count)
    delay(3_000)
    if (_recordingState.value is RecordingState.Deleted) {
        _recordingState.value = RecordingState.Idle
    }
}
```

This coroutine is not stored in a `Job` variable. If `onEntriesDeleted` is
called twice rapidly (e.g., multi-select delete), two coroutines race.
The first one's `delay(3_000)` completes and resets to Idle, then the second
one resets to Idle again — harmless, but if the user tapped the button during
the first Deleted window and started a recording, the second coroutine's
`if (value is Deleted)` guard prevents damage, but only by coincidence.

**Impact**: Minor race; guard happens to work, but the pattern is fragile.

**Recommendation**: Track the job in a `deletedJob: Job?` variable and cancel
the previous one on re-entry, like `resetJob`.

---

## P2 — Medium

### 13. No certificate pinning on API calls

**Category**: Security
**Files**: `DeepgramTranscriptionService.kt`, `OpenAiApiServiceImpl.kt`,
`WhisperTranscriptionService.kt`

**Issue**: All Ktor HTTP clients use the default system trust store with no
certificate pinning. A compromised CA or a MITM proxy (common on corporate/public
WiFi) could intercept API traffic.

**Impact**: Transcript content (raw speech-to-text) and the cleanup prompt are
sent in plaintext to the MITM attacker. API keys in headers are also exposed.

**Recommendation**: Add certificate pinning for `api.deepgram.com` and
`api.openai.com` via Ktor's `SSLConfig` or an OkHttp-based engine with
`CertificatePinner`.

---

### 14. DataStore preferences are stored in plaintext

**Category**: Security
**File**: `PreferencesRepositoryImpl.kt`, backup rules

**Issue**: The DataStore preferences file (`wrait_preferences.preferences_pb`)
contains the privacy mode, selected language, and `hasEverRecorded` flag. While
these aren't diary content, the privacy mode preference reveals whether the user
uses cloud or on-device transcription — a privacy-relevant signal for a
privacy-focused app.

The file is excluded from backup but is readable on rooted devices.

**Impact**: Low — preferences don't contain diary content. But for a
privacy-centric app, every data store should be evaluated.

**Recommendation**: Consider using `EncryptedSharedPreferences` or Jetpack
Security's encrypted DataStore wrapper for preferences.

---

### 15. `MainRecordingController` has `@Inject` annotation but is never Hilt-managed

**Category**: Architecture
**File**: `MainRecordingController.kt` (line 28)

**Issue**: The class constructor is annotated with `@Inject`, but it is
instantiated manually in `MainViewModel`:
```kotlin
private val recordingController = MainRecordingController(
    languageState = languageState, ...
)
```

The `@Inject` annotation is misleading — it suggests Hilt can construct the
class, but it can't (it needs `viewModelScope` which isn't a Hilt-injectable
type).

**Impact**: Confusing for developers. No runtime impact.

**Recommendation**: Remove `@Inject` and mark the constructor as `internal` or
add a comment clarifying the manual instantiation pattern.

---

### 16. `OpenAiApiServiceImpl` does not validate the OpenAI API key at startup

**Category**: Data Flow
**File**: `OpenAiApiServiceImpl.kt`

**Issue**: Unlike `DeepgramTranscriptionService` (which checks
`BuildConfig.DEEPGRAM_API_KEY.isBlank()` at the start of `transcribe()`),
`OpenAiApiServiceImpl.cleanupTranscript()` never checks if the API key is
blank. A blank key results in a 401 from OpenAI, which is caught as
`CleanupResult.Failure("invalid api key")`.

This failure is treated as non-retryable at the API level, but the draft is
kept and retried on every app launch (see Issue #5).

**Impact**: Every recording in MODE_BEST creates a permanent draft that is
retried and fails every startup if the OpenAI key is misconfigured.

**Recommendation**: Add a blank-key guard in `cleanupTranscript()`, matching
the Deepgram pattern.

---

### 17. No user feedback when draft retry succeeds or fails on startup

**Category**: UX
**File**: `MainViewModel.kt` (lines 173–252)

**Issue**: `retryPendingDrafts()` runs silently during `initJob`. If drafts
are successfully finalized, the user never knows their entry was "upgraded"
from draft to final. If all retries fail, there's no indication either.

**Impact**: Users may not realize that stale drafts exist or that background
processing happened.

**Recommendation**: Emit a lightweight notification (e.g., a snackbar or
status line message like "2 drafts finalized") after retry completes, if any
entries were updated.

---

### 18. `listeningStartedAt` uses `System.currentTimeMillis()` instead of `TimeProvider`

**Category**: Data Flow / Testability
**File**: `MainRecordingController.kt` (line 91)

**Issue**: `listeningStartedAt = System.currentTimeMillis()` and the elapsed
check in `stopListening()` both use `System.currentTimeMillis()`. The rest of
the codebase uses an injected `TimeProvider` for testability.

**Impact**: The 5-second minimum recording duration cannot be tested
deterministically.

**Recommendation**: Use the injected `TimeProvider` (add it to the controller's
constructor) for `listeningStartedAt` and elapsed time calculation.

---

### 19. `HttpClient` instances are never closed

**Category**: Reliability
**Files**: `DeepgramTranscriptionService.kt` (line 35),
`OpenAiApiServiceImpl.kt` (line 23), `WhisperTranscriptionService.kt` (line 38)

**Issue**: All three services create `HttpClient(Android)` instances as class
properties but never call `client.close()`. The Ktor documentation recommends
closing the client when it is no longer needed to release connection pool
resources.

Since these services are `@Singleton`, the clients live for the entire app
lifecycle, which mitigates the issue. But if the DI scope ever changes, this
becomes a resource leak.

**Impact**: Low — singletons live as long as the process. But it's a hygiene
issue.

**Recommendation**: Implement `Closeable`/`AutoCloseable` on the services, or
accept the singleton lifecycle and document the decision.

---

### 20. Hardcoded English strings in composables bypass string resources

**Category**: UX / Localization
**Files**: `EntryDetailScreen.kt` (lines 234–235, 300),
`MainScreen.kt` (lines 247–248, 268–288), `ButtonArea.kt` (lines 134–138)

**Issue**: Several user-visible strings are hardcoded in Kotlin code instead of
using `stringResource()`:
- `"Delete this entry?"`, `"This cannot be undone."`, `"Delete"`, `"Cancel"`
  (EntryDetailScreen delete dialog)
- `"Audio draft. Not transcribed yet."` (EntryDetailContent)
- `"wrait"`, `"stop"`, `"new"` (ButtonArea labels)
- `"entry"`, `"entries"`, `"day"`, `"days"` (StatsLine)
- `"tap button to write"`, `"listening…"`, `"uploading…"`, etc. (statusTextFor)

**Impact**: The app cannot be localized. String changes require code
modifications.

**Recommendation**: Extract all user-visible strings to `strings.xml`.

---

### 21. `RecordingState` and `EntrySummary` defined in ViewModel file

**Category**: Architecture
**File**: `MainViewModel.kt` (lines 255–277)

**Issue**: The `RecordingState` sealed class and `EntrySummary` data class are
defined in `MainViewModel.kt`. `RecordingState` is referenced from multiple
layers (Controller, ViewModel, UI composables), making it a cross-cutting
concern that belongs in its own file or in the domain layer.

**Impact**: Violates single-responsibility; file grows with unrelated concerns.

**Recommendation**: Move `RecordingState` to its own file (e.g.,
`RecordingState.kt` in the app package). Move `EntrySummary` to the domain
model package if it's used across layers, or keep it in the ViewModel file if
it's truly ViewModel-scoped.

---

### 22. No loading indicator while entry detail is being fetched

**Category**: UX
**File**: `EntryDetailScreen.kt` (lines 213–225)

**Issue**: When the entry detail screen opens, `entryResult` starts as
`Result.success(null)`. The screen renders nothing during this initial frame:
```kotlin
// entry == null → initial load (null lasts at most one frame); render nothing
```

On slow devices or large databases, this can be more than one frame, resulting
in a visible empty screen before the entry appears.

**Impact**: Perceptible blank screen flash; no visual indicator that content is
loading.

**Recommendation**: Show a lightweight loading indicator (e.g., a shimmer or
`CircularProgressIndicator`) when `entry == null` and `entryResult.isSuccess`.

---

### 23. `insert(onConflict = REPLACE)` can silently overwrite entries

**Category**: Data Flow
**File**: `EntryDao.kt` (line 12)

**Issue**: The DAO's `insert` method uses `OnConflictStrategy.REPLACE`:
```kotlin
@Insert(onConflict = OnConflictStrategy.REPLACE)
suspend fun insert(entry: EntryEntity): Long
```

If an `EntryEntity` is accidentally created with a non-zero `id` that matches
an existing entry, the existing entry is silently deleted and replaced.

**Impact**: Low probability (IDs are auto-generated from 0), but defensively
wrong. A bug in mapping code could trigger unintended data loss.

**Recommendation**: Use `OnConflictStrategy.ABORT` (the default) and handle
conflicts explicitly.

---

### 24. `MediaRecorder()` constructor is deprecated on API 31+

**Category**: Reliability
**File**: `DeepgramTranscriptionService.kt` (line 118)

**Issue**: The no-arg `MediaRecorder()` constructor is deprecated starting
API 31. The app uses `@Suppress("DEPRECATION")` to silence the warning:
```kotlin
@Suppress("DEPRECATION")
val recorder = MediaRecorder()
```

The correct constructor for API 31+ is `MediaRecorder(context)`.

**Impact**: Works today but may be removed in future Android versions.
Suppressing the deprecation hides the migration need.

**Recommendation**: Use a version check:
```kotlin
val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
    MediaRecorder(context)
} else {
    @Suppress("DEPRECATION") MediaRecorder()
}
```

---

### 25. `retryPendingDrafts` reads `openAiApiService` that creates Ktor calls without thread confinement

**Category**: Data Flow / Thread Safety
**File**: `MainViewModel.kt` (lines 173–252)

**Issue**: `retryPendingDrafts()` runs on `ioDispatcher` and calls
`openAiApiService.cleanupTranscript()` and
`transcriptionService.transcribeAudioDraft()`. While Ktor's Android engine is
thread-safe, the `retryAudioDraft` method also calls `File(audioPath).delete()`
outside any dispatcher switch (line 248). If `ioDispatcher` is a limited-
parallelism dispatcher, file I/O on the same thread as network I/O could cause
contention.

More critically, `transcriptionService.transcribeAudioDraft()` goes through
`ModeAwareTranscriptionService.backend()` which reads `privacyMode.first()`.
During retry, the privacy mode is already checked at line 96, but if the user
toggles privacy mode mid-retry, the backend() call could use a different
service than expected.

**Impact**: Unlikely race in practice, but a defensive gap.

**Recommendation**: Capture the privacy mode once at the start of the retry
loop and pass it through, rather than re-reading it per-draft.

---

### 26. Language picker does not close after selection

**Category**: UX
**File**: `MainActivity.kt` (lines 292–298)

**Issue**: The `LanguagePickerSheet` dismisses via `onDismiss`, but when a
language is selected via `onLanguageSelected`, the sheet calls
`onSaveLanguage(code)` without calling `onDismiss`. The user must manually
dismiss the sheet after selecting a language.

Looking at the `LanguagePickerSheet` composable — the `onLanguageSelected`
callback only saves the language. Whether the sheet auto-dismisses depends on
its internal implementation. If it doesn't call `onDismiss` internally, the
user is stuck with the sheet open.

**Impact**: Extra tap required to dismiss the language picker after selection.

**Recommendation**: Ensure `LanguagePickerSheet` calls `onDismiss()` after
`onLanguageSelected()`, or handle it in the callback at the call site:
```kotlin
onLanguageSelected = { code ->
    onSaveLanguage(code)
    showLanguagePicker = false
}
```

---

## P3 — Low

### 27. `WhisperTranscriptionService` is compiled and shipped but unreachable

**Category**: Architecture
**File**: `WhisperTranscriptionService.kt` (221 lines)

**Issue**: The Whisper service is fully implemented, annotated with `@Singleton`
and `@Inject`, but never wired into `ModeAwareTranscriptionService`. It
increases APK size and attack surface (contains hardcoded API URL and key usage)
without providing any value.

**Recommendation**: Either remove it from the build or move it to a separate
source set / feature module that is only included when needed.

---

### 28. Commented-out code in `MainRecordingController`

**Category**: Code Quality
**File**: `MainRecordingController.kt` (line 54)

**Issue**:
```kotlin
//            is RecordingState.Saved    -> _recordingState.value = RecordingState.Idle
```

Commented-out code adds noise and suggests incomplete refactoring.

**Recommendation**: Remove the commented line. History is preserved in Git.

---

### 29. Word count calculation duplicated in 4+ locations

**Category**: Code Quality
**Files**: `EntryRepositoryImpl.kt` (lines 22, 36),
`MainRecordingController.kt` (lines 206–207), `MainViewModel.kt` (lines 201,
218, 233), `EntryDetailViewModel.kt` (line 66)

**Issue**: The word-count formula
`text.trim().split(Regex("\\s+")).count { it.isNotEmpty() }` is duplicated
across multiple files with minor variations (`filter` vs `count`, `Regex` vs
`toRegex()`).

**Recommendation**: Extract to a top-level utility function:
```kotlin
fun String.wordCount(): Int = trim().split("\\s+".toRegex()).count { it.isNotEmpty() }
```

---

### 30. Stats count includes drafts — may mislead users

**Category**: UX
**File**: `MainViewModel.kt` (lines 83–85, 152–165)

**Issue**: `entryStats` is computed from `entryRepository.getAllEntries()`, which
includes drafts. The StatsLine shows "X entries · Y days" where X includes
drafts that the user may not consider as real entries.

**Impact**: Minor — drafts are visible in the list, so the count is technically
accurate. But a user who sees "5 entries" but only 3 finalized entries may be
confused.

**Recommendation**: Either filter drafts from the stats computation or add a
visual distinction (e.g., "3 entries · 2 drafts · 4 days").

---

### 31. `EntryDetailViewModel` uses hardcoded `Dispatchers.IO`

**Category**: Code Quality
**File**: `EntryDetailViewModel.kt` (line 67)

**Issue**: Same as Issue #11, but listed separately as a code-quality note.
The `persistEdit` and `confirmDelete` methods use
`withContext(Dispatchers.IO)` instead of the injected dispatcher.

**Recommendation**: See Issue #11.

---

### 32. `SwipeBackThresholdPx` is in pixels — not density-independent

**Category**: UX
**File**: `DesignTokens.kt` (line 35)

**Issue**:
```kotlin
const val SwipeBackThresholdPx = 200f  // px — accumulated overscroll to trigger back
```

This threshold is in raw pixels, meaning it behaves differently on hdpi
(~1.5x), xxhdpi (~3x), and xxxhdpi (~4x) screens. On a low-density device,
200px requires a larger physical swipe; on high-density, it's a tiny flick.

**Impact**: Inconsistent swipe-back feel across device form factors.

**Recommendation**: Convert to dp and resolve to px at runtime:
```kotlin
val SwipeBackThresholdDp = 80.dp  // consistent across densities
```

---

### 33. No ProGuard/R8 rules for Ktor serialization models

**Category**: Architecture
**File**: `app/proguard-rules.pro` (not reviewed, but no Ktor rules visible in
`build.gradle.kts`)

**Issue**: `DeepgramResponse`, `DeepgramResults`, `DeepgramChannel`, and
`DeepgramAlternative` are `@Serializable` data classes used for Ktor JSON
deserialization. If R8 renames or strips these classes in the release build,
JSON deserialization will fail silently (returning null fields) or crash.

**Impact**: Release builds may fail to parse Deepgram responses.

**Recommendation**: Verify `proguard-rules.pro` includes keep rules for
`kotlinx.serialization` and the Deepgram/OpenAI model classes. The standard
kotlinx-serialization Gradle plugin should handle this, but verify with a
release-mode test.

---

### 34. Inconsistent TAG usage across classes

**Category**: Code Quality
**Files**: Various

**Issue**: Some classes use a `companion object` TAG constant
(`MainRecordingController`, `MainViewModel`, `DeepgramTranscriptionService`),
while others use inline string literals (`"EntryRepository"`,
`"EntryDetailViewModel"`). The class name in the tag doesn't always match the
actual class name (e.g., `"OpenAiApiService"` vs `OpenAiApiServiceImpl`).

**Recommendation**: Standardize on a `companion object` TAG pattern matching
the actual class name.

---

### 35. `resolveActivity()` returns null on API 30+ due to package visibility

**Category**: UX
**File**: `EntryDetailScreen.kt` (line 174)

**Issue**:
```kotlin
if (intent.resolveActivity(context.packageManager) != null) { ... }
```

Starting Android 11 (API 30), `resolveActivity()` requires a `<queries>`
declaration in the manifest to see other apps. Without it, the method always
returns `null`, and the share button shows the "unavailable" toast instead of
the share sheet.

**Impact**: Share button may appear broken on API 30+ devices unless
`<queries>` is declared or the check is removed (since `Intent.createChooser`
doesn't require it).

**Recommendation**: Remove the `resolveActivity()` check. Wrap
`context.startActivity(Intent.createChooser(...))` in a try-catch for
`ActivityNotFoundException` (which is already done). The chooser itself
handles the "no apps available" case.

---

## Appendix: Dependency CVE Check

Key dependencies to validate:

| Package | Version | Notes |
|---------|---------|-------|
| `net.zetetic:sqlcipher-android` | 4.14.1 | Check for SQLCipher CVEs |
| `com.google.crypto.tink:tink-android` | 1.21.0 | Check for Tink CVEs |
| `io.ktor:ktor-client-android` | 3.4.2 | Check for Ktor CVEs |
| `com.google.dagger:hilt-android` | 2.59.2 | Check for Hilt CVEs |
| `androidx.room:room-runtime` | 2.8.4 | Check for Room CVEs |

**Scan result (April 14, 2026)**: No known CVEs found for:
`sqlcipher-android@4.14.1`, `tink-android@1.21.0`, `ktor-client-core@3.4.2`,
`ktor-client-android@3.4.2`, `hilt-android@2.59.2`, `room-runtime@2.8.4`,
`datastore-preferences@1.2.1`, `kotlinx-coroutines-android@1.10.2`.

**Recommendation**: Integrate GitHub Dependabot / Renovate for continuous
monitoring. Run periodic scans as dependencies are updated.

---

*End of issues and findings document.*


