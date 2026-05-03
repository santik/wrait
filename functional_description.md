# wrait - Comprehensive Functional Description

## Application Overview

**wrait** is a minimal Android voice diary application designed for quick, private journaling through voice input. The app follows a simple "one button" philosophy: open, tap, speak, tap again. Your words are transcribed, cleaned up by AI, and stored encrypted on your device.

**Tagline**: *One button. Your voice. Your words. Stays on your phone.*

---

## Core Value Proposition

- **Simplicity**: Single-button interface for voice journaling
- **Privacy**: All entries stored encrypted on-device; no cloud storage of diary content
- **Speed**: Core recording-to-saved loop takes approximately 30 seconds
- **Flexibility**: Two privacy modes (cloud vs. on-device) to balance quality and privacy
- **Security**: Screenshots and recent apps thumbnails blocked; encrypted database

---

## User Flows and Use Cases

### 1. Primary Recording Flow

**Use Case**: User wants to quickly capture a journal entry by speaking.

**Steps**:
1. User opens the app
2. App displays main screen with large action button showing "tap to write"
3. User taps the action button
4. App requests RECORD_AUDIO permission if not already granted
   - If denied: Shows settings prompt to enable permission
   - If granted: Proceeds to recording
5. App enters "Listening" state - button shows "listening..." with visual feedback
6. User speaks their journal entry (minimum 5 seconds, maximum 2 minutes)
7. User taps the button again to stop recording
8. App enters "Uploading" state (if using cloud transcription) or "Processing" state
9. Transcription service processes the audio
10. If successful:
    - In **Best mode**: Raw transcript sent to OpenAI for cleanup (filler word removal, punctuation fixing)
    - In **Offline mode**: Raw transcript saved directly without cleanup
11. App enters "Saved" state, displaying "tap to read"
12. After 3 seconds, app returns to idle state showing "tap to write"

**Error Handling**:
- **Too short** (< 5s): Shows error, user can tap to retry immediately
- **No match**: Speech recognizer couldn't understand, shows error, user can retry
- **Network error** (Best mode only): Saves draft locally, shows error, retries automatically on next app launch
- **Permission error**: Opens app settings to enable microphone permission

---

### 2. Entry Viewing Flow

**Use Case**: User wants to read their past journal entries.

**Steps**:
1. From main screen, user swipes up
2. App navigates to Entry List screen
3. Entries displayed in reverse chronological order (newest first)
4. Each entry shows:
   - Date and time
   - First line of content (truncated)
   - Language tag (if different from default)
5. User taps an entry to view full details
6. Entry Detail screen shows:
   - Full cleaned text
   - Creation date/time
   - Word count
   - Language
   - Share button
   - Delete button
7. User can swipe down or tap back to return to list
8. User can swipe down on list to return to main screen

**Entry List Features**:
- Swipe right on entry to reveal delete button
- Empty state shows "no entries yet" message
- Statistics line shows total entries and active days

---

### 3. Entry Deletion Flow

**Use Case**: User wants to delete a journal entry.

**Steps**:
1. From Entry List, user swipes right on an entry
2. Delete button is revealed
3. User taps delete button
4. Confirmation dialog appears
5. User confirms deletion
6. Entry is deleted from database
7. If entry had associated audio file, it's deleted from disk
8. List refreshes to show updated entries
9. Main screen statistics update

**Alternative (from Detail view)**:
1. From Entry Detail screen, user taps delete button
2. Confirmation dialog appears
3. User confirms deletion
4. User is navigated back to Entry List
5. Entry is removed from list

---

### 4. Entry Editing Flow

**Use Case**: User wants to modify the text of a saved entry.

**Steps**:
1. From Entry Detail screen, user taps on the text area
2. Text becomes editable (BasicTextField)
3. User makes modifications
4. Changes are saved automatically as user types
5. User can tap back or swipe down to exit
6. On exit, changes are flushed to database

**Note**: This is a planned v2 feature; current implementation has editing disabled.

---

### 5. Entry Sharing Flow

**Use Case**: User wants to share a journal entry with another app.

**Steps**:
1. From Entry Detail screen, user taps share button
2. Android share sheet appears with cleaned entry text
3. User selects destination app (email, messaging, etc.)
4. Text is shared to selected app

---

### 6. Language Selection Flow

