package com.wrait.app.test.fake

import com.wrait.app.analytics.AnalyticsSavePath
import com.wrait.app.analytics.AnalyticsTracker
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.domain.model.PrivacyMode

class FakeAnalyticsTracker(
    private val shouldThrow: Boolean = false,
) : AnalyticsTracker {
    sealed class Event {
        data class AppOpened(
            val privacyMode: PrivacyMode,
            val entryCount: Int,
        ) : Event()

        data class RecordingStarted(
            val privacyMode: PrivacyMode,
            val selectedLanguage: String,
        ) : Event()

        data class TranscriptionSucceeded(
            val privacyMode: PrivacyMode,
            val detectedLanguagePresent: Boolean,
            val savePath: AnalyticsSavePath,
        ) : Event()

        data class TranscriptionFailed(
            val privacyMode: PrivacyMode,
            val error: RecognizerError,
        ) : Event()

        data class CleanupSucceeded(
            val privacyMode: PrivacyMode,
            val savePath: AnalyticsSavePath,
        ) : Event()

        data class CleanupFailed(
            val privacyMode: PrivacyMode,
            val savePath: AnalyticsSavePath,
            val reason: String,
        ) : Event()

        data class EntrySaved(
            val privacyMode: PrivacyMode,
            val savePath: AnalyticsSavePath,
        ) : Event()

        data class PrivacyModeToggled(
            val from: PrivacyMode,
            val to: PrivacyMode,
        ) : Event()

        data class EntriesListOpened(
            val entryCount: Int,
        ) : Event()

        data object OptIn : Event()
        data object OptOut : Event()
    }

    private val _events = mutableListOf<Event>()
    val events: List<Event> get() = _events.toList()

    override fun trackAppOpened(privacyMode: PrivacyMode, entryCount: Int) {
        record(Event.AppOpened(privacyMode, entryCount))
    }

    override fun trackRecordingStarted(privacyMode: PrivacyMode, selectedLanguage: String) {
        record(Event.RecordingStarted(privacyMode, selectedLanguage))
    }

    override fun trackTranscriptionSucceeded(
        privacyMode: PrivacyMode,
        detectedLanguagePresent: Boolean,
        savePath: AnalyticsSavePath,
    ) {
        record(Event.TranscriptionSucceeded(privacyMode, detectedLanguagePresent, savePath))
    }

    override fun trackTranscriptionFailed(privacyMode: PrivacyMode, error: RecognizerError) {
        record(Event.TranscriptionFailed(privacyMode, error))
    }

    override fun trackCleanupSucceeded(privacyMode: PrivacyMode, savePath: AnalyticsSavePath) {
        record(Event.CleanupSucceeded(privacyMode, savePath))
    }

    override fun trackCleanupFailed(
        privacyMode: PrivacyMode,
        savePath: AnalyticsSavePath,
        reason: String,
    ) {
        record(Event.CleanupFailed(privacyMode, savePath, reason))
    }

    override fun trackEntrySaved(privacyMode: PrivacyMode, savePath: AnalyticsSavePath) {
        record(Event.EntrySaved(privacyMode, savePath))
    }

    override fun trackPrivacyModeToggled(from: PrivacyMode, to: PrivacyMode) {
        record(Event.PrivacyModeToggled(from, to))
    }

    override fun trackEntriesListOpened(entryCount: Int) {
        record(Event.EntriesListOpened(entryCount))
    }

    override fun optIn() {
        record(Event.OptIn)
    }

    override fun optOut() {
        record(Event.OptOut)
    }

    private fun record(event: Event) {
        if (shouldThrow) {
            throw IllegalStateException("Forced analytics failure")
        }
        _events += event
    }
}
