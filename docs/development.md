# Development

This document contains developer-facing build, test, and deployment notes for
the Flutter wrait client. It replaces the old root README deployment content so
the top-level README can stay public-facing.

## Android Debug Deployment

Connect and authorize one physical Android phone, then run:

```sh
./deploy_debug.sh
```

The script reads runtime config from the ignored current Flutter file
`android/local.properties`. At minimum, that file must contain:

```properties
PROXY_SECRET=SECRET_WRAIT_VALUE
```

The script:

- finds the single connected Android phone with `adb devices`
- requires `PROXY_SECRET` in `android/local.properties` with no whitespace and
  at least 8 characters so the installed app can authenticate launch
  registration and recording requests
- supports starting from a locked phone with the screen off
- wakes the phone before the real-device test phase and before the final
  verified launch
- may keep the phone awake during the automated run when the automation flow is
  active
- temporarily enables a namespaced Android automation setting so the
  debuggable activity can show over the lock screen during the test phase
- auto-grants `android.permission.RECORD_AUDIO` during the automated test setup
  so recording tests do not block on a permission dialog while `flutter test`
  reinstalls the app under test
- builds the Flutter debug APK for the `flutter test` phase
- runs `flutter test --no-pub -d <phone-serial> integration_test`
- builds the Flutter profile APK for the final installed app
- installs `build/app/outputs/flutter-apk/app-profile.apk` only after tests
  pass
- verifies the built APK exists and is non-empty before install
- re-checks that the phone is still connected before install
- verifies `com.wrait.flutter.dev` is installed after deployment
- verifies the native `com.wrait.app` app is still installed when it was
  present before deployment
- restores the temporary stay-awake and automation-setting values before exit

The Flutter Android debug/profile app installs as `com.wrait.flutter.dev`, so
it can coexist with the release Flutter app `com.wrait.flutter` and the older
native Android app `com.wrait.app`. The deploy script must never uninstall
`com.wrait.app`.

The split between debug-for-tests and profile-for-final-install is deliberate:
the connected validation phone can run the existing Flutter integration flow,
but a standalone debug cold launch can remain stuck on the Flutter splash
screen after deployment. The equivalent profile build launches normally on
that device, so `deploy_debug.sh` installs profile only after the debug test
phase passes.

If no usable Android phone is connected, or if the phone is unauthorized or
offline, the script exits before build/install with a clear error.
Emulator-only deployment is intentionally out of scope for this command.

The script restores the temporary Android stay-awake and automation-setting
values that it changes, but it does not restore the phone's visible screen or
lock presentation state after the run. USB debugging authorization is still
required, and some device policies may block automation until private
credentials are entered manually.

## Android Release Deployment

Prefer `./deploy_release.sh` when validating or installing a release-signed
Android build for the stable package identity `com.wrait.flutter`.

Prerequisites:

- exactly one connected physical Android phone
- release config in the ignored current Flutter file `android/local.properties`
- signing passwords in `android/local.properties` as `KEYSTORE_PASSWORD` and
  `KEY_PASSWORD`, or as `WRAIT_RELEASE_KEYSTORE_PASSWORD` and
  `WRAIT_RELEASE_KEY_PASSWORD`; the same `WRAIT_RELEASE_*` names can also be
  supplied transiently as environment variables

The release script reads signing and runtime configuration from
`android/local.properties`, forwards signing passwords only as in-memory build
environment values, validates signing inputs before building, builds the
release APK, installs it, launches it, and preserves any existing debug app or
native Android app install.

## Android Play Bundle

Use `./deploy_bundle.sh` when creating the release Android App Bundle for Play
Console upload:

```sh
./deploy_bundle.sh
```

By default, the bundle uses the `version` value from `pubspec.yaml`. For a
release-specific version override, pass the Flutter build name and Android
build number directly to the script:

```sh
./deploy_bundle.sh --build-name 1.0.0 --build-number 2
```

The build number must increase for each Google Play upload. These options are
used only for the current bundle; they do not modify `pubspec.yaml` or create a
Git tag.

The bundle script uses the same ignored `android/local.properties` signing,
runtime, and Wiredash configuration as `./deploy_release.sh`, and it performs
the same keystore validation before building. It does not call `adb`, install
the app, or launch the app on a device.

The generated bundle path is:

```text
build/app/outputs/bundle/release/app-release.aab
```

Run `./deploy_release.sh` separately when you need physical-phone release APK
validation before uploading the bundle.

## Manual Debug APK Build

To build the Android debug APK manually with the proxy secret baked into the
Flutter runtime config, run:

```sh
PROXY_SECRET=SECRET_WRAIT_VALUE \
  flutter build apk --debug \
  --dart-define=PROXY_SECRET=SECRET_WRAIT_VALUE
```

The generated APK path is:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

To install that APK on a connected phone:

```sh
adb -s <phone-serial> install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Backend Client Generation

The Flutter backend client is generated from the checked-in OpenAPI contract:

```sh
npm install
npm run build
flutter pub get
```

Generated output is written to:

```text
tool/openapi-generator/output/backend_api/
```

That directory is local build output and is intentionally ignored by Git.

## Common Checks

```sh
flutter analyze
flutter test
flutter build apk --debug
```

When `api/wrait-backend.yaml` changes, run `npm run build` before Flutter
analysis or tests.
