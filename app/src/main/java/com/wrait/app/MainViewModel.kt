package com.wrait.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wrait.app.data.speech.RecognitionResult
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.data.speech.SpeechRecognizerManager
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.domain.repository.PreferencesRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.Locale
import javax.inject.Inject

@HiltViewModel
class MainViewModel @Inject constructor(
    preferencesRepository: PreferencesRepository,
    private val entryRepository: EntryRepository,
    private val speechRecognizerManager: SpeechRecognizerManager
) : ViewModel() {
    private val languageState = preferencesRepository.selectedLanguage.stateIn(
        scope = viewModelScope,
        started = SharingStarted.Eagerly,
        initialValue = Locale.getDefault().toLanguageTag()
    )

    private val _recordingState = MutableStateFlow<RecordingState>(RecordingState.Idle)
    val recordingState: StateFlow<RecordingState> = _recordingState.asStateFlow()

    val entries: StateFlow<List<EntrySummary>> = entryRepository.getAllEntries()
        .map { list ->
            list.map { EntrySummary(it.id, it.rawTranscript, it.createdAt) }
        }
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    private var listenJob: Job? = null

    fun onMainButtonTapped() {
        when (recordingState.value) {
            RecordingState.Idle -> startListening()
            RecordingState.Listening -> stopListening()
            RecordingState.Processing -> Unit
            is RecordingState.Saved -> _recordingState.value = RecordingState.Idle
            is RecordingState.Error -> _recordingState.value = RecordingState.Idle
        }
    }

    fun onPermissionRevoked() {
        stopListening(forceIdle = true)
    }

    private fun startListening() {
        listenJob?.cancel()
        _recordingState.value = RecordingState.Listening
        listenJob = viewModelScope.launch {
            val language = languageState.value
            speechRecognizerManager.listen(language).collect { result ->
                when (result) {
                    RecognitionResult.ListeningEnded -> {
                        if (_recordingState.value == RecordingState.Listening) {
                            _recordingState.value = RecordingState.Processing
                        }
                    }
                    RecognitionResult.Restarted -> Unit
                    is RecognitionResult.Final -> {
                        saveTranscript(result.text)
                    }
                    is RecognitionResult.Error -> {
                        emitError(result.error)
                    }
                    is RecognitionResult.Partial -> Unit
                }
            }
        }
    }

    private fun stopListening(forceIdle: Boolean = false) {
        speechRecognizerManager.stopListening()
        if (forceIdle) {
            listenJob?.cancel()
            _recordingState.value = RecordingState.Idle
        } else {
            _recordingState.value = RecordingState.Processing
        }
    }

    private suspend fun saveTranscript(text: String) {
        val language = languageState.value
        entryRepository.saveDraft(text, language)
        _recordingState.value = RecordingState.Saved(text)
        delayAndReset()
    }

    private suspend fun emitError(error: RecognizerError) {
        _recordingState.value = RecordingState.Error(error)
        delayAndReset()
    }

    private suspend fun delayAndReset() {
        listenJob?.cancel()
        delay(1500)
        _recordingState.value = RecordingState.Idle
    }
}

sealed class RecordingState {
    data object Idle : RecordingState()
    data object Listening : RecordingState()
    data object Processing : RecordingState()
    data class Saved(val transcript: String) : RecordingState()
    data class Error(val error: RecognizerError) : RecordingState()
}

data class EntrySummary(
    val id: Long,
    val transcript: String,
    val createdAt: Long
)
