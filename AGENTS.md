---

## Instructions for Codex

Act as a senior flutter engineer. You know everything around flutter
development for android and ios. You have deep knowledge about software
architecture, testing and software development best practices.

## Spec-driven development workflow

This project follows a **specify → clarify → plan → tasks → analyze → implement → review → fix**
loop. All artifact responsibilities and phase gate rules are defined in
[`CONSTITUTION.md`](CONSTITUTION.md). Read it before starting any feature work.

Before starting any non-trivial feature:

1. Copy templates from `specs/_templates/` into a new `specs/NNN-feature-name/` folder.
2. Fill in `spec.md` — what and why.
3. **STOP. Present the draft spec and wait for explicit user approval.**
4. Clarify the spec — resolve ambiguities through agent questions.
5. **STOP. Present the finalised spec and wait for explicit user approval.**
6. Fill in `plan.md` — how (architecture, contracts, review approach, and test strategy).
7. Document `integration_test` coverage for every in-scope user flow plus Android emulator and iOS simulator verification in the plan, or request an explicit user-approved exception during planning.
8. **STOP. Present the plan and wait for explicit user approval.**
9. Fill in `tasks.md` — actionable checklist.
10. **STOP. Present the tasks and wait for explicit user approval.**
11. Analyze — verify cross-artifact consistency before coding.
12. **STOP. Present the analysis and wait for explicit user approval.**
13. Implement against the tasks, updating status as you go.
14. Create `implementation.md` with implementation details and validation evidence.
15. **STOP. Wait for an externally provided `review.md` file unless the user explicitly tells you to skip review.**
16. When `review.md` is available, read it and prepare a remediation plan.
17. **STOP. Present the remediation plan and wait for explicit user approval before updating any files.**
18. Implement the approved fixes, updating `spec.md`, `plan.md`, `tasks.md`, `implementation.md`, code, and tests when the review changes scope, approach, or validation.
19. Repeat the review/fix loop if the user tells you the same `review.md` file has been updated for another pass.
20. After the final approved implementation, propose durable updates to `AGENTS.md`, `docs/application-description.md`, and `docs/agent-findings.md` when the completed feature changed product understanding, architecture, or future implementation guidance in a lasting way.
21. **STOP. Present those proposed long-lived documentation updates and wait for explicit user approval before editing them.**

### Hard rules

- After completing any phase output, you MUST stop and wait for the user to
  respond. Do not continue to the next phase, even if you believe approval is
  implied. Silence is not approval.
- `review.md` is authored by an external reviewer. Do not create a review
  template or pre-fill that file as part of normal feature work.
- After reading `review.md`, do not update any files until the user explicitly
  approves the remediation plan.
- Review findings must be judged case by case. If the right response is
  unclear, ask the user instead of applying a default severity rule.
- Final approval requires Android emulator and iOS simulator verification
  unless the user explicitly approved a validation exception during planning.

Full process: see [`docs/spec-driven-workflow.md`](docs/spec-driven-workflow.md).

## Additional project references

- Application description: [`docs/application-description.md`](docs/application-description.md)
- Agent-relevant implementation findings: [`docs/agent-findings.md`](docs/agent-findings.md)

## Current implementation guidance

### Startup and bootstrap behavior

- Keep startup non-blocking. `runApp()` should happen before heavier app
  initialization, and the first-frame loading/retry shell should stay owned by
  the bootstrap UI in `lib/main.dart`.
- Preserve the current single-flight bootstrap/retry behavior. Retrying failed
  launch work must not create duplicate concurrent startup requests.
- Do not move encrypted database opening back into a fully blocking pre-UI
  bootstrap path unless a future approved story explicitly changes that
  startup tradeoff.

### App lock behavior

- The root privacy lock now lives above the router content through
  `AppLockGate` in `lib/app.dart`; future sensitive screens should stay covered
  by that shared gate instead of adding screen-specific lock logic.