**Use Case**: User wants to change the transcription language.

**Steps**:
1. From main screen, user taps the language label (e.g., "English (US)")
2. Language picker sheet appears from bottom
3. User scrolls through supported languages
4. User selects desired language
5. Sheet dismisses
6. Language preference is saved
7. Next recording uses selected language

**Supported Languages**: Multiple languages supported (see SupportedLanguages.kt for full list)

---

### 7. Privacy Mode Toggle Flow

**Use Case**: User wants to switch between cloud and on-device transcription.

**Steps**:
1. From main screen, user swipes down
2. Settings panel slides down from top
3. User sees privacy mode toggle (Best/Private)
4. Current mode is highlighted
5. User taps to toggle mode
6. Mode preference is saved immediately
7. Settings panel dismisses
8. Next recording uses new mode

**Mode Differences**:
- **Best mode**: Backend proxy for speech-to-text (Deepgram behind `/api/transcribe`) + OpenAI gpt-4o-mini cleanup. Requires network. Higher quality transcription and cleanup.
- **Offline mode**: Android SpeechRecognizer (on-device). No network. No cleanup. Lower quality but completely offline.

---

### 8. Statistics Viewing Flow

**Use Case**: User wants to see their journaling statistics.

**Steps**:
1. From main screen, user looks at stats line above action button
2. Stats show: "X entries over Y days"
3. Entries = total number of journal entries
4. Active days = number of unique days with entries
5. Stats update in real-time as entries are added/deleted

---

### 9. Draft Retry Flow (Automatic)

**Use Case**: App automatically retries failed transcription/cleanup on app launch.

**Steps**:
1. App launches
2. MainViewModel initialization checks for pending drafts
3. If drafts exist (from previous network failures):
   - For audio drafts: Retries transcription with current transcription service
   - For text drafts: Retries OpenAI cleanup
   - If successful: Draft finalized and audio file deleted
   - If failed: Draft remains for manual retry
4. Process runs in background, doesn't block UI

---

### 10. Permission Handling Flow

**Use Case**: App needs microphone permission to record.

**Steps**:
1. User taps record button for first time
2. App checks RECORD_AUDIO permission
3. If not granted:
   - App requests permission via system dialog
   - If granted: Proceeds with recording
   - If denied:
     - App checks if permanently denied (user selected "Don't ask again")
     - If permanently denied: Shows blocked message with settings link
     - If temporarily denied: Shows error, user can retry
4. If permission is revoked while app is running:
   - App detects permission change
   - Stops any active recording
   - Shows error message
   - Navigates to settings to re-enable

---

## Recording State Machine

The app manages recording through a sealed class state machine:

**States**:
- **Idle**: Ready to record. Shows "tap to write"
- **Listening**: Actively recording audio. Shows "listening..."
- **Uploading**: Audio being uploaded to cloud service (Best mode only)
- **Processing**: Transcription/cleanup in progress
- **Saved**: Entry successfully saved. Shows "tap to read" with entry ID
- **Error**: Recording/transcription failed. Shows error message
- **Deleted**: Entry(s) deleted. Shows confirmation with count

**Transitions**:
- Idle → Listening: User taps button
- Listening → Processing: User taps button (after minimum 5s)
- Listening → Idle: User taps button (before 5s) - too short error
- Processing → Saved: Transcription/cleanup successful
- Processing → Error: Transcription/cleanup failed
- Error → Idle: User taps button (retry)
- Error → Listening: User taps button (immediate retry for non-permission errors)
- Saved → Idle: User taps button or auto-clear after 3s
- Deleted → Idle: Auto-clear after 3s

---

## Privacy and Security Model

### Data That Stays On Device

- All diary entries (raw transcript and cleaned text)
- Encryption keys (protected by Android Keystore)
- Language preferences
- Privacy mode preference

### Data That Leaves Device (Best Mode Only)

1. **Voice audio**: Sent to the backend proxy `/api/transcribe`, which forwards it to Deepgram Nova-3 for transcription
   - Stateless API call
   - Audio discarded immediately after transcription
   - Never written to disk on device

2. **Raw transcript**: Sent to OpenAI gpt-4o-mini for cleanup
   - Stateless API call
   - No session, no history
   - Cleaned text never sent

### Data That Never Leaves Device

- Cleaned diary entry text
- Device identifiers
- Location data
- Account information (no accounts exist)

