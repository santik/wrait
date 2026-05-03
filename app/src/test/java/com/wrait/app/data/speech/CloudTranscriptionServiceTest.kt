package com.wrait.app.data.speech

import io.ktor.http.HttpStatusCode
import org.junit.Assert.assertEquals
import org.junit.Test

class CloudTranscriptionServiceTest {

    @Test
    fun transcriptionFailureReasonForStatus_401_returnsProxyAuthFailed() {
        assertEquals(
            TranscriptionFailureReason.ProxyAuthFailed,
            transcriptionFailureReasonForStatus(HttpStatusCode.Unauthorized),
        )
    }

    @Test
    fun transcriptionFailureReasonForStatus_403_returnsProxyAuthFailed() {
        assertEquals(
            TranscriptionFailureReason.ProxyAuthFailed,
            transcriptionFailureReasonForStatus(HttpStatusCode.Forbidden),
        )
    }

    @Test
    fun transcriptionFailureReasonForStatus_503_returnsBackendUnavailable() {
        assertEquals(
            TranscriptionFailureReason.BackendUnavailable,
            transcriptionFailureReasonForStatus(HttpStatusCode.ServiceUnavailable),
        )
    }

    @Test
    fun transcriptionFailureReasonForStatus_400_returnsApiError() {
        assertEquals(
            TranscriptionFailureReason.ApiError,
            transcriptionFailureReasonForStatus(HttpStatusCode.BadRequest),
        )
    }
}
