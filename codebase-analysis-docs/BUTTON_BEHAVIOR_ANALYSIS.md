# Button Behavior by State — Explanation & UX Issue Analysis

> **Generated**: April 14, 2026
> **Scope**: `MainRecordingController.onMainButtonTapped()`, `ButtonArea.kt`, `MainScreen.kt` auto-clear timers

---

## How the Button Works Today

The main button is a single circular element. What it does depends on the current `RecordingState`. There are three layers that combine to determine the full button behavior:

### Layer 1: Visual Appearance (`ButtonArea.kt`)

| State | Label | Alpha (opacity) | Enabled (clickable)? | Animation |
|-------|-------|-----------------|---------------------|-----------|
| **Idle** | "wrait" | 1.0 (full) | Yes | — |
| **Listening** | "stop" | 1.0 (full) | Yes | Pulse ring |
| **Uploading** | "wrait" | 0.3 (disabled) | No | — |
| **Processing** | "wrait" | 0.3 (disabled) | No | — |
| **Saved** | "wrait" | 1.0 (full) | Yes | — |
| **Error (TooShort/NoMatch)** | "wrait" | 1.0 (full) | Yes | Shake |
| **Error (NoInternet/Network/Timeout)** | "wrait" | 0.5 (reduced) | Yes | — |
| **Error (InsufficientPermissions)** | "wrait" | 0.3 (disabled) | Yes* | — |
| **Error (ApiFailed, etc.)** | "wrait" | 1.0 (full) | Yes | — |
| **Deleted** | "wrait" | 1.0 (full) | Yes | — |
| **Mic blocked (special)** | "wrait" | 0.3 (disabled) | Yes* | — |

*\* Enabled at the compose level, but the `MainActivity` handler intercepts and opens settings instead of recording.*

### Layer 2: Tap Action (`MainRecordingController.onMainButtonTapped()`)

| Current State | What the tap does |
|--------------|-------------------|
| **Idle** | Starts recording (`startListening()`) |
| **Listening** | Stops recording — if >= 5s: proceeds to Processing; if < 5s: emits `TooShort` error |
| **Uploading** | **Nothing** (no-op) |
| **Processing** | **Nothing** (no-op) |
| **Saved** | Starts a **new** recording immediately (`startListening()`) |
| **Deleted** | Resets to Idle (no recording starts) |
| **Error (non-permission)** | Starts recording immediately (`startListening()`) — instant retry |
| **Error (permission)** | Resets to Idle (at controller level); at `MainActivity` level, opens app settings |

### Layer 3: Auto-Clear Timers (independent of button taps)

| State | Auto-clear mechanism | What happens after delay |
|-------|---------------------|-------------------------|
| **Saved** | `LaunchedEffect` in `MainScreen.kt` — 4 second delay, then calls `onStatusCleared()` | Calls `viewModel.resetToIdle()`, which sets state to Idle. **No recording starts. (Fixed)** |
| **Error** | `delayAndReset()` in controller — 1.5s delay, but self-cancels via `listenJob?.cancel()` so the `delay()` never completes | **No-op at controller level.** Error stays visible until button tap. |
| **Deleted** | `onEntriesDeleted()` — 3 second delay, then resets to Idle | Resets to Idle. No recording starts. |

---

## Identified UX and User-Flow Issues

### Issue 1 (High): ~~Saved state auto-starts a new recording without user intent~~ FIXED

**Severity**: High — user-hostile behavior

**Status**: **FIXED** — `onStatusCleared` now calls `viewModel.resetToIdle()` instead of `viewModel.onMainButtonTapped()`.

**What was happening**: After a successful recording, the state entered `Saved` and showed "tap to read" for 4 seconds. When the timer expired, `onStatusCleared()` called `viewModel.onMainButtonTapped()`, which dispatched to `is RecordingState.Saved -> startListening()`. A new recording started automatically even though the user didn't tap anything.

**Fix applied**: `app/src/main/java/com/wrait/app/MainActivity.kt` line 172:
```kotlin
// Before (bug):
onStatusCleared = { viewModel.onMainButtonTapped() },

// After (fix):
onStatusCleared = { viewModel.resetToIdle() },
```

**Result**: After the 4-second "tap to read" timer expires, the app returns to Idle. The user must explicitly tap the button to start a new recording.

---

### Issue 2 (Medium): `delayAndReset()` cancels itself — Error state never auto-clears at controller level

**Severity**: Medium — subtle timing bug with no visible impact *today*, but fragile

**What happens**: `delayAndReset()` is called inside `saveTranscript()` and `emitError()`, both of which run inside the `listenJob` coroutine. `delayAndReset()` first calls `listenJob?.cancel()`, which cancels its own parent coroutine. The subsequent `delay(1_500)` throws `CancellationException` and `_recordingState.value = RecordingState.Idle` on line 239 is **never reached**.

**Where it happens**: `app/src/main/java/com/wrait/app/MainRecordingController.kt` lines 236-240

**Why this matters**:
- For the `Saved` state: the UI-layer `LaunchedEffect` handles the clear (4s), so it "works" — but not for the reason the code suggests
- For `Error` states: there is **no auto-clear at all**. If the `LaunchedEffect` only fires for `Saved`, errors just stay on screen forever unless the user taps the button. This is currently masked because the button is enabled during most error states.
- If someone removes the `LaunchedEffect` or changes the UI layer, error states and saved states become permanent

**Suggested fix**: Move `delayAndReset()` to a separate coroutine scope (not inside `listenJob`):
```kotlin
private fun delayAndReset() {
    scope.launch {
        delay(1_500)
        if (_recordingState.value !is RecordingState.Listening) {
            _recordingState.value = RecordingState.Idle
        }
    }
}
```

---

