# Agent Findings

This file is the compact, active guidance index for future coding sessions.
Keep it focused on durable implementation constraints that should affect new
work.

When a detail here conflicts with `AGENTS.md`, `CONSTITUTION.md`, or an
approved story artifact, treat the formal workflow artifact as the gate and use
this file as supporting implementation memory.

## Startup, Bootstrap, and App Lock

- Keep startup non-blocking: `runApp()` should happen before heavier launch
  initialization, and bootstrap loading/retry UI stays owned by `lib/main.dart`.
- Preserve single-flight bootstrap retry behavior. Retry actions must not
  create overlapping launch work.
- Start app-wide launch side effects from the bootstrapped `ProviderContainer`
  in `main.dart`, not route builders or widgets.
- Backend device registration is non-blocking and launch-scoped. Failures are
  logging-only unless a future story explicitly changes the user-visible
  contract.
- Draft retry runs only after successful launch registration, and it waits for
  a future app launch if registration fails and later recovers in-session.
- Keep app lock at the root through `AppLockGate` in `lib/app.dart`; do not add
  screen-specific privacy locks for ordinary sensitive routes.
- Do not relock on `AppLifecycleState.inactive`. Native biometric UI can emit
  transient inactive transitions and trigger prompt restart loops.
- App-lock auth and device-security settings opening are single-flight and
  timeout/retry aware. Preserve those guards when touching lock flow code.

## Settings Screen

- Settings is routed at `/settings` from the main screen gear icon;
  `focusTranscriptionLanguage` scrolls and focuses the language dropdown.
- Settings changes are guarded by `activityActive` (recording or transcription
  in progress).
- Use one activity message for all settings sections — do not add
  section-specific activity messages.
- Keep Settings behind `AppLockGate`; do not add a separate settings lock.

## Capture Privacy

- Android capture protection lives in
  `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt` through
  `FLAG_SECURE`.
- Keep `FLAG_SECURE` applied before `super.onCreate(...)` and reasserted after
  `super.onCreate(...)`, on resume, and on focus return unless a future story
  revalidates a simpler lifecycle.
- Android app-lock production wiring depends on `MainActivity` remaining a
  `FlutterFragmentActivity`, `android.permission.USE_BIOMETRIC`, and
  AppCompat-compatible launch/normal theme parents.
- iOS capture privacy lives in `ios/Runner/SceneDelegate.swift` as a native
  scene-level cover. Keep privacy changes at that scene boundary by default.
- The iOS privacy cover copy should stay generic and non-sensitive. Current
  validated copy is `Private`.
- For Android capture work, prefer evidence from cold start, `dumpsys window`
  secure-flag inspection, black foreground/recents screenshots, and a decoded
  frame from `screenrecord`.
- For iOS simulator validation, `xcrun simctl io booted recordVideo` did not
  toggle `UIScreen.main.isCaptured` in this environment. Use SplashBoard
  snapshot inspection for app-switch/background cover validation when direct
  app-switcher automation is unavailable.

## Android Identities and Deployment

- Release/update Android package ID: `com.wrait.flutter`.
- Debug/profile Android package ID: `com.wrait.flutter.dev`.
- Historical or external notes may mention `com.wrait.app`; verify actual
  installed package names before debugging, uninstalling, or scraping logs.
- Production backend connectivity on Android depends on
  `android.permission.INTERNET` in
  `android/app/src/main/AndroidManifest.xml`.
- The Android manifest intentionally disables Impeller with
  `io.flutter.embedding.android.EnableImpeller=false` because physical-device
  cold launches could hang behind the splash screen while Vulkan/Impeller was
  active.
- Prefer `./deploy_debug.sh` for real-device Android debug deployment when a
  story depends on backend registration, transcription, or proxy-authenticated
  traffic.
- `./deploy_debug.sh` requires exactly one connected physical Android phone,
  ignores emulators, runs `flutter test --no-pub -d <phone> integration_test`,
  then installs the profile APK as the final deployed debug/profile artifact.
- Set `PROXY_SECRET` before running `./deploy_debug.sh`; the app must send the
  backend `X-Proxy-Secret` header from runtime config.
- The debug deploy script temporarily enables the namespaced global setting
  `com.wrait.flutter.debug.automation_lockscreen_mode` and USB stay-awake, then
  restores both on success and failure.
