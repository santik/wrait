package com.wrait.app.data.speech

import org.junit.Assert.assertEquals
import org.junit.Test

class CloudTranscriptionServiceTest {

    @Test
    fun transcriptionFailureReasonForStatus_401_returnsProxyAuthFailed() {
        assertEquals(
            TranscriptionFailureReason.ProxyAuthFailed,
            transcriptionFailureReasonForStatus(401),
        )
    }

    @Test
    fun transcriptionFailureReasonForStatus_403_returnsProxyAuthFailed() {
        assertEquals(
            TranscriptionFailureReason.ProxyAuthFailed,
            transcriptionFailureReasonForStatus(403),
        )
    }

    @Test
    fun transcriptionFailureReasonForStatus_503_returnsBackendUnavailable() {
        assertEquals(
            TranscriptionFailureReason.BackendUnavailable,
            transcriptionFailureReasonForStatus(503),
        )
    }

    @Test
    fun transcriptionFailureReasonForStatus_400_returnsApiError() {
        assertEquals(
            TranscriptionFailureReason.ApiError,
            transcriptionFailureReasonForStatus(400),
        )
    }
}
