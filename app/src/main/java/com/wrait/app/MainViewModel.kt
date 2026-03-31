package com.wrait.app

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wrait.app.data.api.OpenAiApiService
import com.wrait.app.di.IoDispatcher
import com.wrait.app.data.speech.TranscriptionService
import com.wrait.app.domain.model.Entry
import com.wrait.app.domain.model.EntryStats
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.repository.PreferencesRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale
import javax.inject.Inject

@HiltViewModel
class MainViewModel @Inject constructor(
    private val preferencesRepository: PreferencesRepository,
    private val entryRepository: EntryRepository,
    private val transcriptionService: TranscriptionService,
    private val openAiApiService: OpenAiApiService,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher
) : ViewModel() {

    private val languageState = preferencesRepository.selectedLanguage.stateIn(
        scope = viewModelScope,
        started = SharingStarted.Eagerly,
        initialValue = Locale.getDefault().toLanguageTag()
    )

    val selectedLanguage: StateFlow<String> = languageState

    private val recordingController = MainRecordingController(
        languageState = languageState,
        entryRepository = entryRepository,
        transcriptionService = transcriptionService,
        openAiApiService = openAiApiService,
        ioDispatcher = ioDispatcher,
        scope = viewModelScope,
    )

    val recordingState: StateFlow<RecordingState> = recordingController.recordingState

    // Incremented on each NoMatch / TooShort error so ButtonArea can fire a shake
    // even when two identical error states are emitted in succession.
    val shakeErrorKey: StateFlow<Int> = recordingController.shakeErrorKey

    val entries: StateFlow<List<EntrySummary>> = entryRepository.getAllEntries()
        .map { list ->
            list.map { EntrySummary(it.id, it.rawTranscript, it.createdAt) }
        }
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    val entryStats: StateFlow<EntryStats> = entryRepository.getAllEntries()
        .map { list -> computeStats(list) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), EntryStats.Empty)

    internal val initJob: Job = viewModelScope.launch {
        entryRepository.deleteStaleDrafts()
    }

    // region — button handling

    fun onMainButtonTapped() {
        recordingController.onMainButtonTapped()
    }

    fun saveLanguage(code: String) {
        viewModelScope.launch {
            try {
                preferencesRepository.setLanguage(code)
                Log.d(TAG, "Language saved: $code")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save language: $code", e)
            }
        }
    }

    fun onPermissionRevoked() {
        recordingController.onPermissionRevoked()
    }

    fun onEntriesDeleted(count: Int) {
        recordingController.onEntriesDeleted(count)
    }

    // endregion

    // region — stats computation

    private fun computeStats(entries: List<Entry>): EntryStats {
        if (entries.isEmpty()) return EntryStats.Empty

        val zone   = ZoneId.systemDefault()
        val today  = LocalDate.now(zone)
        val monday = today.with(DayOfWeek.MONDAY)

        // Build a Set once — O(n) — so the 7 streak lookups are O(1) each instead of O(n) each
        val entryDates: Set<LocalDate> = entries.mapTo(HashSet()) { entry ->
            Instant.ofEpochMilli(entry.createdAt).atZone(zone).toLocalDate()
        }

        val streakDays = (0..6).map { offset ->
            monday.plusDays(offset.toLong()) in entryDates
        }

        return EntryStats(
            entryCount = entries.size,
            activeDays = entryDates.size,
            streakDays = streakDays
        )
    }

    // endregion

    private companion object {
        private const val TAG = "MainViewModel"
    }
}

sealed class RecordingState {
    data object Idle       : RecordingState()
    data object Listening  : RecordingState()
    data object Uploading  : RecordingState()
    data object Processing : RecordingState()
    data class Saved(val entryId: Long) : RecordingState()
    data class Error(val error: com.wrait.app.data.speech.RecognizerError) : RecordingState()
    data class Deleted(val count: Int) : RecordingState()
}

data class EntrySummary(
    val id: Long,
    val transcript: String,
    val createdAt: Long
)