### Local Storage Security

- **Database**: SQLite encrypted with SQLCipher
- **Password**: Randomly generated, encrypted with Tink AEAD
- **Key Storage**: Tink keyset protected by Android Keystore
- **Backup**: Explicitly disabled (android:allowBackup="false")
- **Screenshots**: Blocked via FLAG_SECURE
- **Recent Apps**: Thumbnail blocked via FLAG_SECURE

---

## Technical Architecture

### Technology Stack

- **Language**: Kotlin
- **UI Framework**: Jetpack Compose
- **Dependency Injection**: Hilt
- **Database**: Room with SQLCipher encryption
- **Async**: Coroutines with StateFlow
- **Architecture**: MVVM with Repository pattern

### Key Components

**UI Layer**:
- `MainActivity`: Single activity with Compose navigation
- `MainScreen`: Primary recording interface
- `EntryListScreen`: List of all entries
- `EntryDetailScreen`: Single entry view/edit
- `LanguagePickerSheet`: Language selection modal
- `SettingsPanel`: Privacy mode toggle

**ViewModels**:
- `MainViewModel`: Main screen state and recording orchestration
- `EntryListViewModel`: Entry list management
- `EntryDetailViewModel`: Single entry editing

**Controllers**:
- `MainRecordingController`: Recording pipeline orchestration
- `SpeechRecognizerManager`: Android speech recognition
- `ModeAwareTranscriptionService`: Privacy-mode-aware transcription routing

**Repositories**:
- `EntryRepository`: Entry data operations
- `PreferencesRepository`: User preferences (DataStore)

**Data Layer**:
- `EntryDao`: Room database access
- `WraitDatabase`: Encrypted SQLite database
- `OpenAiApiService`: Text cleanup API client
- `WraitBackendClient`: Backend proxy client for registration, speech-to-text, and optional cleanup
- `TranscriptionService`: Abstraction for transcription backends

### Transcription Backends

**Best Mode**:
- `CloudTranscriptionService`: Cloud STT via backend proxy (`/api/transcribe`, Deepgram behind the proxy)
- `WhisperTranscriptionService`: Alternative cloud STT via OpenAI Whisper
- `OpenAiApiService`: Text cleanup via gpt-4o-mini

**Private Mode**:
- `AndroidTranscriptionService`: On-device STT via Android SpeechRecognizer
- No cleanup step

### Data Model

**Entry**:
- `id`: Unique identifier
- `rawTranscript`: Original transcribed text
- `cleanedText`: AI-cleaned version (null if not cleaned)
- `isDraft`: Whether entry is a draft (pending cleanup)
- `language`: Language code (e.g., "en-US")
- `createdAt`: Unix timestamp
- `wordCount`: Number of words in cleaned text
- `audioPath`: Path to audio file (null if transcribed)

**EntryStats**:
- `entryCount`: Total number of entries
- `activeDays`: Number of unique days with entries

**PrivacyMode**:
- `MODE_BEST`: Cloud transcription + cleanup
- `MODE_OFFLINE`: On-device transcription only

---

## Error Handling

### Recording Errors

**TooShort**: Recording less than 5 seconds
- Action: Show error, allow immediate retry
- UI: Shake animation on button

**NoMatch**: Speech recognizer couldn't understand audio
- Action: Show error, allow immediate retry
- UI: Shake animation on button

**InsufficientPermissions**: Microphone permission denied
- Action: Open app settings to enable permission
- UI: Settings link in status line

**NoInternet**: Network unavailable (Best mode only)
- Action: Save as draft, retry on next app launch
- UI: Error message, draft kept

**BackendUnavailable**: Backend proxy timed out or returned a 5xx response
- Action: Save as draft, retry on next app launch
- UI: Error message, draft kept

**ProxyAuthFailed**: Backend proxy rejected the request due to proxy auth/config
- Action: Save as draft, retry after backend configuration is fixed
- UI: Error message, draft kept

**ApiFailed**: API call failed (Best mode only)
- Action: Save as draft, retry on next app launch
- UI: Error message, draft kept

### Data Errors

**Database corruption**: SQLCipher key invalid
- Action: Clear encrypted state, recreate database
- User impact: All entries lost (by design)

**Keystore invalid**: Device reset or security change
- Action: Clear encrypted state, recreate database
- User impact: All entries lost (by design)

