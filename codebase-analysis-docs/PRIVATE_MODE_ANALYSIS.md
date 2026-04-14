# Private Mode — Honest Assessment

> **Date**: April 14, 2026  
> **Question**: Is `MODE_PRIVATE` delivering on its promise? Should it be kept?

---

## What Private Mode Promises

The settings panel tells the user:

> **Private mode**  
> *"Transcription stays on-device, nothing is sent to the cloud."*

---

## What Actually Happens

### MODE_BEST (private mode OFF)

| Step | Data | Destination | Retention |
|------|------|-------------|-----------|
| 1. Record | Raw audio | Stays on device | Temp file, deleted after |
| 2. Transcribe | Audio bytes | Deepgram API (cloud) | Stateless — discarded |
| 3. Cleanup | Raw transcript text | OpenAI API (cloud) | Stateless — no history |
| 4. Save | Final entry | On-device (encrypted) | Permanent until deleted |

### MODE_PRIVATE (private mode ON)

| Step | Data | Destination | Retention |
|------|------|-------------|-----------|
| 1. Record + Transcribe | Raw audio | Android `SpeechRecognizer` | Processed in real-time |
| 2. Save | Final entry | On-device (encrypted) | Permanent until deleted |

---

## The Problems

### 1. "On-device" is misleading — it's still Google

Android's `SpeechRecognizer` — including `createOnDeviceSpeechRecognizer()` on
API 31+ — is powered by **Google Speech Services**. This is a Google system app
that runs the speech recognition models.

Even with on-device models:
- Google controls the Speech Services app and its update cycle
- Google's privacy policy allows diagnostic/telemetry data collection
- The user has **no verifiable guarantee** that audio data isn't being collected
- On some OEM devices, the speech service may behave differently

**The promise "nothing is sent to the cloud" cannot be guaranteed** — it depends
on a third-party system service that the app doesn't control.

### 2. Unreliable offline support across API levels

| API Level | Behavior |
|-----------|----------|
| 31+ (Android 12+) | `createOnDeviceSpeechRecognizer()` — dedicated on-device engine. Best case scenario. |
| 26–30 (Android 8–11) | `createSpeechRecognizer()` + `EXTRA_PREFER_OFFLINE` — a **hint**, not a guarantee. The OS may still use the network. On some devices/ROMs, this flag is ignored entirely. |

The app's `minSdk = 26`, so **roughly half the supported range has no reliable
offline speech recognition**.

### 3. Requires pre-downloaded language models

On-device recognition requires the user to manually download the offline
speech recognition pack for their language:

> Settings → System → Languages → Speech → Offline speech recognition

Most users don't know this exists. If the model isn't downloaded, private mode
fails with a cryptic `NotAvailable` error.

### 4. Significantly worse transcription quality

| Aspect | MODE_BEST (Deepgram Nova-3) | MODE_PRIVATE (Android on-device) |
|--------|----------------------------|----------------------------------|
| Accuracy | State-of-the-art | Mediocre |
| Punctuation | Yes (smart_format) | Minimal/none on many devices |
| Language support | All 11 languages, excellent | Varies wildly by device |
| Continuous listening | Deepgram handles natively | Hacky restart-on-silence loop (up to 100 restarts) |
| AI cleanup | GPT-4o-mini polishes text | None — raw transcript is the final text |

Private mode entries are visibly lower quality — no punctuation, filler words
preserved, missed words. This undermines the app's core value proposition of
*capturing your words beautifully*.

### 5. No cleanup means worse entries

In MODE_BEST, the GPT-4o-mini cleanup step:
- Removes filler words ("um", "uh", "like")
- Fixes punctuation and capitalization
- Preserves the user's voice and meaning

In MODE_PRIVATE, the user gets raw, unpolished speech-to-text output. For a
*diary app*, this matters — entries that are unpleasant to re-read defeat the
purpose of journaling.

---

## What Private Mode IS Good For

