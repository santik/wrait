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
| **Saved** | "new" | 1.0 (full) | Yes | — |
| **Error (TooShort/NoMatch)** | "wrait" | 1.0 (full) | Yes | Shake |
| **Error (NoInternet/Network/Timeout)** | "wrait" | 1.0 (full) | Yes | — |
| **Error (InsufficientPermissions)** | "wrait" | 0.5 (reduced) | Yes* | — |
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
| **Deleted** | Starts a **new** recording immediately (`startListening()`) |
| **Error (non-permission)** | Starts recording immediately (`startListening()`) — instant retry |
| **Error (permission)** | Resets to Idle (at controller level); at `MainActivity` level, opens app settings |

### Layer 3: Auto-Clear Timers (independent of button taps)

| State | Auto-clear mechanism | What happens after delay |
|-------|---------------------|-------------------------|
| **Saved** | `LaunchedEffect` in `MainScreen.kt` — 4 second delay, then calls `onStatusCleared()` | Calls `viewModel.resetToIdle()`, which sets state to Idle. **No recording starts. (Fixed)** |
| **Error** | `delayAndReset()` in controller — 1.5s delay via separate `resetJob` coroutine | Resets to Idle after 1.5 seconds. **(Fixed)** |
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

### Issue 2 (Medium): ~~`delayAndReset()` cancels itself — Error state never auto-clears at controller level~~ FIXED

**Severity**: Medium — subtle timing bug with no visible impact *today*, but fragile

**Status**: **FIXED** — `delayAndReset()` now launches a separate coroutine on `scope` instead of running inline inside `listenJob`.

**What was happening**: `delayAndReset()` was a `suspend fun` called inside the `listenJob` coroutine. It called `listenJob?.cancel()`, which cancelled its own parent coroutine. The subsequent `delay(1_500)` threw `CancellationException` and the state was never set to Idle. Error states stayed on screen forever unless the user tapped the button.

**Fix applied**: `app/src/main/java/com/wrait/app/MainRecordingController.kt`:
```kotlin
// Before (bug): suspend fun running inside listenJob, cancelling itself
private suspend fun delayAndReset() {
    listenJob?.cancel()
    delay(1_500)
    _recordingState.value = RecordingState.Idle
}

// After (fix): fire-and-forget coroutine on scope with state guard
private fun delayAndReset() {
    resetJob?.cancel()
    resetJob = scope.launch {
        delay(AUTO_CLEAR_DELAY_MS)
        val current = _recordingState.value
        if (!current.isActive) {
            _recordingState.value = RecordingState.Idle
        }
    }
}
```

Additional changes:
- Added `resetJob: Job?` field to track and cancel previous reset timers
- `startListening()` cancels `resetJob` so a new recording isn't interrupted by a pending reset
- `emitError()` changed from `suspend` to regular function (no longer calls a suspend function)
- Added `AUTO_CLEAR_DELAY_MS = 1_500L` constant

**Result**: Error states (`NoInternet`, `ApiFailed`, `TooShort`, `NoMatch`) and Saved states now correctly auto-clear to Idle after 1.5 seconds at the controller level.

---

### Issue 3 (Medium): ~~Error (InsufficientPermissions) — button looks disabled but is clickable~~ FIXED

**Severity**: Medium — confusing visual signal

**Status**: **FIXED** — `buttonAlphaFor()` now returns `AlphaReduced` (0.5) instead of `AlphaDisabled` (0.3) for `InsufficientPermissions`, matching the visual treatment of other tappable-but-degraded states.

**What was happening**: When the error is `InsufficientPermissions`, `buttonAlphaFor()` returned `0.3` (disabled look). But `isEnabled` in `ButtonArea.kt` only checks for `Processing` and `Uploading` — so the button was **still clickable**. The `MainActivity` handler intercepts this case and opens app settings, which is correct behavior. But the button appeared faded/disabled, so the user might not try tapping it.

**Fix applied**: `app/src/main/java/com/wrait/app/ui/main/ButtonArea.kt`:
```kotlin
// Before (bug):
RecognizerError.InsufficientPermissions -> DesignTokens.Button.AlphaDisabled

// After (fix):
RecognizerError.InsufficientPermissions -> DesignTokens.Button.AlphaReduced
```

**Result**: The button now shows at 0.5 alpha (reduced, not disabled) for permission errors, signaling that it is still tappable and will open settings.

---

### Issue 4 (Medium): ~~Button shows "wrait" during Saved state — no indication that tapping starts recording~~ FIXED

