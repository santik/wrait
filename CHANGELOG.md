# Changelog

All notable changes to wrait are documented here.

---

## [1.2-beta] — 2026-04-15

Major UX improvements: edit entries, share entries, swipe-to-delete, language detection, responsive layout, button behavior fixes, and offline mode.

### New features

- **Edit entries** — Finalized entries are now editable in-place on the detail screen. Changes save automatically ~500 ms after the last keystroke with no save button. Draft entries remain read-only.
- **Share entries** — Share a single non-draft entry from the entry detail screen via Android share sheet. Sends date + body text (cleaned text when available, otherwise raw transcript).
- **Swipe right to delete** — Swipe right on any entry card in the entries list to reveal a delete button. Confirmation dialog required before deletion.
- **Language detection** — When using Deepgram transcription, if you speak in a different language than selected, the app detects it and shows "tap to read · detected <lang>" in the status line. The entry is tagged with the detected language.
- **Keep screen on while recording** — The display stays awake during active recording states, preventing the screen from turning off mid-recording.
- **Responsive layout** — UI elements now scale by screen size. The main button uses a continuous ratio (0.56 of screen width) with min/max bounds (160–280 dp) for consistent feel across phones and tablets.
- **Offline mode** — "Private mode" has been renamed to "Offline mode" with an honest description: "Record without internet. Lower transcription quality." The toggle is in the settings panel (swipe down). The app now checks for offline speech model availability before recording starts and shows "offline model not installed" if the model for the selected language is missing.

### Improvements

- **Delete from detail screen** — Added a delete button on the entry detail screen with confirmation dialog. After deletion, you're always returned to the entries list.
- **Keyboard dismissal** — Keyboard and cursor are dismissed before navigating back from the entry detail screen (applies to swipe-down, system back, and back button).
- **Swipe down on empty list** — Swipe-down-to-back gesture now works even when the entry list is empty.

### Fixes

- **"Tap to read" no longer starts a recording** — Tapping the "tap to read" status message now only navigates to the entry without starting a new recording. Previously, tapping the status message would open the entry and simultaneously begin a new recording session.
- **Button tap on "tap to read" starts a new recording** — Tapping the main button while "tap to read" is visible correctly starts a new recording session.
- **Saved state no longer auto-starts recording** — Restoring from a Saved state (e.g. after process death) no longer silently starts a new recording without user intent.
- **Error state auto-clears properly** — The `delayAndReset()` timer no longer cancels itself, so error and saved states now correctly auto-clear to Idle after 3 seconds.
- **Deleted state button behavior** — Tapping the button while "entry deleted" is showing now starts a new recording (previously only reset to Idle).
- **Missing offline model detection** — When offline mode is on and the selected language's speech model is not installed, the app now shows "offline model not installed" instead of the misleading "saved as draft · will retry".
- **Offline mode works without internet** — Recording in offline mode no longer fails immediately when airplane mode is on. The `preferOffline` flag is now correctly passed through the transcription pipeline.
- **Entry list visual jump** — Fixed visual jump when entering or exiting selection mode (selection mode has been removed entirely, see below).
- **Audio draft handling** — Audio drafts are now only saved after recoverable Deepgram errors (network, rate limit, server errors). Empty responses (no speech detected) no longer create drafts that will never resolve.
- **Draft retry UX** — Audio-only draft cards show "pending · will retry" and are non-tappable.

### Removed features

- **Batch select and delete** — Removed multi-select and batch delete from the entries list screen. The screen now supports single-tap navigation only. Swipe right to delete individual entries instead.
- **"Private mode" branding** — Renamed to "Offline mode" throughout the app. The `MODE_PRIVATE` enum value is now `MODE_OFFLINE`.

### Testing

- **Comprehensive test coverage** — Added ~128 tests across DAO, repositories, preferences, database migration, ViewModels, recording controller state machine, all UI screens, and end-to-end user journeys. The suite now has ~141 tests covering all application layers.
- **Test pipeline** — Deploy script now runs the full test suite (unit + instrumented) before every release build. Debug builds use a separate package ID to avoid conflicts with release app data.

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
