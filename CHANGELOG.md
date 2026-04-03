# Changelog

All notable changes to wrait are documented here.

---

## [1.1-beta] — 2026-04-03

Closed beta update. UX improvements, Deepgram STT backend, runtime privacy mode, and onboarding fix.

### UX improvements

- **Tappable stats line** — "12 entries · 8 days" now shows a `›` chevron and navigates directly to the entry list. Tap it as an alternative to swiping up.
- **Tap to read** — After saving an entry the status line reads "tap to read". One tap opens the new entry directly instead of requiring a swipe then a tap.
- **"Tap to write" persists on first launch** — The hint no longer disappears after 4 seconds. It stays until you complete your first recording.
- **Streak dots removed** — The Mon–Sun dot row has been removed. The stats line already shows days active.

### New: Deepgram Nova-3 speech-to-text

- Third STT option alongside Android on-device and OpenAI Whisper
- Strong multilingual accuracy, including mixed-language audio
- Requires a Deepgram API key; audio is sent to Deepgram's servers

### New: Privacy mode (runtime)

- Switch between **Best** (Deepgram STT + OpenAI cleanup) and **Private** (on-device only, nothing leaves your phone) without reinstalling
- Swipe down from the top of the main screen to open the settings panel
- Toggle takes effect on the next recording — no restart needed
- Panel is locked during recording

### Fixes

- Status bar overlap on edge-to-edge layouts resolved
- Swipe gesture conflict between settings panel dismiss and entry list navigation resolved

---

## [1.0-beta] — 2026-04-01

First closed beta release. Friends and family only.

### What's in this release

**Core loop**
- Tap the button, talk, tap again — entry saved
- Up to 2 minutes of recording per entry
- 5-second silence pause tolerance before auto-stopping
- Entries are saved as a local draft before any network call, so your words are never lost even if the connection drops

**Transcription**
- On-device Android speech recognition (no audio ever leaves your phone in default mode)
- Optional OpenAI Whisper backend for higher accuracy (requires your own API key, sends audio to OpenAI)

**AI text cleanup**
- Raw transcript is cleaned up by OpenAI gpt-4o-mini: filler words removed, punctuation fixed, paragraph breaks added
- Cleanup runs after the draft is already saved — if it fails, your draft is kept and retried on next app open
- Supports Dutch, English, German, French, Spanish, Polish, Italian, Portuguese, Turkish

**Entry list and detail**
- Swipe up from the main screen to browse all entries
- Entries shown newest first, with date and word count
- Draft entries shown with an amber label until cleanup completes
- Long-press to select entries for deletion
- Tap any entry to read the full text

**Language picker**
- Ghost label above the button shows the current language
- Tap it to switch — device locale is used by default

**Privacy and storage**
- All entries stored locally in an encrypted SQLite database (SQLCipher + Android Keystore)
- Audio is discarded immediately after transcription
- Google cloud backup explicitly disabled — entries stay on your device only
- Screenshots blocked via FLAG_SECURE

**Design**
- Single screen, one button, no tab bars or menus
- Warm off-white light mode, near-black dark mode
- Pulse ring while listening, button shake on errors
- 7-dot weekly streak row, ambient entry count (streak dots later removed in 1.1-beta)

### Known limitations in this release

- No edit or delete of individual entries from the detail screen (delete via long-press in the list)
- No export — if you uninstall the app, entries are gone
- No biometric or PIN lock
- No search
- Whisper backend requires building from source with your own OpenAI key

### How to install

See [BETA_TESTER_GUIDE.md](BETA_TESTER_GUIDE.md) for step-by-step sideload instructions.

### Feedback

Send feedback via the WhatsApp group or open an issue on GitHub.
