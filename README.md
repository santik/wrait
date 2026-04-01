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
  <img src="docs/dark_start.png" width="170">
  <img src="docs/dark_listening.png" width="170">
</p>

---

## Privacy model

### What stays on your device

- All diary entries — both the raw transcript and the cleaned text
- The encryption key (protected by Android Keystore hardware)
- Your language preference

### What leaves your device

Two things, both in service of transcription and cleanup:

1. **Voice audio** is sent to [OpenAI Whisper](https://openai.com/research/whisper) for transcription. This is a stateless API call — OpenAI does not retain the audio or use it for model training under their standard API terms. The audio is discarded immediately after transcription and never written to disk on the device.

2. **The raw transcript text** (not the cleaned entry) is sent to OpenAI's GPT API for cleanup. Same stateless model — no session, no history.

The cleaned entry text never leaves your device.

### What is never sent anywhere

- Cleaned diary entry text
- Device identifiers
- Location
- Any account information (there is no account)

### Local storage security

Entries are stored in a SQLite database encrypted with [SQLCipher](https://www.zetetic.net/sqlcipher/). The SQLCipher password is generated randomly, encrypted with [Tink](https://developers.google.com/tink) AEAD, and stored in shared preferences — the Tink keyset itself is protected by Android Keystore and never leaves the device. If you factory reset your phone, your entries are unrecoverable — this is intentional. Google's automatic cloud backup is explicitly disabled (`android:allowBackup="false"`).

Screenshots and the recent apps thumbnail are blocked via `FLAG_SECURE`.

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
   OPENAI_API_KEY=sk-...
   ```

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

These are functional integration tests — they run against a real in-memory database and real ViewModels. There are no unit tests.

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
│   ├── api/      OpenAI API service (cleanup + transcription)
│   └── prefs/    DataStore and EncryptedSharedPreferences
├── audio/        SpeechRecognizerManager
├── di/           Hilt modules
└── util/         DesignTokens, RecognitionConfig, extensions
```

### Transcription backends

The STT backend is selected at build time via `STT_BACKEND` in `app/build.gradle.kts`:

- **`android`** — uses Android `SpeechRecognizer` (on-device). Restarts silently across pauses, accumulates partial results, respects silence thresholds and a 2-minute hard cap. No audio leaves the device.
- **`whisper`** — records raw audio with `MediaRecorder`, uploads the `.m4a` file to OpenAI Whisper, emits an explicit `Uploading` UI state during the upload. The audio file is deleted immediately after the API call.

Both backends converge into the same cleanup pipeline after transcription.

**Key decisions:**

- `StateFlow` throughout — no LiveData
- Draft-first pipeline: entry is written to the database before any API call. If the network drops mid-cleanup, your words are already safe.
- No Accompanist — microphone permission uses stable `ActivityResultContracts`
- Sealed result classes for all fallible operations — no exception propagation through the pipeline
- SQLCipher key protected via Tink AEAD + Android Keystore. If Keystore material becomes invalid, encrypted state is cleared and the DB setup is recreated.

---

## Known v1 limitations

- **No edit.** Entry text is read-only after saving. Revisit based on beta feedback.
- **No export.** Planned for v2 (plain text markdown files, one per entry).
- **No backup.** Factory reset means data loss. This is documented in the beta guide.
- **No biometric or PIN lock.** App-level lock planned for v2 as an opt-in setting.
- **No search.** Planned for a later version once there are enough entries to make it useful.
- **2-minute recording cap.** By design — longer recordings degrade cleanup quality and push the app toward voice memo territory.
- **Android only.** No iOS plans in the near term.
- **API key in binary.** In the closed beta build, the OpenAI key is compiled into the APK via `BuildConfig`. This is acceptable for a private friends-and-family beta with a hard spend cap set on the OpenAI account. 

---

## License

MIT. See [LICENSE](LICENSE).

---

*wrait — speak your mind. keep it private.*