**Severity**: Medium — discoverability issue

**Status**: **FIXED** — `buttonLabelFor()` now returns `"new"` when the state is `Saved`, clearly indicating that tapping starts a new recording.

**What was happening**: After a successful recording, the button label changed back from "stop" to "wrait" and remained at full opacity. The status line showed "tap to read." If the user tapped the button (not the status line), a new recording started immediately. There was no visual indication that the button would start recording — it looked exactly like the Idle state.

**Fix applied**: `app/src/main/java/com/wrait/app/ui/main/ButtonArea.kt`:
```kotlin
// Before (bug):
private fun buttonLabelFor(recordingState: RecordingState): String =
    if (recordingState is RecordingState.Listening) "stop" else "wrait"

// After (fix):
private fun buttonLabelFor(recordingState: RecordingState): String = when (recordingState) {
    is RecordingState.Listening -> "stop"
    is RecordingState.Saved -> "new"
    else -> "wrait"
}
```

**Result**: The button now shows "new" during the Saved state, clearly differentiating it from both Idle ("wrait") and Listening ("stop"). The user can distinguish between "tap to start first recording" and "tap to start another recording."

---

### Issue 5 (Low): ~~Deleted state — button tap only resets to Idle, doesn't start recording~~ FIXED

**Severity**: Low — minor inconsistency

**Status**: **FIXED** — `onMainButtonTapped()` now calls `startListening()` for the `Deleted` state instead of only resetting to `Idle`, making behavior consistent with `Saved` and non-permission `Error` states.

**What was happening**: In `Deleted` state, the button label was "wrait", alpha was full, and the button was enabled. Tapping it set state to `Idle` — it did **not** start recording. The user had to tap twice: once to dismiss the "entry deleted" message, once to start recording. In contrast, `Saved` and non-permission `Error` states started recording immediately on tap.

**Fix applied**: `app/src/main/java/com/wrait/app/MainRecordingController.kt`:
```kotlin
// Before (bug):
is RecordingState.Deleted -> _recordingState.value = RecordingState.Idle

// After (fix):
is RecordingState.Deleted -> startListening()
```

**Result**: Tapping the button during the `Deleted` state now immediately starts a new recording, consistent with `Saved` and non-permission `Error` states. The user no longer needs to tap twice.

---

### Issue 6 (Low): ~~Network error states — button is enabled but faded, creating ambiguity~~ FIXED

**Severity**: Low — minor visual ambiguity

**Status**: **FIXED** — `buttonAlphaFor()` now returns `AlphaFull` (1.0) for `NoInternet`, `Network`, and `Timeout` errors, matching the fact that the button is fully functional and starts an immediate retry.

**What was happening**: For `NoInternet`, `Network`, and `Timeout` errors, the button alpha was `0.5` (reduced). But tapping it called `startListening()` — an immediate retry. The reduced alpha suggested the button was semi-disabled, yet it was fully functional.

**Fix applied**: `app/src/main/java/com/wrait/app/ui/main/ButtonArea.kt`:
```kotlin
// Before (bug):
RecognizerError.NoInternet,
RecognizerError.Network,
RecognizerError.Timeout -> DesignTokens.Button.AlphaReduced

// After (fix): Removed special case — falls through to the default `else -> AlphaFull` branch.
```

**Result**: Network error states now show the button at full opacity, correctly signaling that the button is fully functional and tapping it will retry the recording.

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
| 2 | ~~`delayAndReset()` cancels itself~~ | ~~Medium~~ **Fixed** | `delayAndReset()` now launches on `scope` with `resetJob` tracking | Error and Saved states auto-clear to Idle after 1.5s |
| 3 | ~~Permission error: looks disabled but clickable~~ | ~~Medium~~ **Fixed** | Alpha changed from 0.3 to 0.5 for `InsufficientPermissions` | Button now visually tappable |
| 4 | ~~No visual cue that button starts recording during Saved~~ | ~~Medium~~ **Fixed** | Button now shows "new" instead of "wrait" during Saved | Clear differentiation from Idle state |
| 5 | ~~Deleted requires two taps to start recording~~ | ~~Low~~ **Fixed** | `Deleted` now calls `startListening()` | Single tap starts recording |
| 6 | ~~Network errors: faded but functional~~ | ~~Low~~ **Fixed** | Network error alpha changed from 0.5 to 1.0 | Button correctly signals full functionality |
| 7 | No cancel during upload/processing | Low | Button disabled, controller no-ops | User stuck waiting |