---

## Known Limitations (v1)

- **No edit**: Entry text is read-only after saving (planned for v2)
- **No export**: Cannot export entries as files (planned for v2)
- **No backup**: Factory reset means data loss (documented in beta guide)
- **No biometric lock**: No app-level lock (planned for v2)
- **No search**: Cannot search entries (planned for later)
- **2-minute cap**: Recording limited to 2 minutes by design
- **Android only**: No iOS version planned
- **Secrets in binary/config**: The OpenAI key plus backend configuration values are compiled into the APK (acceptable for closed beta)

---

## Configuration

### Build-Time Configuration (local.properties)

- `OPENAI_API_KEY`: OpenAI API key for cleanup
- `BACKEND_URL`: Base URL for backend proxy endpoints
- `PROXY_SECRET`: Shared secret required for backend proxy calls in cloud mode
- `PRIVACY_MODE`: Default privacy mode (MODE_BEST or MODE_OFFLINE)

### Runtime Configuration

- Language selection (user preference)
- Privacy mode (user preference, switchable at runtime)
- Draft retry (automatic on app launch)

---

## Performance Characteristics

- **Recording latency**: Near real-time streaming
- **Transcription time**: ~5-10 seconds for typical entry
- **Cleanup time**: ~3-5 seconds for typical entry
- **Total loop time**: ~30 seconds end-to-end
- **Database operations**: All on IO dispatcher, non-blocking UI
- **Draft retry**: Background operation, doesn't block app launch

---

## Accessibility

- **Screen reader support**: All UI elements properly labeled
- **Touch targets**: Minimum 48dp for all interactive elements
- **Gesture alternatives**: All swipe gestures have button alternatives
- **Error announcements**: Screen reader announces error states
- **Status updates**: Recording state announced to screen readers

---

## Localization

- Supported languages: Multiple (see SupportedLanguages.kt)
- Language detection: Automatic in Best mode (backend proxy returns Deepgram-style detection data)
- Language mismatch handling: Entry re-tagged with detected language
- Date/time formatting: Locale-aware

---

## Testing

- **Instrumented tests**: Functional integration tests on real device/emulator
- **Test coverage**: MainViewModel, EntryRepository, database migrations
- **Fake implementations**: FakeTranscriptionService, FakeOpenAiApiService for testing
- **No unit tests**: All tests are instrumented integration tests

---

## Deployment

- **Build system**: Gradle with Kotlin DSL
- **Target SDK**: 34
- **Min SDK**: 26
- **Release process**: deploy.sh script builds, tests, and installs release APK
- **Device targeting**: Specific device ID in deploy script (4A181FDJH0030G)

---

## User Onboarding

**First Launch**:
1. App requests microphone permission
2. User grants permission
3. App shows "tap to write" on main screen
4. User can tap language label to select preferred language
5. User can swipe down to access privacy mode settings
6. Default privacy mode: MODE_BEST (configurable at build time)

**First Recording**:
1. User taps action button
2. App enters listening state
3. User speaks for at least 5 seconds
4. User taps button to stop
5. App processes transcription
6. App shows "tap to read" when saved
7. "hasEverRecorded" flag set to true

---

## Data Lifecycle

**Entry Creation**:
1. Audio recorded to temporary file
2. Transcription service processes audio
3. Raw transcript saved as draft to database
4. Audio file deleted (if transcription successful)
5. Cleanup API called (Best mode only)
6. Entry updated with cleaned text
7. Draft flag cleared

**Entry Deletion**:
1. Entry marked for deletion
2. Removed from database
3. Associated audio file deleted (if exists)
4. Statistics recalculated

**Draft Cleanup**:
1. App checks for stale drafts (> 7 days old)
2. Old drafts deleted automatically
3. Audio files for stale drafts deleted

---

## Offline Behavior

**Best Mode (Online Required)**:
- Recording: Requires network for transcription
- Draft saving: Works offline (audio saved locally)
- Cleanup: Requires network (draft kept if offline)
- Retry: Automatic on next app launch when online

**Private Mode (Offline Capable)**:
- Recording: Works offline (on-device transcription)
- Draft saving: Works offline
- Cleanup: N/A (no cleanup in Offline mode)
- Retry: N/A (no network dependency)


*Document generated on April 12, 2026*