- Treat only true foreground exits as relock triggers. Do not re-lock on
  `AppLifecycleState.inactive`; native `local_auth` UI can emit transient
  `inactive` transitions, and treating those as background exits can cause the
  biometric prompt to cancel and restart in a loop on real devices.
- Keep app-lock authentication and device-security settings opening
  single-flight. Future changes should preserve the current timeout-based auth
  recovery and the controller's guard against repeated settings launches.
- Android app-lock production wiring depends on keeping
  `MainActivity` as `FlutterFragmentActivity`, preserving
  `android.permission.USE_BIOMETRIC`, and keeping the AppCompat-compatible
  launch/normal theme parents required by `local_auth_android`.

### Settings screen behavior

- Settings is routed at `/settings` with an optional `focusTranscriptionLanguage`
  parameter for focused dropdown navigation from the main-screen language
  indicator.
- The main screen gear icon is the Settings entry point.
- Settings changes are disabled during active recording/transcription via
  `activityActive`.
- Settings stays behind the existing root `AppLockGate`; do not add a separate
  settings-specific lock.
- The activity message covers all settings sections: use one shared message
  rather than section-specific activity messages.

### Capture privacy behavior

- Android screenshot, screen-recording, and recent-app protection now lives in
  `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt` through
  `FLAG_SECURE`.
- Keep Android capture protection applied before `super.onCreate(...)` and also
  keep the current reassertion points after `super.onCreate(...)`, on resume,
  and on focus return unless a future approved story revalidates and removes
  them. Emulator validation showed Flutter can retarget the live activity
  window later in startup and lifecycle transitions.
- Existing Android debug automation lockscreen mode must remain compatible with
  `FLAG_SECURE`, and any temporary automation-setting changes still need to be
  restored after validation or deploy flows.
- iOS capture privacy now lives in `ios/Runner/SceneDelegate.swift` as a
  scene-level native cover. Keep future privacy changes at that native scene
  boundary rather than adding route-specific Flutter capture-hiding logic by
  default.
- The iOS privacy cover copy should stay generic and non-sensitive. Current
  validated copy is `Private`.
- For stronger Android validation, prefer a four-part evidence set: launcher
  cold start, `dumpsys window` secure-flag inspection, black foreground/recents
  screenshots, and a decoded frame from a `screenrecord` artifact.
- For iOS simulator validation, `xcrun simctl io booted recordVideo` did not
  toggle `UIScreen.main.isCaptured` in this environment. Do not treat simulator
  recording alone as proof that active-capture hiding works.
- When direct app-switcher automation is unavailable on iOS simulator, inspect
  the app's stored SplashBoard snapshot under the simulator app container to
  verify the background/app-switch privacy cover path.
- Secure startup dependencies can still surface a system passcode prompt before
  normal Wrait UI appears on iOS simulator. A compile-time
  `CAPTURE_VALIDATION_MODE=true` launch path exists in `lib/main.dart` only for
  native privacy-cover validation with non-sensitive placeholder content; keep
  production launches on the normal bootstrap path.

### Android debug deployment guidance

- Prefer `./deploy_debug.sh` for real-device Android debug deployment when the
  story depends on backend registration, transcription, or proxy-authenticated
  traffic.
- `./deploy_debug.sh` targets the debug/profile Flutter app identity
  `com.wrait.flutter.dev`. Treat it as a separate install from the release app
  identity `com.wrait.flutter`.
- Set `PROXY_SECRET` before running `./deploy_debug.sh`. The deployed app must
  send the backend `X-Proxy-Secret` header from that runtime config value.
- `./deploy_debug.sh` now uses two Android build artifacts on the validation
  phone:
  - it builds and runs the debug app for the `flutter test` phase
  - it builds and installs the profile APK as the final deployed app because
    the standalone debug install can remain stuck on the Flutter splash screen
    on the physical validation phone even when the debug test phase succeeds
- When you need a manual fallback instead of the deploy script, build the debug
  APK with:
  - `PROXY_SECRET=... /opt/homebrew/bin/flutter build apk --debug --dart-define=PROXY_SECRET=...`
