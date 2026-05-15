package com.wrait.app.data.api

import okhttp3.MediaType
import okhttp3.MediaType.Companion.toMediaType
import java.io.File

/**
 * Shared upload metadata for the recorded audio files sent to `/api/transcribe`.
 *
 * The app currently records audio into an audio-only MPEG-4 container and stores it with the
 * `.m4a` extension. For wire compatibility, those files are uploaded as `audio/mp4`, while
 * `.wav` and `.webm` keep their native media types. Unknown extensions fall back to `audio/mp4`
 * because that is the stable format produced by the in-app recorder today.
 */
internal object BackendAudioUploadConfig {
    const val RECORDED_AUDIO_FILE_EXTENSION = "m4a"

    private val fallbackMediaType = "audio/mp4".toMediaType()

    fun mediaTypeFor(file: File): MediaType {
        return when (file.extension.lowercase()) {
            "m4a", "mp4" -> "audio/mp4".toMediaType()
            "wav" -> "audio/wav".toMediaType()
            "webm" -> "audio/webm".toMediaType()
            else -> fallbackMediaType
        }
    }
}