- The debug deploy script must never uninstall `com.wrait.app`; it should also
  preserve any pre-existing release install.
- Prefer `./deploy_release.sh` for physical-phone release deployment when the
  stable release identity or update-compatible installs matter.
- Current private release config lives in the ignored
  `android/local.properties`; runtime values are passed through transient
  build defines and signing passwords remain environment-only.
- Release signing passwords stay transient in
  `WRAIT_RELEASE_KEYSTORE_PASSWORD` and `WRAIT_RELEASE_KEY_PASSWORD`.
- `./deploy_release.sh` should validate the configured keystore with `keytool`
  before building and must preserve pre-existing debug/profile installs.

## Branding Assets

- Android launcher icons are adaptive-icon XML resources, not generated PNGs.
- Reference structure for Android launcher branding is
  `android/app/src/main/res`.
- Main Android release launcher resources live under
  `android/app/src/main/res/mipmap-anydpi/` and
  `android/app/src/main/res/drawable/`.
- Android debug/profile launcher overrides should stay limited to
  `android/app/src/debug/res/drawable/` and
  `android/app/src/profile/res/drawable/`.
- Android launcher branding should remain background color plus the `wrait`
  wordmark only; release uses the button-color background and debug/profile
  use the red background.
- iOS app icons remain raster assets in
  `ios/Runner/Assets.xcassets/AppIcon.appiconset/` and
  `ios/Runner/Assets.xcassets/AppIconDebug.appiconset/`, but their source rule
  is full background plus `wrait`, with no inner circle.
- `tool/branding/generate_assets.sh` now owns only the iOS app-icon and launch
  image PNG generation; do not treat it as the Android launcher source of
  truth.
- If `FLAG_SECURE` causes Android recents screenshots to go black, verify
  launcher packaging from the built APK with `aapt` and `unzip -l` instead of
  relying on overview screenshots alone.

## Data, Drafts, and Persistence

- The encrypted local entry store uses Drift plus the `sqlite3mc` runtime
  selected through `hooks.user_defines.sqlite3.source: sqlite3mc`.
- Entry classification source of truth is `Entry.type` with
  `EntryType.draft` and `EntryType.saved`; do not reintroduce `isDraft` as a
  runtime classification field.
- Database open must verify cipher availability with `PRAGMA cipher;` and fail
  startup explicitly if encryption support is missing.
- Keep database opening behind the first-frame bootstrap shell. Do not move it
  back to a fully blocking pre-UI startup path without an approved story.
- `LocalEntryDatabase.open()` should fail closed on corruption or open errors
  and leave database artifacts untouched.
- The supported type-based entry store lives in `wrait_entries_v2.sqlite`.
  Legacy `wrait_entries.sqlite` entry data is intentionally left untouched and
  is not migrated or interpreted by the current app.
- Keep the database-level `type` constraint limited to `draft` and `saved`,
  and keep repository parsing validation as defense in depth for corrupted
  current-shape databases.
- `deleteDatabaseArtifacts()` is destructive and should stay reserved for
  explicit reset flows, not automatic bootstrap recovery.
- Same-identity Android and iOS app updates should preserve the encrypted
  database and linked app-private retained files.
- Uninstall/reinstall and Android `pm clear` should start from fresh local
  state. Android backup/restore is intentionally disabled for this lifecycle.
- On iOS, keep the encrypted entry database in
  `Library/Application Support/wrait_entries_v2.sqlite` and keep user-visible
  CSV exports under `Documents/Wrait Exports`.
- US-039 intentionally ships without an iOS database-location migration path
  because there were no shipped iOS users to preserve for that rollout.
- Retryable draft audio paths should be stored as
  `app-cache://<relative-path>` under the current app temporary directory, not
  absolute iOS container paths.
- Do not reintroduce basename fallback or legacy absolute-path recovery for
  retained draft audio. Unsafe references should fail explicitly.
- Stale drafts older than seven days are deleted before pending drafts are
  loaded for retry.
- Pending drafts retry newest-first, and one failed draft must not block later
  drafts in the same launch pass.
- Audio drafts with blank, missing, unreadable, or empty retained files should
  be deleted instead of retried indefinitely.
