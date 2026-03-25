Microphone permission handling

Use Compose Accompanist permissions library — rememberPermissionState(RECORD_AUDIO)
On button tap: check status — Granted → start recording, Denied → request, PermanentlyDenied → set error state
If recording started, stop recording on button tap
Show status while recording
PermanentlyDenied: tapping button opens system app settings via Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
Never request permission on app launch — Android best practice is to request at point of use
Important: On Android 13+ the permission dialog can only be shown twice. After two denials it's permanently denied. Your error state must handle this gracefully — "mic access blocked, tap to open settings" not a generic error.