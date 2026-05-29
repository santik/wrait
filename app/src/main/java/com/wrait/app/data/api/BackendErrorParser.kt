package com.wrait.app.data.api

import android.util.Log
import com.wrait.app.data.api.generated.model.DailyRecordLimitExceededResponse
import com.wrait.app.data.api.generated.infrastructure.Serializer
import com.wrait.app.data.api.generated.model.ErrorResponse

internal object BackendErrorParser {
    private const val TAG = "BackendErrorParser"
    private val json = Serializer.kotlinxSerializationJson

    fun parseRaw(body: String?): String? {
        if (body.isNullOrBlank()) return null
        return runCatching {
            json.decodeFromString<ErrorResponse>(body)
                .error
                .trim()
                .takeIf { it.isNotEmpty() }
        }.getOrNull()
    }

    fun parseQuotaExceeded(body: String?): RecordQuotaState? {
        if (body.isNullOrBlank()) return null
        return try {
            json.decodeFromString<DailyRecordLimitExceededResponse>(body)
                .quota
                .toRecordQuotaStateOrNull("429 quota-exceeded response")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse quota from 429 response body", e)
            null
        }
    }
}
