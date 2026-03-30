package com.wrait.app.domain.model

import java.util.UUID

enum class MessageType { DraftCleaned, CleanupFailed, NetworkError }
enum class MessageStripLevel { None, Warning }

data class AppMessage(
    val id: UUID,
    val type: MessageType,
    val title: String,
    val description: String,
    val actionLabel: String? = null,
    val entryId: Long? = null,
    val createdAt: Long,
)
