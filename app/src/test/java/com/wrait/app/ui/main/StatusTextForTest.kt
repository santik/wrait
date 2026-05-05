package com.wrait.app.ui.main

import com.wrait.app.RecordingState
import com.wrait.app.data.speech.RecognizerError
import org.junit.Assert.assertEquals
import org.junit.Test

class StatusTextForTest {
    @Test
    fun idle_showsTapToWrite_untilFirstRecording() {
        val text = statusTextFor(
            recordingState = RecordingState.Idle,
            showBlockedMessage = false,
            hasEverRecorded = false,
        )
        assertEquals("tap button to write", text)
    }

    @Test
    fun idle_hidesTapToWrite_afterFirstRecording() {
        val text = statusTextFor(
            recordingState = RecordingState.Idle,
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("", text)
    }

    @Test
    fun idle_blockedMessage_overridesTapToWrite() {
        val text = statusTextFor(
            recordingState = RecordingState.Idle,
            showBlockedMessage = true,
            hasEverRecorded = false,
        )
        assertEquals("mic blocked · tap to open settings", text)
    }

    @Test
    fun listening_showsEllipsis() {
        val text = statusTextFor(
            recordingState = RecordingState.Listening,
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("listening…", text)
    }

    @Test
    fun uploading_showsEllipsis() {
        val text = statusTextFor(
            recordingState = RecordingState.Uploading,
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("uploading…", text)
    }

    @Test
    fun processing_showsCleaningUp() {
        val text = statusTextFor(
            recordingState = RecordingState.Processing,
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("cleaning up…", text)
    }

    @Test
    fun saved_showsTapToRead() {
        val text = statusTextFor(
            recordingState = RecordingState.Saved(entryId = 1L, detectedLanguage = "fr"),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("tap to read", text)
    }

    @Test
    fun deleted_singleEntry_showsSingular() {
        val text = statusTextFor(
            recordingState = RecordingState.Deleted(count = 1),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("entry deleted", text)
    }

    @Test
    fun deleted_multipleEntries_showsCount() {
        val text = statusTextFor(
            recordingState = RecordingState.Deleted(count = 3),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("3 entries deleted", text)
    }

    @Test
    fun error_noInternet_showsSavedAsDraft() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.NoInternet),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("no connection · saved as draft", text)
    }

    @Test
    fun error_apiFailed_showsWillRetry() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.ApiFailed),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("saved as draft · will retry", text)
    }

    @Test
    fun error_tooShort_showsKeepTalking() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.TooShort),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("too short · keep talking", text)
    }

    @Test
    fun error_connectionRequired_showsBestModeNeedsConnection() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.ConnectionRequired),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("best mode needs connection", text)
    }

    @Test
    fun error_noMatch_showsTooQuiet() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.NoMatch),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("nothing caught · too quiet?", text)
    }

    @Test
    fun error_insufficientPermissions_showsMicBlocked() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.InsufficientPermissions),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("mic blocked · tap to open settings", text)
    }

    @Test
    fun error_notAvailable_showsOfflineModelNotInstalled_withLanguage() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.NotAvailable("es-ES")),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("no offline model for Español", text)
    }

    @Test
    fun error_notAvailable_showsGenericMessage_whenLanguageEmpty() {
        val text = statusTextFor(
            recordingState = RecordingState.Error(RecognizerError.NotAvailable()),
            showBlockedMessage = false,
            hasEverRecorded = true,
        )
        assertEquals("offline model not installed", text)
    }

    @Test
    fun blocked_overridesAllNonIdleStates() {
        val text = statusTextFor(
            recordingState = RecordingState.Listening,
            showBlockedMessage = true,
            hasEverRecorded = true,
        )
        assertEquals("mic blocked · tap to open settings", text)
    }
}