- When you need to manually validate the same final install artifact that
  `./deploy_debug.sh` uses, build and install the profile APK with:
  - `PROXY_SECRET=... /opt/homebrew/bin/flutter build apk --profile --dart-define=PROXY_SECRET=...`
- The current Android manifest explicitly disables Impeller with
  `io.flutter.embedding.android.EnableImpeller=false` because cold launches on
  the physical validation device could hang behind the Android splash screen
  while Vulkan/Impeller was active.
- The deploy script temporarily enables the namespaced Android global setting
  `com.wrait.flutter.debug.automation_lockscreen_mode` so the debuggable
  `MainActivity` can launch over the lock screen during automated runs. Keep
  that automation gate namespaced and restore-on-exit.
- The deploy script temporarily enables USB stay-awake mode and restores the
  previous `stay_on_while_plugged_in` value on exit. Keep that restoration
  behavior intact.
- The deploy script maintains `android.permission.RECORD_AUDIO` during the
  deploy-time Flutter test session because `flutter test` can reinstall both
  `com.wrait.flutter.dev` and `com.wrait.flutter.dev.test`, which would
  otherwise let the system recording prompt reappear on a locked phone.
- Keep the current deploy-script safety checks intact:
  - require exactly one connected physical Android phone and ignore emulators
  - reject missing or empty APK artifacts
  - avoid silently reinstalling stale build output
  - run `flutter test --no-pub -d <phone-serial> integration_test` before any
    final install
  - restore temporary automation and stay-awake settings on both success and
    failure paths
  - verify `com.wrait.flutter.dev` exists after install
  - verify `com.wrait.app` remains installed when it existed before deployment
  - never uninstall `com.wrait.app`

### Android release deployment guidance

- Prefer `./deploy_release.sh` for physical-phone Android release deployment
  when the story depends on the stable release signing identity or
  update-compatible installs.
- `./deploy_release.sh` targets the release Flutter app identity
  `com.wrait.flutter` and should preserve any pre-existing
  `com.wrait.flutter.dev` debug install.
- Current private release config lives in the ignored `android/local.properties`.
- `./deploy_release.sh` synchronizes only non-secret release keys into the
  ignored Flutter-local `android/local.properties`.
- Provide transient signing-password env vars before the release build:
  - `WRAIT_RELEASE_KEYSTORE_PASSWORD`
  - `WRAIT_RELEASE_KEY_PASSWORD`
- `./deploy_release.sh` validates the configured keystore with `keytool`
  before building and should fail before install if signing inputs are missing
  or invalid.
- Keep the release deploy-script safety checks intact:
  - require exactly one connected physical Android phone and ignore emulators
  - reject missing or empty APK artifacts
  - avoid silently reinstalling stale build output
  - verify `com.wrait.flutter` exists after install
  - verify `com.wrait.app` remains installed when it existed before deployment
  - verify `com.wrait.flutter.dev` remains installed when it existed before
    deployment
  - never uninstall `com.wrait.app`

### Testing guidance

- For main-screen integration and widget tests, prefer stable selectors from
  `lib/presentation/main/main_screen_test_keys.dart` instead of visible-text
  lookups wherever practical.
- Main-screen pulse validation is currently more stable on split iOS simulator
  runs than on a single combined command with the other touched entry flows.
  When a story changes recording-pulse behavior, prefer validating
  `integration_test/main_screen_flow_test.dart` separately on iOS simulator and
  record any combined-run flake explicitly instead of treating it as automatic
  app regression.
- Widget and integration tests that pump `WraitApp` but are not explicitly
  about app lock should override `appLockEnabledProvider` to `false` so they
  stay focused on the behavior under test instead of booting behind the root
  privacy gate.
- Reuse existing bootstrap and recording-controller tests before adding new
  startup-specific harnesses.
