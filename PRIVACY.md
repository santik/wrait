> This document is a best-effort disclosure for closed beta. Have a qualified legal professional review before any public (non-closed-beta) release.

# wrait Privacy Policy (Closed Beta)

Last updated: 2026-04-13

This privacy policy describes what data the wrait app ("wrait", "we") processes when you record voice diary entries, where that data goes, and the choices you have.

Important: wrait has **no servers**. Your entries are stored **only on your device**. Some data is sent directly from your device to third-party processors (listed below) to provide transcription and text cleanup — unless you switch to Private mode (see section 2).

## 1) What data is collected

When you use wrait, the app may process:

- **Voice audio**: the raw audio you record while creating an entry.
- **Transcript text**: the text transcription of what you said (raw transcript text).

Audio is processed only to produce a transcript. The transcript is then optionally cleaned up (punctuation, filler words) and saved as your diary entry.

What is actually sent to third parties depends on your selected **privacy mode** (see section 2).

## 2) Privacy mode and who data is sent to

wrait supports two modes, switchable at runtime from the settings panel (swipe down from the top of the main screen):

### Best mode (default)

- **Deepgram (transcription)**: **raw audio** is sent to Deepgram's API (Nova-3 model) for speech-to-text transcription.
- **OpenAI (text cleanup)**: the **raw transcript text** is sent to OpenAI's API (gpt-4o-mini) to clean it up (remove filler words, fix punctuation).

The cleaned entry text is never sent anywhere — it stays on your device.

### Private mode

- **No data leaves your device.** Transcription is performed on-device using Android's built-in SpeechRecognizer. There is no cleanup step.

wrait does not send your data to any wrait-operated servers, because there are none.

## 3) Why it is processed

wrait processes and sends the minimum necessary data to:

- Transcribe your recording into text (when using Best mode with an online transcription backend).
- Clean up the transcript text for readability (punctuation and filler words).

wrait does **not** use your data for advertising, analytics, profiling, or marketing.

## 4) How long it is retained

- **On your device**: your saved entries remain on your phone until you delete them in the app or uninstall the app.
- **Audio on your device**: audio is discarded immediately after transcription and is not stored on your device.
- **Deepgram** (Best mode): Deepgram's data retention is described in their privacy policy. See: https://deepgram.com/privacy and https://deepgram.com/privacy#data-retention
- **OpenAI** (Best mode): OpenAI's public API policies state that API data may be retained for up to 30 days for abuse monitoring and is not used to train models unless you opt in. See: https://openai.com/policies/api-data-usage-policies
- **Private mode**: no audio or transcript is sent to any third party, so no third-party retention applies.

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

You can switch to **Private mode** at any time to ensure no future audio or transcript data leaves your device (swipe down from the top of the main screen → toggle "Private mode").

If you want to request deletion of data that may have been processed by third parties (Best mode only):

- **Deepgram**: see Deepgram's privacy policy at https://deepgram.com/privacy
- **OpenAI**: see OpenAI's privacy and deletion information at https://privacy.openai.com/policies

## 7) Contact

If you have questions about this policy or wrait's privacy model, contact:

fedorets.alex@gmail.com