### Issue 3 (Medium): Error (InsufficientPermissions) — button looks disabled but is clickable

**Severity**: Medium — confusing visual signal

**What happens**: When the error is `InsufficientPermissions`, `buttonAlphaFor()` returns `0.3` (disabled look). But `isEnabled` in `ButtonArea.kt` only checks for `Processing` and `Uploading` — so the button is **still clickable**. The `MainActivity` handler intercepts this case and opens app settings, which is correct behavior. But the button appears faded/disabled, so the user might not try tapping it.

**Where it happens**:
- `app/src/main/java/com/wrait/app/ui/main/ButtonArea.kt` line 87: `isEnabled` doesn't check for permission error
- `app/src/main/java/com/wrait/app/ui/main/ButtonArea.kt` lines 142-143: alpha is `0.3`
- `app/src/main/java/com/wrait/app/MainActivity.kt` lines 180-188: intercepts and opens settings

**Why this is a problem**: The button visually communicates "I can't be used" (same alpha as Processing), but the intended behavior is "tap me to go to settings." The user relies on the status line text ("mic blocked - tap to open settings") but the button itself is misleading.

**Suggested fix**: Either make the button alpha `0.5` (reduced, not disabled) for the permission error, or make the status line the only tap target and truly disable the button.

---

### Issue 4 (Medium): Button shows "wrait" during Saved state — no indication that tapping starts recording

**Severity**: Medium — discoverability issue

**What happens**: After a successful recording, the button label changes back from "stop" to "wrait" and remains at full opacity. The status line shows "tap to read." If the user taps the button (not the status line), a new recording starts immediately. There is no visual indication that the button will start recording — it looks exactly like the Idle state.

**Where it happens**:
- `app/src/main/java/com/wrait/app/ui/main/ButtonArea.kt` line 134-135: `buttonLabelFor()` returns "wrait" for all non-Listening states
- `app/src/main/java/com/wrait/app/MainRecordingController.kt` line 54: `is RecordingState.Saved -> startListening()`

**Why this is a problem**: A user who just finished recording and wants to read their entry might accidentally tap the button (larger touch target) instead of the status line text (smaller). This starts an unwanted recording.

---

### Issue 5 (Low): Deleted state — button tap only resets to Idle, doesn't start recording

**Severity**: Low — minor inconsistency

**What happens**: In `Deleted` state, the button label is "wrait", alpha is full, and the button is enabled. Tapping it sets state to `Idle` — it does **not** start recording. The user must tap twice: once to dismiss the "entry deleted" message, once to start recording.

**Where it happens**: `app/src/main/java/com/wrait/app/MainRecordingController.kt` line 55: `is RecordingState.Deleted -> _recordingState.value = RecordingState.Idle`

**Why this is (mildly) inconsistent**: In `Saved` and non-permission `Error` states, tapping the button immediately starts recording (single tap). In `Deleted`, it requires two taps. This is a deliberate design choice (not all states should restart recording), but the user has no way to predict which states are "tap once" vs "tap twice."

---

### Issue 6 (Low): Network error states — button is enabled but faded, creating ambiguity

**Severity**: Low — minor visual ambiguity

**What happens**: For `NoInternet`, `Network`, and `Timeout` errors, the button alpha is `0.5` (reduced). But tapping it calls `startListening()` — an immediate retry. The reduced alpha suggests the button is semi-disabled, yet it's fully functional and will start recording.

**Where it happens**:
- `app/src/main/java/com/wrait/app/ui/main/ButtonArea.kt` lines 144-146: alpha = `AlphaReduced` (0.5)
- `app/src/main/java/com/wrait/app/MainRecordingController.kt` lines 60-61: `startListening()` for non-permission errors

**Why this is a problem**: The visual signal (faded = less interactive) contradicts the actual behavior (fully functional retry). A user might not try tapping because the button looks partially disabled. The status line says "no connection - saved as draft" which doesn't invite tapping either.

---

### Issue 7 (Low): No way to cancel an in-progress upload or processing

**Severity**: Low — design limitation

**What happens**: During `Uploading` and `Processing` states, the button is disabled (`isEnabled = false`) and the controller returns `Unit` (no-op). The user must wait for the operation to complete or fail.

**Where it happens**:
- `app/src/main/java/com/wrait/app/ui/main/ButtonArea.kt` line 87: `isEnabled = false` for Processing and Uploading
- `app/src/main/java/com/wrait/app/MainRecordingController.kt` lines 51-52: `Unit` (no-op)

**Why this is a problem**: If the Deepgram upload is slow (timeout is 5 minutes), or OpenAI cleanup hangs (timeout is 30 seconds), the user is stuck with a dimmed button and no way to abort. The only escape is killing the app.

---

## Summary Table

| # | Issue | Severity | Root Cause | User Impact |
|---|-------|----------|-----------|-------------|
| 1 | ~~Saved auto-starts recording after 4s~~ | ~~High~~ **Fixed** | `onStatusCleared` now calls `resetToIdle()` | Returns to Idle correctly |
| 2 | `delayAndReset()` cancels itself | Medium | `listenJob?.cancel()` inside its own coroutine | Error states never auto-clear at controller level |
| 3 | Permission error: looks disabled but clickable | Medium | Alpha 0.3 but `isEnabled = true` | User might not discover the settings shortcut |
| 4 | No visual cue that button starts recording during Saved | Medium | Button shows "wrait" at full alpha during Saved | Accidental recording instead of reading entry |
| 5 | Deleted requires two taps to start recording | Low | `Deleted -> Idle` (not `startListening`) | Minor inconsistency |
| 6 | Network errors: faded but functional | Low | Alpha 0.5 but `startListening()` on tap | Confusing visual signal |
| 7 | No cancel during upload/processing | Low | Button disabled, controller no-ops | User stuck waiting |