- For local-data lifecycle work, treat same-identity update validation and
  uninstall/fresh-state validation as separate flows:
  - normal Android and iOS app updates should preserve the encrypted database
    plus linked app-private files
  - uninstall/reinstall should start from fresh local state
  - Android `pm clear` should start from fresh local state
- US-037 is an intentional entry-store exception to the usual update
  preservation guidance: the type-based entry database now lives in
  `wrait_entries_v2.sqlite` and does not migrate or surface the legacy
  `wrait_entries.sqlite` entry file. Do not plan legacy entry-data
  preservation validation for entry-type work unless a future approved story
  explicitly changes that rollout decision.
- On iOS, keep the encrypted entry database under
  `Library/Application Support/wrait_entries_v2.sqlite`, not in
  `Documents`.
- US-039 intentionally does not add a legacy iOS database-location migration
  path because there are no shipped iOS users to preserve for this rollout.
- `./deploy_debug.sh` is not a reliable validator for same-identity
  update-preservation behavior on `com.wrait.flutter` because its
  `flutter test` phase can reinstall or reset app state on-device.
- When a story depends on verifying update-versus-uninstall persistence,
  prefer explicit install/update flows or `flutter drive --keep-app-running`
  instead of `flutter test -d ... integration_test/...`.
- Keep destructive database cleanup explicit. Do not reintroduce automatic
  database-artifact deletion on open failure.
- Entry export now lives on the `/entries` screen and writes CSV files only.
  The export includes saved and draft entries, excludes retained audio files,
  and should stay non-mutating.
- Entry import now also lives on the `/entries` screen and accepts only
  Wrait-produced CSV files. Import is strictly additive, preserves draft vs
  saved state exactly as exported, ignores CSV ids, forces `audioPath` null,
  and must not update or delete existing entries.
- Entry-list text search is presentation-only: keep the query in
  `EntryListSearchQuery`/`EntryListController.filterEntries` over the existing
  materialized list. Do not pass it to a DAO, SQL/Drift predicate, backend, or
  logs. The current literal all-term matching uses Dart's default case
  conversion rather than locale-aware/full Unicode case folding; an indexed or
  internationalized search change requires a future approved story and fresh
  Android/iOS validation.
- Entry-list search now covers cleaned text, raw transcripts, and tag names.
  Tag matching checks each tag name individually via `entry.tags.any(...)`, not
  by concatenating tag names into a single string. The tag filter chip composes
  with text search using AND logic.
- The current Wrait CSV contract is
  `type,created_at,language,word_count,raw_transcript,cleaned_text,tags`.
  Import accepts both 6-column (pre-tags legacy) and 7-column files. Tags in
  CSV are semicolon-separated within the `tags` cell. Do not reintroduce `id`
  or `created_at_epoch_ms` compatibility unless a future approved story
  explicitly changes that contract.
- Database schema v2 adds `tags` and `entry_tags` tables. Migration from v1 is
  additive-only (CREATE TABLE IF NOT EXISTS). The `entry_tags` join table uses
  ON DELETE CASCADE on the entry foreign key.
- Tag system limits: 10 tags per system (`TagRepository.maxTags`), 15
  characters per tag name (`TagRepository.maxTagNameLength`). Tag name
  uniqueness is case-insensitive via COLLATE NOCASE at the database level.
- CSV import tag assignment resolves tag names to IDs (creating missing tags as
  needed), then assigns by returned entry IDs. Tags that fail to create (limit
  exceeded, invalid name) are silently skipped without failing the import.
- Stream composition for `watchAllEntries()` and `watchEntryById()` in
  `EntryRepositoryImpl` combines entry and tag-assignment change signals. Guard
  `controller.add()` and `controller.addError()` with `!controller.isClosed`
  checks because the async mapping may outlive stream cancellation.
- `created_at` in CSV is the raw stored database integer value. Import should
  reject `created_at` values above `2100-01-01T00:00:00Z`
  (`4102444800000`) instead of converting or clamping them.
