# Changelog

All notable changes to wrait are documented here.

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
- 7-dot weekly streak row, ambient entry count

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
