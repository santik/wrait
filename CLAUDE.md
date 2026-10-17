# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Wrait is a voice-first diary app for Android and iOS built with Flutter. The user records a spoken entry, the app sends it to a backend for transcription and cleanup, and stores the result in an encrypted local database. This repository is the Flutter mobile client.

## Build & run

All commands run from the repository root.

### Bootstrap (first time or after `api/wrait-backend.yaml` changes)

```bash
npm install
npm run build              # generates backend API client from OpenAPI spec
flutter pub get
```

The generated package at `tool/openapi-generator/output/backend_api/` is local build output and is not committed to git. Regenerate it before `flutter pub get` or `flutter analyze` whenever the API contract changes.

### Common commands

```bash
flutter analyze                        # lint
flutter test                           # all unit/widget tests
flutter test test/data/entries/entry_database_test.dart   # single test file
flutter test --name 'test name regex'  # single test by name
```

### Integration tests (require a connected device or emulator)

```bash
flutter test -d <device-id> integration_test/entry_list_flow_test.dart
```

### Build

```bash
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
```

### Compile-time configuration

Runtime config is injected via `--dart-define`. Keys are defined in `lib/core/config/app_config.dart`:

- `BACKEND_URL` (default: `https://wrait-backend.vercel.app`)
- `PROXY_SECRET`
- `RECORDING_HARD_CAP_MS` (default: `120000`)
- `WIREDASH_PROJECT_ID`, `WIREDASH_SECRET`, `WIREDASH_ENVIRONMENT`
- `CAPTURE_VALIDATION_MODE` (bool, default false — special launch path for native privacy-cover validation only)

Example: `flutter build apk --debug --dart-define=PROXY_SECRET=...`

### Deployment scripts

- `./deploy_debug.sh` — builds, tests, and installs a debug/profile app on a connected physical Android phone. Requires `PROXY_SECRET` env var.
- `./deploy_release.sh` — builds and installs a signed release APK. Requires `WRAIT_RELEASE_KEYSTORE_PASSWORD` and `WRAIT_RELEASE_KEY_PASSWORD` env vars.
- `./deploy_bundle.sh` — builds a release AAB for store upload.

### CI

Push to `main` triggers `.github/workflows/deploy-internal.yml` which builds a release AAB and deploys to Google Play Internal Testing.

## Architecture

Layered MVVM with Riverpod for state management. No LiveData — `StateFlow` equivalent via `StateNotifier`/`AsyncNotifier` and `StreamProvider` throughout.

```
lib/
  core/           # AppConfig (build-time defines), GoRouter, time helpers
  data/           # Implementations: API client, audio, auth, database, preferences, transcription
  domain/         # Models, repository interfaces, services, use cases
  presentation/   # Screens, controllers, theme — organized by feature area
  l10n/           # ARB-based localization (11 languages)
```

### Key boundaries

- **Backend API**: `api/wrait-backend.yaml` is the contract source of truth. App code imports `lib/data/api/generated/backend_api_generated.dart` (the stable bridge), never the generated package directly.
- **Database**: Drift (SQLite) with SQLCipher encryption. Schema in `lib/data/entries/local_entry_database.dart`. After schema changes, run `dart run build_runner build`.
- **Entries**: Draft-first rule — entries are persisted as `EntryType.draft` before any API call. Stale drafts (>7 days) are cleaned up at launch. Pending drafts are retried on next successful launch registration.
- **Transcription**: Cloud-backed via the wrait backend (`/api/transcribe` + `/api/cleanup`). Language selection is stored locally and sent as an optional query parameter.
- **App lock**: Root-level `AppLockGate` in `lib/app.dart` covers all routes. Tests not about app lock should override `appLockEnabledProvider` to `false`.
- **Capture privacy**: Android uses `FLAG_SECURE` in `MainActivity.kt`; iOS uses a native scene-level cover in `SceneDelegate.swift`.

### Navigation

GoRouter at `lib/core/router/app_router.dart`. Routes: `/` (home/main), `/entries` (list), `/entries/:id` (detail), `/settings`.

### Localization

ARB files in `lib/l10n/`. Template is `app_en.arb`. Config in `l10n.yaml`. Flutter's `generate: true` in `pubspec.yaml` handles codegen.

## Spec-driven development workflow

This project follows a strict **specify → clarify → plan → tasks → analyze → implement → review → fix** loop. Full process in [`CONSTITUTION.md`](CONSTITUTION.md) and [`docs/spec-driven-workflow.md`](docs/spec-driven-workflow.md).

Before starting any non-trivial feature:

1. Create `specs/NNN-feature-name/` from `specs/_templates/`.
2. Fill `spec.md` → **STOP, wait for approval**.
3. Clarify ambiguities → **STOP, wait for approval**.
4. Fill `plan.md` → **STOP, wait for approval**.
5. Fill `tasks.md` → **STOP, wait for approval**.
6. Analyze cross-artifact consistency → **STOP, wait for approval**.
7. Implement against tasks.
8. Create `implementation.md` → **STOP, wait for external `review.md`** (do not create this file).
9. Read review, propose remediation → **STOP, wait for approval** before editing files.
10. After final implementation, propose updates to `AGENTS.md`, `docs/application-description.md`, `docs/agent-findings.md` → **STOP, wait for approval**.

**Hard rules**: silence is not approval. `review.md` is externally authored. Never skip a gate.

## Testing conventions

- Unit and widget tests in `test/`, organized to mirror `lib/`.
- Integration tests in `integration_test/`, each covering a user flow. Require a connected device or emulator.
- Shared integration test utilities in `integration_test/support/`.
- `test_driver/` contains driver entry points for `flutter drive` runs.
- Main-screen tests use stable key selectors from `lib/presentation/main/main_screen_test_keys.dart`.
- Widget/integration tests that pump `WraitApp` but aren't testing app lock should override `appLockEnabledProvider` to `false`.

## Android identities

- Release: `com.wrait.flutter`
- Debug/profile: `com.wrait.flutter.dev`
- Historical references to `com.wrait.app` are stale — verify actual package before debugging.

## Additional references

- [`AGENTS.md`](AGENTS.md) — detailed implementation guidance and accumulated findings
- [`docs/agent-findings.md`](docs/agent-findings.md) — durable implementation constraints
- [`docs/application-description.md`](docs/application-description.md) — product description
- [`CONSTITUTION.md`](CONSTITUTION.md) — governing principles and SDD phase gates
