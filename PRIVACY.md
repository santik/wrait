> This document is a best-effort disclosure for closed beta. Have a qualified legal professional review before any public (non-closed-beta) release.

# wrait Privacy Policy (Closed Beta)

Last updated: 2026-05-05

This privacy policy describes what data the wrait app ("wrait", "we") processes when you record voice diary entries, where that data goes, and the choices you have.

Important: your entries are stored **only on your device**. Some data is sent from your device to the wrait backend proxy and third-party processors (listed below) to provide transcription, text cleanup, and anonymous device registration — unless you switch to Offline mode for entry processing (see section 2).

## 1) What data is collected

When you use wrait, the app may process:

- **Voice audio**: the raw audio you record while creating an entry.
- **Transcript text**: the text transcription of what you said (raw transcript text).
- **Anonymous device ID**: a stable anonymous identifier derived on-device and stored encrypted locally for beta-service registration and backend requests.

Audio is processed only to produce a transcript. The transcript is then optionally cleaned up (punctuation, filler words) and saved as your diary entry.

What is actually sent to third parties depends on your selected **privacy mode** (see section 2).

## 2) Privacy mode and who data is sent to

wrait supports two modes, switchable at runtime from the settings panel (tap the settings icon in the top-right corner or swipe down from the top of the main screen):

### Best mode (default)

- **wrait backend proxy + Deepgram (transcription)**: **raw audio** is sent to the wrait backend proxy (`/api/transcribe`), which forwards it to Deepgram's API (Nova-3 model) for speech-to-text transcription.
- **wrait backend proxy + OpenAI (text cleanup)**: the **raw transcript text** is sent to the wrait backend proxy (`/api/cleanup`), which forwards cleanup to OpenAI's API (gpt-4o-mini) to remove filler words and fix punctuation.

The cleaned entry text is never sent anywhere — it stays on your device.

### Offline mode

- **No recording audio or transcript leaves your device.** Transcription is performed on-device using Android's built-in SpeechRecognizer. There is no cleanup step.

### Device registration

- On app launch, wrait may send the anonymous device ID to the wrait backend at `/api/register` to register the device for the beta service.

## 3) Why it is processed

wrait processes and sends the minimum necessary data to:

- Transcribe your recording into text (when using Best mode with an online transcription backend).
- Clean up the transcript text for readability (punctuation and filler words).
- Register an anonymous device ID for operation of the closed beta service.

wrait does **not** use your data for advertising, analytics, profiling, or marketing.

## 4) How long it is retained

- **On your device**: your saved entries remain on your phone until you delete them in the app or uninstall the app.
- **Audio on your device**: audio is discarded immediately after transcription and is not stored on your device, unless a recoverable Best-mode failure requires a local draft retry.
- **Deepgram** (Best mode): Deepgram's data retention is described in their privacy policy. See: https://deepgram.com/privacy and https://deepgram.com/privacy#data-retention
- **OpenAI** (Best mode): OpenAI's public API policies state that API data may be retained for up to 30 days for abuse monitoring and is not used to train models unless you opt in. See: https://openai.com/policies/api-data-usage-policies
- **Offline mode**: no recording audio or transcript is sent to any third party, so no third-party retention applies to entry processing in Offline mode.

## 5) What is NOT collected

In this closed beta version, wrait does not collect:

- Accounts, usernames, passwords
- Names, email addresses, phone numbers (unless you email us directly)
- Location data
- Advertising identifiers
- Analytics events
- Crash reporting (v1)
- Any cleaned diary entry text sent to wrait-operated servers
- Any backups or syncing of your entries to wrait-operated servers

## 6) Your rights and choices

Because your entries are stored on your device, you can delete your data at any time by:

- Deleting entries in the app, or
- Uninstalling the app

You can switch to **Offline mode** at any time to ensure no future recording audio or transcript data leaves your device (tap the settings icon in the top-right corner or swipe down from the top of the main screen → toggle "Offline mode").

If you want to request deletion of data that may have been processed by third parties (Best mode only):

- **Deepgram**: see Deepgram's privacy policy at https://deepgram.com/privacy
- **OpenAI**: see OpenAI's privacy and deletion information at https://privacy.openai.com/policies

## 7) Contact

If you have questions about this policy or wrait's privacy model, contact:

fedorets.alex@gmail.com
