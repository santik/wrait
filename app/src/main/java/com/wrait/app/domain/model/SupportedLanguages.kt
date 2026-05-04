package com.wrait.app.domain.model

import java.util.Locale

data class SupportedLanguage(
    val code: String,
    val displayName: String,
)

/**
 * Single source of truth shared by UI and preferences validation.
 */
val SUPPORTED_LANGUAGES: List<SupportedLanguage> = listOf(
    SupportedLanguage("en-US", "English"),
    SupportedLanguage("nl-NL", "Nederlands"),
    SupportedLanguage("ru-RU", "Русский"),
    SupportedLanguage("uk-UA", "Українська"),
    SupportedLanguage("de-DE", "Deutsch"),
    SupportedLanguage("es-ES", "Español"),
    SupportedLanguage("fr-FR", "Français"),
    SupportedLanguage("it-IT", "Italiano"),
    SupportedLanguage("pl-PL", "Polski"),
    SupportedLanguage("pt-PT", "Português"),
    SupportedLanguage("tr-TR", "Türkçe"),
)

val SUPPORTED_LANGUAGE_CODES: Set<String> = SUPPORTED_LANGUAGES
    .mapTo(linkedSetOf()) { it.code }

fun normalizeDetectedLanguageCode(code: String?): String? {
    if (code.isNullOrBlank()) return null

    val sanitized = code.trim().replace('_', '-')
    val locale = Locale.forLanguageTag(sanitized)
    val language = locale.language
    if (language.isBlank() || language == "und") return null

    val normalized = locale.toLanguageTag()
    return if (normalized.isBlank() || normalized == "und") null else normalized
}

fun resolveSupportedLanguageCode(code: String?): String? {
    if (code.isNullOrBlank()) return null

    SUPPORTED_LANGUAGES.firstOrNull { it.code.equals(code, ignoreCase = true) }?.let {
        return it.code
    }

    val baseLanguage = code.substringBefore("-")
    return SUPPORTED_LANGUAGES.firstOrNull {
        it.code.substringBefore("-").equals(baseLanguage, ignoreCase = true)
    }?.code
}

fun defaultSupportedLanguageCode(localeTag: String = Locale.getDefault().toLanguageTag()): String {
    return resolveSupportedLanguageCode(localeTag) ?: "en-US"
}

fun displayNameForLanguage(code: String): String {
    return SUPPORTED_LANGUAGES.firstOrNull { it.code.equals(code, ignoreCase = true) }
        ?.displayName
        ?: Locale.forLanguageTag(code).displayLanguage.replaceFirstChar { it.uppercaseChar() }
}
