package com.wrait.app.test.fake

import android.content.Context
import com.wrait.app.data.speech.RecognitionResult
import com.wrait.app.data.speech.RecognizerError
import com.wrait.app.data.speech.SpeechRecognizerManager
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

class FakeSpeechRecognizerManager(context: Context) : SpeechRecognizerManager(context) {

    sealed class FakeResult {
        data class FinalTranscript(val text: String) : FakeResult()
        data class SpeechError(val error: RecognizerError) : FakeResult()
    }

    var nextResult: FakeResult = FakeResult.FinalTranscript("one two three four five")

    override fun listen(
        languageCode: String,
        preferOffline: Boolean,
    ): Flow<RecognitionResult> = flow {
        emit(RecognitionResult.ListeningEnded)
        when (val r = nextResult) {
            is FakeResult.FinalTranscript -> emit(RecognitionResult.Final(r.text))
            is FakeResult.SpeechError -> emit(RecognitionResult.Error(r.error))
        }
    }

    override fun stopListening() { /* no-op */ }

    override fun isOnDeviceRecognitionAvailable(): Boolean = true
}
