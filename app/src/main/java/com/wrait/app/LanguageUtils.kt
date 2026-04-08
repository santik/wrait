package com.wrait.app

/**
 * Returns true when [detected] represents a different base language than [selected].
 * Comparison uses base language codes only (e.g. "fr" from "fr-FR") and is case-insensitive.
 * Returns false when [detected] is null (no detection available).
 */
internal fun isLanguageMismatch(detected: String?, selected: String): Boolean =
    detected != null &&
        detected.substringBefore("-").lowercase() !=
        selected.substringBefore("-").lowercase()