- CSV import now enforces explicit size limits: reject files above 10 MB and
  reject oversized individual fields before persistence. Keep user-facing
  import failures sanitized by category instead of exposing raw platform or
  parser diagnostics.
- iOS CSV exports live in `Documents/Wrait Exports`, while the encrypted
  database stays in `Library/Application Support`.
- Android export should prefer public `Downloads/Wrait` on API 29+ and may
  fall back to an app-specific downloads directory on older Android versions.
- Same-second export requests can produce `-1`, `-2`, and later filename
  suffixes; treat that as expected collision avoidance, not a bug.
- The native CSV import bridges live in
  `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt` and
  `ios/Runner/AppDelegate.swift`. The current repo-local Flutter integration
  harness can rebuild and run those bridges on emulator/simulator, but it does
  not automate the platform system document picker UI itself; document that
  blocker explicitly instead of claiming unverified picker interaction.
- For Android startup or rendering work, verify a launcher-style cold start
  with `adb shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity`
  in addition to ordinary `flutter run` checks.
- For Android capture-privacy work, also verify secure-flag persistence after
  app-switch/resume with `dumpsys window` instead of relying only on a single
  cold-launch screenshot.
- When a story refreshes Flutter or dependency versions, also validate the
  generated backend package in `tool/openapi-generator/output/backend_api`
  with at least `flutter pub get` and `flutter analyze` so resolver or
  generated-client compatibility drift is caught explicitly.
- `integration_test/transcription_language_settings_flow_test.dart` covers
  dropdown interaction, regional selection, focused navigation from the main
  indicator, and automatic reset.
- Settings-related widget tests should override
  `transcriptionLanguageControllerProvider` with known state to avoid async
  loading in focused tests.
- Tag-related widget tests override `tagRepositoryProvider` with a
  `_FakeTagRepository`. Screens using GoRouter context extensions
  (`context.push`, `context.pop`) need a `MaterialApp.router` with a
  `GoRouter` instance, not a plain `MaterialApp`.
- The "Raw transcript" label in the debug section of `entry_detail_screen.dart`
  is intentionally hardcoded in English without localization. It is a
  developer-only debug surface, not user-facing, so ARB/l10n is not required.
- Current Android emulator validation has a known split for recording flows:
  `integration_test/main_recording_controller_flow_test.dart` passes on
  `emulator-5554`, while
  `integration_test/audio_recording_service_flow_test.dart` can stall on
  `provider graph supports start and valid stop with a completed file path`
  and later report `did not complete`. Treat that as an emulator/test-runner
  limitation to document and re-check, not as automatic proof of an app-side
  regression.

### Feedback integration guidance

- The feedback entry point is the single top-right icon on the main screen;
  do not add a Settings entry point or a second main-screen trigger without an
  approved story.
- Wiredash `2.6.1` is mounted below `AppLockGate` in `lib/app.dart`, is
  configured only when all `WIREDASH_PROJECT_ID`, `WIREDASH_SECRET`, and
  `WIREDASH_ENVIRONMENT` values are present, and must not participate in
  startup/bootstrap work.
- Keep Wiredash values in ignored `android/local.properties`, CI secret
  storage, or transient environment/build-define inputs. Never log or commit
  the SDK secret, and do not use the legacy `wrait-android` directory.
- The feedback adapter must keep email and screenshot prompts hidden, avoid
  Wiredash analytics, and replace `metadata.custom` with a fresh allowlisted
  map containing only approved broad context and explicit contact text. When
  contact is supplied, copy the same trimmed plain-text value to Wiredash's
  standard `userId` field so it survives Wiredash's hidden-email submission
  path; keep the strict `userEmail` field unset, even when the free-text
  contact happens to look like an email. Do not auto-collect or validate it as
  an email. Do not attach journal text,
  transcripts, audio, paths, identifiers, screenshots, proxy secrets, or raw
  diagnostics.
