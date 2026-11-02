> This document is a best-effort disclosure for a public open-source release.
> Have a qualified legal professional review it before distributing the app to
> the general public through an app store or similar channel.

# wrait Privacy Policy

Last updated: 2026-07-13

This privacy policy describes what data the wrait app ("wrait", "we")
processes when you record voice diary entries, where that data goes, and the
choices you have.

Important: your saved entries are stored on your device in an encrypted local
database. The current Flutter app uses a backend service for transcription,
text cleanup, and anonymous device registration.

## 1. What Data Is Processed

When you use wrait, the app may process:

- Voice audio: the raw audio you record while creating an entry.
- Transcript text: the raw text transcription of what you said.
- Cleaned entry text: the edited, diary-ready text returned after cleanup.
- Anonymous device ID: a stable hashed identifier stored on-device and sent
  with backend requests.
- Local app state: draft status, entry timestamps, language metadata, word
  counts, and first-recording state.
- User-created exports: CSV files you explicitly export from the entries
  screen.

Audio is processed to produce a transcript. The transcript is then cleaned up
for readability and saved as your diary entry.

## 2. What Leaves Your Device

The current Flutter app uses the configured wrait backend for the recording
flow:

- Device registration: on app launch, wrait may send the anonymous device ID to
  `/api/register`.
- Transcription: raw voice audio is sent to `/api/transcribe`.
- Cleanup: raw transcript text is sent to `/api/cleanup`.

The backend contract describes `/api/transcribe` as a proxy for upstream
Deepgram transcription. The cleanup endpoint is the backend boundary for
diary-text cleanup. The mobile app does not send cleaned entry text back to
wrait-operated servers after it is saved locally.

The app sends `X-Device-Id` with backend requests. Debug and release builds may
also send `X-Proxy-Secret` when configured.

## 3. What Stays On Your Device

- Saved diary entries
- Draft entries waiting for retry
- The encrypted local database key
- The stored anonymous device ID
- CSV exports until you move, share, or delete them

Audio files are temporary during normal recording. If a recoverable backend
failure occurs, wrait may keep a local audio draft so it can retry later. After
a successful transcription and cleanup path, temporary audio is removed.

## 4. Why Data Is Processed

wrait processes this data to:

- Transcribe a recording into text.
- Clean up the transcript for readability.
- Save and display local diary entries.
- Retry interrupted backend work without losing a draft.
- Enforce backend access and quota policy for anonymous devices.
- Export or import entries when you explicitly request it.

wrait does not use your diary data for advertising, analytics, profiling, or
marketing.

## 5. Local Storage And Device Protections

Saved entries are stored in an encrypted SQLite database using the configured
encrypted SQLite runtime. The database key is generated on-device and stored
through platform secure storage.

Android backup is disabled for the app's private data. Android also blocks
screenshots, screen recordings, and recent-app previews through secure-window
handling. iOS uses a native privacy cover for background and app-switch
snapshots. The app also includes an app-wide lock that uses device-owner
authentication where supported.

## 6. How Long Data Is Retained

- On your device: entries remain until you delete them in the app, clear app
  data, or uninstall the app.
- Local drafts: retryable drafts remain until they succeed, are deleted, or are
  cleaned up by the app's stale-draft handling.
- Local audio: temporary audio is removed after successful processing unless it
  is needed for a retryable draft.
- CSV exports: exported files remain wherever the operating system writes them
  until you delete them.
- Backend and upstream providers: retention depends on the configured backend
  and its upstream processors. For the default hosted backend, review the
  backend operator's deployment and provider policies before public
  distribution.

## 7. What Is Not Collected By The App

The current Flutter app does not collect:

- Accounts, usernames, or passwords
- Names, email addresses, or phone numbers, unless you contact the developer
  directly
- Location data
- Advertising identifiers
- In-app analytics events
- Crash reporting payloads through a crash-reporting SDK
- Cloud backups or syncing of saved entries to wrait-operated storage

## 8. Your Choices

Because entries are stored locally, you can delete your diary data by:

- deleting individual entries in the app
- clearing app data on Android
- uninstalling the app

You can export entries to CSV from the entries screen. Exports are plain CSV
files and are no longer protected by wrait's encrypted local database once
created.

You can import only Wrait-produced CSV files. Import is additive: it creates
new local entries and does not update or delete existing entries.

## 9. Contact

If you have questions about this policy or wrait's privacy model, contact:

fedorets.alex@gmail.com
