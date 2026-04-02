# wrait — beta tester guide

Thanks for testing wrait. This guide tells you everything you need to know to get started and what to look out for.

---

## What wrait is

A voice diary for your phone. You open it, tap a button, talk, and tap again. Your entry is saved. That's it.

There's no account. Nothing goes to the cloud. Your entries stay encrypted on your phone.

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

The app will clean up your recording automatically (removes filler words, fixes punctuation). This takes a second or two. When it's done, you'll see **"entry saved"** on screen.

### Reading your entries

Swipe up from anywhere on the main screen. Your entries appear newest first. Tap any entry to read the full text. The entry text is selectable — you can copy it to the clipboard if you want to use it elsewhere.

### Deleting entries

In the entries list, long-press any entry to enter selection mode. Tap to select more entries. Tap the delete button at the bottom, then confirm. The main screen will briefly confirm how many entries were deleted.

### Changing the language

Tap the language name above the button (e.g. "Nederlands" or "English"). Pick the language you'll be speaking in. This tells the app which language to transcribe and clean up — it's important to set this correctly before recording.

---

## What happens to your data

When you record an entry, the text is sent to OpenAI to clean it up (removing filler words and
fixing punctuation). If you're using a build with the Whisper backend, your audio is also sent
to OpenAI for transcription. Nothing is ever sent to us — we have no servers.

Your entries are saved encrypted on your phone only. Audio is discarded immediately after
transcription and is never stored on your device.

For full details, see the [privacy policy](https://santik.github.io/wrait/PRIVACY).

---

## A few things to know before you start

**Entries can be deleted, but not edited.** To delete one or more entries, go to the entries list, long-press any entry to enter selection mode, select what you want to remove, then tap the delete button. A confirmation dialog appears before anything is deleted. Entry text itself is read-only for now.

**There's no backup.** If you uninstall the app or factory reset your phone, your entries are gone. This is intentional (privacy by design), but worth knowing upfront.

**Short recordings are discarded.** If you tap stop before saying at least a few words, nothing is saved. This is expected.

**If you lose your internet connection** while recording, your entry is saved as a draft on your phone and cleaned up automatically the next time you open the app with a connection.

---

## What to try

Here are some things worth testing — especially in the first week:

- Record a few entries in different styles: calm and slow, fast and stream-of-consciousness, emotional
- Try recording in your language and check whether the cleaned text reads naturally — does it still sound like you?
- Try pausing mid-sentence for a few seconds — the app should wait for you
- Swipe up to browse your entries — does the list update immediately after recording?
- Switch languages and record in a different one
- Try recording with a poor connection and check if the draft recovers on the next open
- Long-press an entry to enter selection mode — try selecting multiple entries and deleting them
- Open an entry and try copying the text

---

## Known rough edges in this version

This is an early beta. A few things are not finished yet:

- No edit — entry text is read-only after saving
- No export of your entries
- No PIN or biometric lock
- The design is not final — some screens are placeholder layouts
- Animations may feel unpolished

These are all on the list for the next version.

---

## Giving feedback

Please share anything — what felt off, what surprised you, what you wish worked differently. No observation is too small.

Please report bugs or specific issues directly to the developer at fedorets.alex@gmail.com.

What's most useful to hear about:
- Did the cleanup output sound natural in your language?
- Did the app feel slow or unresponsive at any point?
- Did anything confuse you, especially around the recording flow?
- Did you lose an entry or see unexpected behaviour?

---

*wrait — speak your mind. keep it private.*
