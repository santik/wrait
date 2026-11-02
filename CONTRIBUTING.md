# Contributing

Thanks for considering a contribution to wrait, the voice-first diary app.

## Development Setup

You need the Flutter SDK (stable channel) and Node.js 20+.

```sh
npm install
npm run build        # generates the backend API client from the OpenAPI spec
flutter pub get
```

`npm run build` regenerates the local backend client at
`tool/openapi-generator/output/backend_api/` (not committed). Re-run it whenever
`api/wrait-backend.yaml` changes, before `flutter pub get` or `flutter analyze`.

### Compile-time configuration

Runtime config is injected with `--dart-define` (keys in
`lib/core/config/app_config.dart`), for example:

```sh
flutter run --dart-define=PROXY_SECRET=... --dart-define=BACKEND_URL=...
```

## Checks before a pull request

```sh
flutter analyze
flutter test
```

Integration tests live in `integration_test/` and require a connected device or
emulator; the wrapper `tool/run_integration_tests.sh` grants microphone access so
the native permission dialog does not hang the run.

## Pull Requests

- Keep changes focused.
- Include tests for behavior changes.
- Document Android emulator and iOS simulator validation for user-facing flows,
  or explain the validation gap.
- Do not commit secrets, local signing files, `android/local.properties`,
  generated backend output, or build artifacts.
- Use conventional commit-style titles where practical, for example
  `fix(recording): stop timer leak on dispose`.

## Reporting Issues

When reporting a bug, include:

- platform and OS version
- app build type and version
- expected behavior
- actual behavior
- reproduction steps
- relevant logs, with private diary content removed

Please report security or privacy issues privately — see
[SECURITY.md](SECURITY.md).
