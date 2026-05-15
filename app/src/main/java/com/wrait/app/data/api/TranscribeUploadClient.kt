package com.wrait.app.data.api

import java.io.File

interface TranscribeUploadClient {
    suspend fun transcribe(audioFile: File): TranscribeHttpResponse
}

data class TranscribeHttpResponse(
    val statusCode: Int,
    val body: String?,
)

internal class DeviceIdUnavailableException(
    message: String,
) : IllegalStateException(message)
