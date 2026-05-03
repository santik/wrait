package com.wrait.app.data.api

/**
 * Shared Deepgram request contract for both DIRECT and PROXY transcription paths.
 *
 * Kept `internal` intentionally: this is transport-level wiring owned by the data layer.
 */
internal object DeepgramRequestParams {
    private enum class Model(val value: String) {
        NOVA_3_GENERAL("nova-3-general"),
    }

    private const val SMART_FORMAT = true
    private const val DETECT_LANGUAGE = true
    private const val UTTERANCES = false
    private const val FILLER_WORDS = true

    // Keep deterministic order for easier log diffing and test expectations.
    fun asPairs(): List<Pair<String, String>> = listOf(
        "model" to Model.NOVA_3_GENERAL.value,
        "smart_format" to SMART_FORMAT.toString(),
        "detect_language" to DETECT_LANGUAGE.toString(),
        "utterances" to UTTERANCES.toString(),
        "filler_words" to FILLER_WORDS.toString(),
    )
}
