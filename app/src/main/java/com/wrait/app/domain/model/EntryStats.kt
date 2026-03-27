package com.wrait.app.domain.model

data class EntryStats(
    val entryCount: Int,
    val activeDays: Int,
    /** 7 booleans: index 0 = Monday … index 6 = Sunday of the current calendar week. */
    val streakDays: List<Boolean>
) {
    companion object {
        val Empty = EntryStats(
            entryCount = 0,
            activeDays = 0,
            streakDays = List(7) { false }
        )
    }
}
