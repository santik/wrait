package com.wrait.app.domain.model

data class EntryStats(
    val entryCount: Int,
    val activeDays: Int,
) {
    companion object {
        val Empty = EntryStats(
            entryCount = 0,
            activeDays = 0,
        )
    }
}
