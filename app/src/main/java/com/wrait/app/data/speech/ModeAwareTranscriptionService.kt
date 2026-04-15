package com.wrait.app.data.speech

import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.repository.PreferencesRepository
import kotlinx.coroutines.flow.first
import javax.inject.Inject

class ModeAwareTranscriptionService @Inject constructor(
    private val deepgramService: DeepgramTranscriptionService,
    private val androidService: AndroidTranscriptionService,
    private val preferencesRepository: PreferencesRepository,
) : TranscriptionService {

    private suspend fun backend(): TranscriptionService {
        return if (preferencesRepository.privacyMode.first() == PrivacyMode.MODE_OFFLINE) {
            androidService
        } else {
            deepgramService
        }
    }

    override suspend fun transcribe(
        languageCode: String,
        onStatus: (TranscriptionStatus) -> Unit,
    ): TranscriptionResult = backend().transcribe(languageCode, onStatus)

    override suspend fun transcribeAudioDraft(
        audioPath: String,
        languageCode: String,
        onStatus: (TranscriptionStatus) -> Unit,
    ): TranscriptionResult = backend().transcribeAudioDraft(audioPath, languageCode, onStatus)

    override fun isOfflineModelAvailable(): Boolean =
        androidService.isOfflineModelAvailable()

    override fun stopRecording() {
        // Only one service is active at a time, but stop is cheap on the idle one.
        deepgramService.stopRecording()
        androidService.stopRecording()
    }
}

