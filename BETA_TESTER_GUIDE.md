# wrait — beta tester guide

Thanks for testing wrait. This guide tells you everything you need to know to get started and what to look out for.

---

## What wrait is

A voice diary for your phone. You open it, tap a button, talk, and tap again. Your entry is saved. That's it.

There's no account. In Best mode, your audio and raw transcript go through the wrait backend proxy for transcription and cleanup. In Offline mode, your entries stay encrypted on your phone.

---

## Installing the app

If you received an APK file directly (outside of the Play Store), follow the steps below to install it.

### Installing an APK from outside the Play Store

Android blocks apps from unknown sources by default. You need to allow your file manager or browser to install APKs once.

1. **Copy the APK to your phone** — download it directly in the browser, or transfer it via cable/cloud.
2. **Open the APK file** — tap it in your Downloads folder or file manager. Android will show a warning that the install is blocked.
3. **Grant install permission** — tap **Settings** in the warning dialog. You'll land on an "Install unknown apps" screen for that specific app (e.g. Chrome or Files). Toggle **Allow from this source** on.
4. **Go back and tap Install** — Android will ask you to confirm once more, then install.
5. Once installed, you can turn the permission back off: Settings → Apps → (the app you used to install) → Install unknown apps → toggle off.

> This only needs to be done once. Future APK updates follow the same steps.

**Requirements:** Android 8.0 or newer. If you're unsure, go to Settings → About Phone → Android version.

---

## Using the app

### Recording an entry

1. Open wrait
2. Tap the button in the middle of the screen
3. Talk — up to 2 minutes
4. Tap the button again to stop

The app will clean up your recording automatically (removes filler words, fixes punctuation). This takes a second or two. When it's done, you'll see **"tap to read"** — tap it to open the new entry directly.

If Best mode is selected and your phone has no connection, the app now blocks before recording starts instead of letting you record something it cannot upload.

### Reading your entries

Swipe up from anywhere on the main screen, or tap the stats line ("12 entries · 8 days") at the bottom. Your entries appear newest first. Tap any entry to read the full text. The entry text is selectable — you can copy it to the clipboard if you want to use it elsewhere.

### Editing entries

Finalized entries can be edited in-place on the detail screen. Just tap and type — changes save automatically about 500 ms after you stop typing. Draft entries cannot be edited.

### Sharing entries

Share a finalized entry from the detail screen using the share icon in the top-right corner. This opens the Android share sheet with the entry's date and text.

### Deleting entries

Swipe right on any entry in the entries list to reveal a delete button. Tap it and confirm to delete that entry. You can also delete from the entry detail screen using the delete button in the top-right corner.

### Changing the language

Open the settings panel from the settings icon in the top-right corner or by swiping down from the top of the main screen. Tap **Offline transcription language**. Pick the language you'll be speaking in when you use Offline mode.

In Best mode, cloud transcription detects language automatically. If you speak in a different language than the offline language selected in settings, the app will detect it and show "tap to read · detected <lang>" after saving. The entry will be tagged with the detected language.

### Offline mode

Tap the settings icon in the top-right corner, or swipe down from the top of the main screen, to open the settings panel. You'll see an **Offline mode** toggle:

- **Off (Best mode)** — Audio is sent to the wrait backend proxy for transcription. The raw transcript is sent to the wrait backend proxy for cleanup. Best accuracy, requires internet.
- **On (Offline mode)** — Everything stays on your phone. Android's on-device speech recognition is used. No internet needed. No cleanup step. Lower transcription quality.

The change takes effect on the next recording — no restart needed. The panel closes when you swipe up or tap outside it.

> **Note:** Offline mode requires an offline speech model for the selected language to be installed on your device. If it's not installed, you'll see "offline model not installed" when you try to record. You can download offline speech models in your device settings: Settings → System → Languages → Speech → Offline speech recognition.

---

## What happens to your data

**In Best mode (default):** Your audio is sent to the wrait backend proxy for transcription, and the raw transcript is sent to the wrait backend proxy for cleanup. The cleaned entry text still stays on your device.

**In Offline mode:** No recording audio or transcript leaves your phone. Transcription runs on-device. There is no cleanup step.

In both modes, your entries are saved encrypted on your phone only. Audio is discarded immediately after transcription and is never stored on your device, unless a recoverable Best-mode failure requires a local draft retry. On app launch, an anonymous device ID may also be sent to the wrait backend to register the device for the beta service.

For full details, see the [privacy policy](https://santik.github.io/wrait/PRIVACY).

---

## A few things to know before you start

**Entries can be edited, deleted, and shared.** Edit finalized entries directly on the detail screen — changes save automatically. Delete by swiping right on any entry card or using the delete button on the detail screen. Share entries using the share icon on the detail screen.

**There's no backup.** If you uninstall the app or factory reset your phone, your entries are gone. This is intentional (privacy by design), but worth knowing upfront.

**Short recordings are discarded.** If you tap stop before saying at least a few words, nothing is saved. This is expected.

**If you lose your internet connection** before starting a recording in Best mode, the app blocks immediately. If the connection drops while recording or during upload/cleanup, your entry is saved as a draft on your phone and cleaned up automatically the next time you open the app with a connection.

---

## What to try

Here are some things worth testing — especially in the first week:

- Record a few entries in different styles: calm and slow, fast and stream-of-consciousness, emotional
- Try recording in your language and check whether the cleaned text reads naturally — does it still sound like you?
- Try pausing mid-sentence for a few seconds — the app should wait for you
- After saving, tap "tap to read" to open the entry directly
- Tap the stats line ("12 entries · 8 days") to navigate to the entry list
- Swipe up to browse your entries — does the list update immediately after recording?
- Open the settings panel from the new settings icon in the top-right corner
- Change the Offline transcription language in settings and record in a different one
- Try recording in a different language than the offline language selected in settings — check if the app detects it and shows the detected language
- Try recording with a poor connection and check if the draft recovers on the next open
- Try starting a Best-mode recording with no connection — the app should block before recording starts
- Swipe right on an entry to delete it — confirm the dialog and check it's gone
- Open an entry and try editing the text — check that it saves automatically
- Open an entry and try sharing it — check that the share sheet opens with the correct text
- Swipe down from the top to open the settings panel — toggle Offline mode on and record an entry; check whether the cleanup step is skipped
- Toggle back to Best mode and record again — check that cleanup runs
- Try Offline mode with airplane mode on — recording should work if the language model is downloaded
- Try Offline mode with a language whose speech model is not downloaded — the app should show "offline model not installed"
- Tap the main button while "tap to read" is showing — check that it immediately starts a new recording

---

## Known rough edges in this version

This is an early beta. A few things are not finished yet:

- No export of your entries
- No PIN or biometric lock
- The design is not final — some screens are placeholder layouts
- Animations may feel unpolished
- In Offline mode, transcription accuracy depends on your device's built-in speech recognition and whether the offline model for your language is installed

These are all on the list for the next version.

---

## Giving feedback

Please share anything — what felt off, what surprised you, what you wish worked differently. No observation is too small.

Please report bugs or specific issues directly to the developer at fedorets.alex@gmail.com.

What's most useful to hear about:
- Did the cleanup output sound natural in your language?
- Did the app feel slow or unresponsive at any point?
- Did anything confuse you, especially around the recording flow?
- Did the new settings entry point feel clearer?
- Did you lose an entry or see unexpected behaviour?

---

*wrait — speak your mind. keep it private.*
