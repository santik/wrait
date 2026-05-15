package com.wrait.app.data.api

import com.wrait.app.data.api.generated.model.ErrorResponse
import kotlinx.serialization.json.Json

internal object BackendErrorParser {
    private val json = Json { ignoreUnknownKeys = true }

    fun parseRaw(body: String?): String? {
        if (body.isNullOrBlank()) return null
        return runCatching {
            json.decodeFromString<ErrorResponse>(body)
                .error
                .trim()
                .takeIf { it.isNotEmpty() }
        }.getOrNull()
    }
}