- Audio transcription failure preserves the audio draft and retained file.
- Audio transcription success followed by cleanup failure should preserve a
  text draft at the same entry id and delete no-longer-needed retained audio.
- Entry export is a manual CSV action on `/entries`. It includes saved and
  draft entries, omits retained audio paths/files, and must not mutate entry
  state.
- Entry import is also a manual `/entries` action and accepts only
  Wrait-produced CSV. It is additive-only: preserve imported draft vs saved
  state as-is, ignore CSV ids, force imported `audioPath` to null, and never
  update or delete existing rows.
- The current Wrait CSV contract is
  `type,created_at,language,word_count,raw_transcript,cleaned_text,tags`.
  Import must accept both 6-column (pre-tags legacy) and 7-column files for
  backward compatibility. Older Wrait CSVs with `id` or `created_at_epoch_ms`
  are intentionally rejected.
- Database schema v2 adds `tags` (id, name with COLLATE NOCASE) and
  `entry_tags` (entry_id, tag_id with ON DELETE CASCADE on entry_id) tables.
  Migration is additive-only (CREATE TABLE IF NOT EXISTS).
- Tag system limits are enforced at the repository level: 10 tags, 15-char
  max. Do not move limit enforcement to the DAO or UI layer.
- CSV import tag assignment depends on `importEntries` returning inserted IDs.
  The one-by-one insert inside a transaction (not batch) is the accepted
  tradeoff.
- `EntryRepositoryImpl` stream composition must guard `controller.add` and
  `controller.addError` with `!controller.isClosed` because async tag mapping
  can outlive stream cancellation.
- `created_at` import uses the raw stored integer value and currently rejects
  values above `2100-01-01T00:00:00Z` (`4102444800000`) in
  `lib/domain/service/entry_import_service.dart`.