- Wiredash's public `2.6.1` API does not expose typed API exception classes;
  preserve the generic sanitized user-facing failure boundary and use
  developer-only logs for diagnostics.
- The direct feedback adapter is coupled to Wiredash internals and the
  dependency is exact-pinned at `2.6.1` in `pubspec.yaml`. Before any SDK
  upgrade, update and pass the adapter's real-SDK/local-HTTP transport contract
  test, then repeat Android emulator and iOS simulator feedback validation.
- The preparation form is a top-anchored fixed-height dialog. Its keyboard
  layout depends on `android:windowSoftInputMode="adjustNothing"` in the main
  Android manifest, keyboard-inset removal around the dialog, and a fixed
  bottom action gap. Preserve the panel-bound and action-gap regression tests
  when changing this surface.

### Android identity note

- The release/update Flutter Android application/package ID is
  `com.wrait.flutter`.
- The debug/profile Flutter Android application/package ID is
  `com.wrait.flutter.dev`.
- Older notes or external materials may still mention `com.wrait.app`; verify
  the actual installed target before debugging, uninstalling, or scraping
  device logs.
- Production backend connectivity on Android depends on keeping
  `android.permission.INTERNET` in `android/app/src/main/AndroidManifest.xml`,
  not only in debug/profile manifests.

### Launcher branding guidance

- Android launcher branding follows the current resource pattern in
  `android/app/src/main/res` rather than the legacy Android implementation.
- Keep Flutter Android launcher resources hand-authored under:
  - `android/app/src/main/res/mipmap-anydpi/`
  - `android/app/src/main/res/drawable/`
  - `android/app/src/debug/res/drawable/`
  - `android/app/src/profile/res/drawable/`
- Do not reintroduce generated Android launcher PNGs for this app unless a
  future approved story explicitly changes the launcher implementation.
- Android release launcher branding should stay as background color plus the
  `wrait` wordmark; debug/profile should stay red plus the `wrait` wordmark.
- iOS app icons still ship through the asset catalogs, but their source
  artwork should stay full-background plus `wrait`, with no inner circle.
- If secure-surface behavior makes Android recents screenshots unusable for
  launcher verification, inspect packaged APK resources with `aapt` and
  `unzip -l` instead of relying only on overview screenshots.

## Backend API generation guidance

US-005 introduced a build-time OpenAPI generation prerequisite for the Flutter
backend client.

- The backend contract source of truth in this repo is `api/wrait-backend.yaml`.
- If that file changes, run `npm run build` before `flutter pub get`,
  `flutter analyze`, or `flutter test`.
- The generated package under `tool/openapi-generator/output/backend_api/` is
  local build output and is not committed to git.
- App code should depend on
  `lib/data/api/generated/backend_api_generated.dart`, which acts as the stable
  compatibility bridge over the generated package, rather than importing the
  generated package surface directly in feature code.

## Dependency maintenance guidance

US-049 establishes Flutter 3.47.5 / Dart 3.13.4 as the validated baseline.
Use an SDK matching pubspec.yaml; the maintenance run used a separate SDK and
did not upgrade the machine's global installation.

- The historic record 7.0.0 and drift_dev 2.34.0 exceptions are retired:
  record 7.1.1 and drift_dev 2.35.0 passed the approved Android validation.
- Six transitive blockers remain in the September 28, 2026 audit. Refer to
  specs/049-dependency-refresh/evidence/dependency-blockers.md and re-evaluate
  their upstream constraints during future refreshes; do not force overrides.
- Keep the root build.yaml source allowlist. When changing generation tooling,
  verify backend generated parts survive root build_runner execution and run
  generated-package resolution/analysis separately.
- The US-049 iOS validation exception applies only to that maintenance story.
  Before any iOS release, verify the final dependency graph and complete native
  recording, permission, picker/share, authentication, feedback keyboard-layout
  and active-capture checks. The simulator's 28-byte recording outcome reproduced
  with both old and new dependencies and must be resolved and verified before
  release. Approved minimum iOS support is 15.
