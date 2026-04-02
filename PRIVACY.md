> This document is a best-effort disclosure for closed beta. Have a qualified legal professional review before any public (non-closed-beta) release.

# wrait Privacy Policy (Closed Beta)

Last updated: 2026-04-02

This privacy policy describes what data the wrait app ("wrait", "we") processes when you record voice diary entries, where that data goes, and the choices you have.

Important: wrait has **no servers**. Your entries are stored **only on your device**. Some data is sent directly from your device to third-party processors (listed below) to provide transcription and text cleanup.

## 1) What data is collected

When you use wrait, the app may process:

- **Voice audio**: the raw audio you record while creating an entry.
- **Transcript text**: the text transcription of what you said (raw transcript text).

Audio is processed only to produce a transcript (depending on your transcription backend). The transcript is then cleaned up (punctuation, filler words) and saved as your diary entry.

## 2) Who it is sent to

Depending on your configuration/build, wrait may send data to these third parties:

- **OpenAI (text cleanup)**: after every recording, the **transcript text** is sent to OpenAI's API to clean it up (remove filler words, fix punctuation).
- **OpenAI Whisper (transcription, if enabled)**: if you use a build or setting that selects the Whisper backend, **raw audio** is sent to OpenAI for transcription.
- **Deepgram (transcription, if enabled in the future)**: if you use a build or setting that selects a Deepgram backend (not currently implemented in the app), **raw audio** may be sent to Deepgram for transcription.

wrait does not send your data to any wrait-operated servers, because there are none.

## 3) Why it is processed

wrait processes and sends the minimum necessary data to:

- Transcribe your recording into text (when using an online transcription backend).
- Clean up the transcript text for readability (punctuation and filler words).

wrait does **not** use your data for advertising, analytics, profiling, or marketing.

## 4) How long it is retained

- **On your device**: your saved entries remain on your phone until you delete them in the app or uninstall the app.
- **Audio on your device**: audio is discarded immediately after transcription and is not stored on your device.
- **OpenAI**: OpenAI's public API policies describe how API data is handled and retained (for example, OpenAI has stated that API data may be retained for up to 30 days for abuse monitoring, and is not used to train models unless you opt in). See: https://openai.com/policies/api-data-usage-policies
- **Deepgram** (if used in the future): Deepgram's retention is described in their privacy policy and data retention section. See: https://deepgram.com/privacy and https://deepgram.com/privacy#data-retention

## 5) What is NOT collected

In this closed beta version, wrait does not collect:

- Accounts, usernames, passwords
- Names, email addresses, phone numbers (unless you email us directly)
- Location data
- Advertising identifiers
- Analytics events
- Crash reporting (v1)
- Any diary entry text sent to wrait-operated servers (there are none)
- Any backups or syncing of your entries to wrait-operated servers (there are none)

## 6) Your rights and choices

Because your entries are stored on your device, you can delete your data at any time by:

- Deleting entries in the app, or
- Uninstalling the app

If you want to request deletion of data that may have been processed by third parties:

- **OpenAI**: see OpenAI's privacy and deletion information at https://privacy.openai.com/policies
- **Deepgram** (if applicable): see Deepgram's privacy policy at https://deepgram.com/privacy

## 7) Contact

If you have questions about this policy or wrait's privacy model, contact:

fedorets.alex@gmail.com