1. **Airplane mode / no-connectivity scenarios** — the only way to record when
   there's no internet (with the `preferOffline` fix applied).
2. **Zero network traffic guarantee** (on API 31+ only) — for users who are
   paranoid about any data leaving the device.
3. **No API cost** — recordings in private mode don't consume Deepgram or
   OpenAI credits.

---

## The Real Privacy Story

The honest privacy story of wrait is already strong **in both modes**:

| Protection | MODE_BEST | MODE_PRIVATE |
|------------|-----------|--------------|
| Encrypted on-device storage (SQLCipher + Tink + Keystore) | ✅ | ✅ |
| No user accounts, no cloud storage of entries | ✅ | ✅ |
| Screenshot protection (`FLAG_SECURE`) | ✅ | ✅ |
| Backup disabled | ✅ | ✅ |
| No analytics, no telemetry | ✅ | ✅ |
| Audio never stored permanently | ✅ | ✅ |
| Raw audio touches a cloud API briefly | ⚠️ Yes (Deepgram) | ❓ Depends on device/API level |
| Transcript touches a cloud API briefly | ⚠️ Yes (OpenAI) | ✅ No |

The only genuine privacy difference is that in MODE_BEST, raw audio and
transcript text briefly transit through Deepgram and OpenAI APIs (both
stateless, no retention). In MODE_PRIVATE, the audio *might* stay on-device
(API 31+ only, Google Speech Services permitting).

---

## Recommendation

### Option A: Remove Private Mode (Simplify)

**Rationale**: The feature doesn't deliver a meaningful privacy improvement over
MODE_BEST, while significantly degrading transcription quality. The app's real
privacy story (encryption, no accounts, no cloud storage) is the same in both
modes. Removing it eliminates:
- `ModeAwareTranscriptionService` routing logic
- `AndroidTranscriptionService` + `SpeechRecognizerManager` complexity
- The `SpeechRecognizer` restart-on-silence hack (100 restart loop)
- Privacy mode toggle UI
- Build-time `PRIVACY_MODE` configuration
- Confusing user expectation vs. reality

**Risk**: Loses the offline recording capability.

### Option B: Rebrand as "Offline Mode" (Honest Naming)

**Rationale**: If the feature is kept, rebrand it from "Private mode" to
"Offline mode" with honest descriptions:
- Toggle label: **"Offline mode"**
- Description: *"Record without internet. Lower transcription quality."*

This sets correct expectations and avoids misleading privacy claims. The
feature remains useful for airplane/connectivity scenarios.

**Changes needed**:
- Rename UI strings
- Update `PrivacyMode` enum: `MODE_BEST` → keep, `MODE_PRIVATE` → `MODE_OFFLINE`
- Update documentation

### Option C: Keep As-Is (Acknowledge Limitations)

**Rationale**: Accept that "private mode" is a best-effort feature. Some users
genuinely want the *option* to keep audio off third-party APIs, even if the
guarantee isn't absolute. The feature is already built and working.

**Risk**: Users may feel misled when they discover the limitations. The quality
gap between modes is large enough to disappoint.

---

## Decision Factors

| Factor | Remove | Rebrand "Offline" | Keep "Private" |
|--------|--------|-------------------|----------------|
| Code complexity | ✅ Simplifies | ⚪ Same | ⚪ Same |
| User trust | ✅ No false promises | ✅ Honest | ⚠️ Misleading |
| Offline capability | ❌ Lost | ✅ Kept | ✅ Kept |
| Transcription quality | ✅ Always best | ⚠️ Worse when offline | ⚠️ Worse when private |
| Maintenance burden | ✅ Less code | ⚪ Same | ⚪ Same |
| API cost savings | ❌ Always costs | ✅ Free when offline | ✅ Free when private |

**My recommendation: Option B (Rebrand as "Offline Mode").**

It's the honest middle ground — keeps a useful capability (offline recording)
without making promises the app can't keep (true privacy from Google's speech
services). The code is already built; the main change is UI strings and naming.

---

*End of analysis.*