- Import validation lives primarily in
  `lib/domain/service/entry_import_service.dart`, with native picker/read
  bridges in `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
  and `ios/Runner/AppDelegate.swift`. Keep user-facing import errors
  categorized and sanitized (`invalid format`, `unreadable file`, `too large`,
  `save failed`) rather than surfacing raw platform diagnostics.
- Import currently enforces a 10 MB total file limit plus per-field byte caps.
  Keep those checks at both the native boundary and the Dart service layer.
- Same-second export requests append `-1`, `-2`, and later suffixes to the
  CSV filename to avoid collisions.
- Android export prefers public `Downloads/Wrait` on API 29+ and falls back to
  an app-specific downloads directory on older Android versions. Keep the path
  label clear when the fallback is app-specific.
- Export failures intentionally keep user-facing messages generic while
  preserving richer internal diagnostic context in thrown/logged errors.
- The current repo-local Flutter integration harness can validate import flows
  on emulator/simulator with provider overrides and can force fresh native
  rebuilds, but it cannot automate the platform system document picker UI
  itself. Record that limitation explicitly in future validation evidence when
  native picker interaction is not manually verified.

## Backend and Generation

- Backend contract source of truth: `api/wrait-backend.yaml`.
- If that file changes, run `npm run build` before `flutter pub get`,
  `flutter analyze`, or `flutter test`.
- Generated backend output lives under
  `tool/openapi-generator/output/backend_api/` and is local build output, not
  committed source.
- App code should depend on
  `lib/data/api/generated/backend_api_generated.dart`, the compatibility bridge
  over the generated package.
- Backend base URL comes from `AppConfig.backendUrl`.
- Proxy authentication comes from `AppConfig.proxySecret` through
  `X-Proxy-Secret`.
- Device identity comes from `PreferencesRepository.getDeviceId()` through
  `X-Device-Id`.
- Keep app-specific backend policy in the handwritten adapter layer; do not
  leak generated package types into feature code.
- Current app-facing backend failures are intentionally narrower than transport
  errors: proxy auth failed, request too large, quota exceeded, backend
  unavailable, no internet, timeout, and generic API error.
- Shared session quota has one owner: `sessionRecordQuotaStateProvider`.
  Quota-aware work should update or read that provider instead of adding a
  parallel cache.

## Recording, Transcription, and Cleanup

- Recording service contract stays narrow: `startRecording(outputPath)`,
  `stopRecording()`, `isRecording`, and `hardCapDeadlineElapsedRealtime`.
- Recording output is file-based AAC Low Complexity in an M4A container,
  16 kHz, mono.
- The 5-second minimum recording rule is enforced in the service, and too-short
  output files are deleted before returning control to callers.
- The service owns recorder lifecycle, active-session bookkeeping, and cleanup
  of invalid or aborted partial output.
- The controller/orchestrator owns hard-cap stopping and successful returned
  file cleanup policy.
- When microphone access disappears while listening, use cancel semantics
  instead of normal stop/upload so revoked audio is not uploaded or saved.
- `CloudTranscriptionService` is the app-facing Best-mode transcription
  boundary. UI should not coordinate recorder and backend calls directly.
- Live transcription is sequential: start recording, stop valid recording,
  upload, then return a narrowed app-facing success or failure.
- The transcription service rejects overlapping live or draft operations.
- `detectedLanguage` is optional. A usable transcript can succeed when backend
  language detection is blank or unsupported.
- Language normalization should reuse `resolveSupportedLanguageCode()` from
  `lib/domain/model/supported_language.dart`.
- `CleanupTranscriptUseCase` is the app-facing Best-mode cleanup boundary.
- Fresh cleanup persists a text draft before the backend request and finalizes
  that same entry only after usable cleaned text is returned.
- Retry cleanup targets an existing draft entry and must fail safely if the
  entry is missing or already finalized.
- Cleanup request truncation is request-only: submit at most 10,000 characters
  while preserving the full stored `rawTranscript`.
- `CloudTranscriptionService` receives a `readLanguageSnapshot` callback; it
  captures one stable snapshot at operation start.
- Explicit language selections propagate as the `language` query parameter on
  `POST /api/transcribe` — never in the multipart body.
- The backend client validates outgoing language codes against
  `supportedLanguageCodes` before sending; invalid codes fail locally without a
  network request.
- Returned `detected_language` stays authoritative for entry metadata and
  cleanup; the user's preference is an optional upstream hint.

## Preferences and Device ID

- Shared preferences are injected once during app bootstrap in `lib/main.dart`.
- Reuse `sharedPreferencesProvider`, `platformDeviceIdProvider`, and
  `preferencesRepositoryProvider`.
- `PreferencesRepository` owns `hasEverRecorded` and `deviceId`.
- Failed writes are hard failures inside the repository.
- Treat `getDeviceId()` as returning one opaque stable app identifier. Feature
  code should not care whether it came from the platform or generated fallback.
- Current resolution order is in-memory cache, stored `app_device_id`,
  platform-provided device ID, then generated fallback ID.
- Newly resolved device IDs are normalized to 64-character lowercase SHA-256
  hex using the app-scoped salt `wrait-v1` before first persistence.
- Preexisting stored values are intentionally returned unchanged; legacy
  migration is explicit future scope.
- `TranscriptionLanguageController` (`transcriptionLanguageControllerProvider`)
  owns language preference lifecycle: load, committed state, single-flight save
  with concurrent chaining, and async snapshots.
- `snapshotLanguage()` must return `null` when the preference is unavailable —
  throwing blocks recording entirely.
- Concurrent `setLanguage()` calls chain after an in-flight save rather than
  silently returning the first save's future.
- The stored key is `transcription_language`; automatic mode removes the key
  rather than storing a sentinel.

## Main Screen and Entry UI

- The root `/` route renders the recording-focused main screen under
  `lib/presentation/main/`.
- Build recording UI on `mainRecordingControllerProvider` rather than
  recreating state in widgets.
- `RecordingControllerState.isActive` is true only for Listening, Uploading,
  and Processing.
- `RecordingSaved` requires a positive `entryId`; invalid cleanup results must
  degrade to `RecordingError.apiFailed` and must not set `hasEverRecorded`.
- Error and Deleted auto-clear timers belong to the controller. Saved feedback
  is UI-owned and clears through `clearSaved()` or a new recording start.
- Preserve `_buttonActionInFlight` style guarding against rapid repeated taps
  while start/stop work is in flight.
- Status copy and status tap behavior are centralized in
  `lib/presentation/main/main_screen_status.dart`.
- Entry-stat derivation is centralized in
  `lib/presentation/main/main_screen_stats.dart`.
- Countdown progress is localized through a `ValueNotifier<double?>` and
  `ValueListenableBuilder`; avoid whole-screen ticking rebuilds.
- Main-screen recording pulse sizing is now derived from the measured action
  button center to the furthest visible safe-area corner, with a temporary
  max-dimension fallback before the first layout measurement completes.
- Keep pulse-diameter guardrails in `ButtonArea`; invalid, undersized, or
  extreme caller-provided values should clamp or fall back instead of driving
  rendering directly.
- Use stable main-screen selectors from
  `lib/presentation/main/main_screen_test_keys.dart` in widget and integration
  tests wherever practical.
- The `/entries` route includes finalized and draft entries, ordered newest
  first in the presentation/controller layer.
- Entry-list search is presentation-only: `entryListSearchQueryProvider` feeds
  `EntryListController.filterEntries` over the materialized entry list. Keep
  search text out of the DAO, SQL/Drift predicates, backend, and logs.
- Search splits whitespace-separated literal all terms and uses Dart's default
  case conversion, not locale-aware/full Unicode case folding. The keyboard
  Search action unfocuses the field while retaining the query and results.
- Entry-list tag search must match individual tag names via
  `entry.tags.any(...)`, never by joining tag names into a single string and
  doing substring matching. The joined-string approach creates false positives
  across tag boundaries.
- Audio-only draft rows remain visible as pending retry state and should not
  navigate to `/entry/:id`.
- Keep row preview, timestamp, and language-label derivation in
  `entry_list_formatters.dart`.
- Delete failures should remain non-destructive in list/detail UI: log and
  leave visible state intact instead of showing false optimistic removal.
- The `/entry/:id` route accepts only positive integer IDs; invalid, missing,
  deleted, or unreadable entries redirect to `/entries`.
- Entry edits update `cleanedText` and `wordCount` only. They do not mutate
  `rawTranscript`.
- Entry-detail auto-save is revision-based and single-flight. Preserve that
  shape when expanding editing.
- Shared entry text now uses the entry-detail screen's localized full weekday
  and long-date presentation plus localized time, then a blank line, then the
  shared body text.
- Entry-list back handling should prefer a real navigator pop when route
  history exists and only fall back to `/` when no prior route can be popped.
- An explicit language selection shows as `Language: <display name>` on the
  main screen; automatic mode hides the indicator.
- The indicator navigates to `/settings?focusTranscriptionLanguage=true` when
  idle; navigation is disabled during active work.
- `supportedLanguageDisplayName()` is the single lookup for display labels;
  compute it once when both Semantics and visible text need it.

## Feedback and Wiredash

- The only feedback entry point is the top-right main-screen icon. The
  preparation flow lives in
  `lib/presentation/feedback/feedback_preparation_sheet.dart` and uses a
  top-anchored `showGeneralDialog` before opening Wiredash.
- Wiredash `2.6.1` is mounted below `AppLockGate` in `lib/app.dart`. Keep it
  lazy and startup-safe; missing `WIREDASH_PROJECT_ID`, `WIREDASH_SECRET`, or
  `WIREDASH_ENVIRONMENT` must not block launch.
- Keep Wiredash credentials in ignored `android/local.properties`, CI secret
  storage, or transient build defines. Never print the SDK secret, and never
  use `wrait-android`, which is legacy and unused.
- The adapter hides Wiredash email and screenshot prompts and does not call
  analytics. `metadata.custom` must be replaced with a clean allowlist map,
  not merged with SDK-provided custom fields. Only broad context, category,
  and trimmed non-blank explicit contact text are allowed. That contact is
  copied to Wiredash's standard `userId` field for console visibility as well
  as custom `reply_contact`. The strict `userEmail` field must remain unset,
  even when the contact looks like an email; the contact is not
  auto-collected or email-validated. Journal content, transcripts, audio,
  paths, identifiers, screenshots, proxy secrets, and raw diagnostics stay
  excluded.
- The direct feedback adapter uses Wiredash internals, so `pubspec.yaml` keeps
  Wiredash exact-pinned at `2.6.1`. Before upgrading it, pass the real-SDK
  adapter contract test with a local HTTP client and repeat Android/iOS
  feedback validation.
- Wiredash `2.6.1` has no public typed API exception classes. Keep the
  generic sanitized failure result and developer-only diagnostic logging.
- The preparation panel must remain top-anchored and fixed-height while the
  keyboard appears. Android uses
  `android:windowSoftInputMode="adjustNothing"`; preserve the panel-height
  and action-gap regression coverage when changing the form.
- Feedback validation uses stable keys from the feedback presentation layer,
  the focused feedback/main-screen widget suite, the deterministic
  `integration_test/main_feedback_flow_test.dart`, and Android/iOS platform
  runs. Do not claim live Wiredash console delivery or payload inspection
  without credentialed runtime evidence.
- iOS integration screenshots can show the native `Private` capture cover, and
  simulator screenshots can be blocked by an existing passcode prompt. Do not
  weaken native capture privacy to obtain form screenshots; record the
  limitation instead.

## Testing and Validation Gotchas

- Tests that pump `WraitApp` but are not specifically about app lock should
  override `appLockEnabledProvider` to `false`.
- Use `dart format` for Dart/Flutter formatting. `flutter format` is not the
  correct formatter command in this toolchain.
- For Android startup or rendering work, verify launcher-style cold start with
  `adb shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity`
  in addition to ordinary `flutter run` checks.
- For update-versus-uninstall persistence, prefer explicit install/update flows
  or `flutter drive --keep-app-running`; `flutter test -d ... integration_test`
  can reinstall or reset app state.
- `./deploy_debug.sh` is not a reliable validator for same-identity
  update-preservation behavior on `com.wrait.flutter`.
- For local-data lifecycle work, validate same-identity update preservation and
  uninstall/fresh-state behavior as separate flows.
- For dependency refreshes, validate generated backend package compatibility
  with at least `flutter pub get` and `flutter analyze` under
  `tool/openapi-generator/output/backend_api`.
- US-049 retired the historic record/drift_dev pins using Flutter 3.47.5 /
  Dart 3.13.4, record 7.1.1 and drift_dev 2.35.0. Six upstream transitive
  constraints remain documented in specs/049-dependency-refresh/evidence/
  dependency-blockers.md (September 28, 2026 audit).
- Root generation isolation is verified by comparing backend generated-part
  hashes before and after build_runner. Keep tool output outside the root
  build.yaml source allowlist; run generated-client checks separately.
- US-049 completed Android native verification but waived remaining iOS work.
  Before iOS release, complete the final-graph rerun and native checks listed
  in AGENTS.md's dependency guidance. The 28-byte iOS recording result is a
  baseline-reproduced unresolved limitation, not a passing recording check.
- Android emulator recording validation has a known split:
  `integration_test/main_recording_controller_flow_test.dart` passes on
  `emulator-5554`, while
  `integration_test/audio_recording_service_flow_test.dart` can stall on a
  provider-graph start/stop case and report `did not complete`.
  US-049 subsequently passed the isolated audio-service suite, including actual
  AAC/M4A file validation, on emulator-5556 with Flutter 3.47.5. Retain the older
  emulator-5554 failure as historical evidence, not a current blanket failure.
- iOS simulator validation for the recording pulse currently has a known
  combined-run flake: `integration_test/main_screen_flow_test.dart` can fail
  intermittently when run in the same command as the touched entry integration
  flows, while the isolated main-screen run and the shared entry-detail plus
  entry-list run both pass. Treat that as a simulator/test-runner limitation
  to document and re-check, not automatic proof of an app-side regression.
- Screenshot-heavy integration coverage works well on emulator/simulator, but
  physical Android verification may need screenshot-free smoke tests for
  timing-sensitive entry detail flows.
- Entry-detail smoke tests always verify editor focus before text injection.
  Require visible software-keyboard insets only in controlled runs using
  `--dart-define=VERIFY_ENTRY_SOFTWARE_KEYBOARD=true`. Zero insets in a general
  device/deploy suite do not by themselves prove a focus failure; software
  keyboard visibility also depends on device and lockscreen configuration.
- Direct emulator bring-up is often more reliable than `flutter emulators`:
  `/Users/alexander/Library/Android/sdk/emulator/emulator -avd Pixel_8_emulator -no-snapshot-load`.
