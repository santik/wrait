# wrait

*One button. Your voice. Your words. Stays on your phone.*

A minimal Android voice diary. Open it, tap the button, talk, tap again. Your entry is saved, cleaned up, and kept encrypted on your device. Nothing is stored in the cloud. There is no account.

---

## What it does

wrait records your voice, transcribes it, sends the transcript to an AI for cleanup (removing filler words and fixing punctuation), then saves the result encrypted on your phone. The audio is discarded the moment transcription is done.

The core loop takes about thirty seconds.

---

<p align="center">
  <img src="docs/light_start.png" width="170">
  <img src="docs/light_listening.png" width="170">
  <img src="docs/light_setting.png" width="170">
</p>

---

<p align="center">
  <a href="https://github.com/santik/wrait/releases/latest">
    <img src="https://img.shields.io/github/v/release/santik/wrait?label=download&style=for-the-badge" alt="Download latest release">
  </a>
</p>

---

## Privacy model

### What stays on your device

- All diary entries — both the raw transcript and the cleaned text
- The encryption key (protected by Android Keystore hardware)
- Your language preference
- Your anonymous device ID (stored encrypted on-device)

### What leaves your device

This depends on your selected **mode** (see below). In the default **Best** mode:

1. **Voice audio** is sent to the wrait backend proxy (`/api/transcribe`), which forwards it to [Deepgram](https://deepgram.com) (Nova-3) for transcription. The Android app no longer calls Deepgram directly.

2. **The raw transcript text** (not the cleaned entry) is sent to the wrait backend proxy (`/api/cleanup`), which forwards cleanup to OpenAI's GPT API. Same stateless model — no session, no history.

The cleaned entry text never leaves your device.

In **Offline** mode, no recording audio or transcript text leaves your device — transcription runs on-device via Android SpeechRecognizer.

On app launch, an anonymous device ID may still be sent to the wrait backend to register the device for the beta service.

### Offline mode

wrait has two modes, switchable at runtime from the settings panel (tap the settings icon in the top-right corner or swipe down from the top of the main screen):

| Mode | Transcription | Cleanup | Network required |
|------|--------------|---------|-----------------|
| **Best** | Backend proxy (Deepgram cloud STT) | Backend proxy (OpenAI gpt-4o-mini) | Yes |
| **Offline** | Android SpeechRecognizer (on-device) | None | No |

The selected mode takes effect on the next recording. No restart needed.

Offline mode requires an offline speech model for the selected language to be installed on the device. If the model is missing, the app shows "offline model not installed" when you try to record.

### What is never sent anywhere

- Cleaned diary entry text
- Location
- Any account information (there is no account)

### Local storage security

Entries are stored in a SQLite database encrypted with [SQLCipher](https://www.zetetic.net/sqlcipher/). The SQLCipher password is generated randomly, encrypted with [Tink](https://developers.google.com/tink) AEAD, and stored in shared preferences — the Tink keyset itself is protected by Android Keystore and never leaves the device. If you factory reset your phone, your entries are unrecoverable — this is intentional. Google's automatic cloud backup is explicitly disabled (`android:allowBackup="false"`).

Screenshots and the recent apps thumbnail are blocked via `FLAG_SECURE`.

---

## Backend

The Android app relies on a separate backend service for **Best** mode and beta device registration. That backend lives in its own repository:

- [wrait-backend](https://github.com/santik/wrait-backend)

The app talks to that service through these endpoints:

- `/api/register` for anonymous device registration
- `/api/transcribe` for speech-to-text proxying
- `/api/cleanup` for transcript cleanup proxying

By default, the app uses `https://wrait-backend.vercel.app` as `BACKEND_URL`. If you're running your own backend deployment, set `BACKEND_URL` in `local.properties` to point at that compatible instance.

---

## Building from source

### Requirements

- Android Studio Hedgehog or later
- JDK 17
- Android SDK 34
- A physical Android device (API 26+) or emulator

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/wrait.git
   cd wrait
   ```

2. Create `local.properties` in the project root (this file is never committed):
   ```properties
   sdk.dir=/path/to/your/Android/sdk
   PRIVACY_MODE=MODE_BEST
   BACKEND_URL=https://wrait-backend.vercel.app
   PROXY_SECRET=...
   ```
   Set `PRIVACY_MODE=MODE_OFFLINE` to default to on-device-only mode.

3. Open in Android Studio and sync Gradle.

4. Run on a device or emulator:
   ```bash
   ./gradlew installDebug
   ```

### Running the tests

Instrumented tests run on a connected device or emulator:

```bash
./gradlew connectedAndroidTest
```

These are functional integration tests — they run against a real in-memory database and real ViewModels. There are also JVM unit tests for backend and UI logic.

---

## Architecture

Single-module Android app written in Kotlin with Jetpack Compose.

```
com.wrait.app/
├── ui/           Compose screens and components
├── viewmodel/    ViewModels, UI state sealed classes
├── repository/   EntryRepository, PreferencesRepository
├── data/
│   ├── db/       Room entities, DAOs, encrypted database
│   ├── api/      Backend/OpenAI API clients
│   └── prefs/    DataStore and EncryptedSharedPreferences
├── audio/        SpeechRecognizerManager
├── di/           Hilt modules
└── util/         DesignTokens, RecognitionConfig, extensions
```

### Transcription backends

Offline mode is a runtime user setting (settings icon or swipe down → settings panel) backed by DataStore. The default is set at build time via `PRIVACY_MODE` in `local.properties`:

- **`MODE_BEST`** — backend-proxied Deepgram Nova-3 STT (network) + backend-proxied OpenAI gpt-4o-mini cleanup (network). Draft-first pipeline: entry is written to DB before any API call.
- **`MODE_OFFLINE`** — Android `SpeechRecognizer` (on-device). No cleanup, no network calls. Entry saved immediately as final. Requires offline speech model for the selected language.

`ModeAwareTranscriptionService` reads the current DataStore value at call time, so switching modes takes effect on the next recording without restarting the app.

**Key decisions:**

- `StateFlow` throughout — no LiveData
- Draft-first pipeline: entry is written to the database before any API call. If the network drops mid-cleanup, your words are already safe.
- No Accompanist — microphone permission uses stable `ActivityResultContracts`
- Sealed result classes for all fallible operations — no exception propagation through the pipeline
- SQLCipher key protected via Tink AEAD + Android Keystore. If Keystore material becomes invalid, encrypted state is cleared and the DB setup is recreated.

---

## Known v1 limitations

- **No export.** Planned for v2 (plain text markdown files, one per entry).
- **No backup.** Factory reset means data loss. This is documented in the beta guide.
- **No biometric or PIN lock.** App-level lock planned for v2 as an opt-in setting.
- **No search.** Planned for a later version once there are enough entries to make it useful.
- **2-minute recording cap.** By design — longer recordings degrade cleanup quality and push the app toward voice memo territory.
- **Android only.** No iOS plans in the near term.
- **Secrets in binary/config.** In the closed beta build, the backend configuration values are compiled into the APK via `BuildConfig`. This is acceptable for a private friends-and-family beta with hard spend caps set on the upstream services.

---

## License

MIT. See [LICENSE](LICENSE).

---

*wrait — speak your mind. keep it private.*
