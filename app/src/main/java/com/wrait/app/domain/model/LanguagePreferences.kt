package com.wrait.app.domain.model

data class LanguagePreferences(
    val selectedLanguages: List<String>,
    val primaryLanguage: String,
)

fun defaultLanguagePreferences(): LanguagePreferences =
    normalizeLanguagePreferences(emptyList(), null)

fun normalizeLanguagePreferences(
    selectedLanguages: List<String>,
    primaryLanguage: String?,
): LanguagePreferences {
    val normalizedSelected = selectedLanguages
        .mapNotNull(::resolveSupportedLanguageCode)
        .distinct()

    val fallback = defaultSupportedLanguageCode()
    val ensuredSelected = if (normalizedSelected.isEmpty()) listOf(fallback) else normalizedSelected
    val requestedPrimary = resolveSupportedLanguageCode(primaryLanguage) ?: fallback
    val ensuredPrimary = if (requestedPrimary in ensuredSelected) {
        requestedPrimary
    } else {
        ensuredSelected.first()
    }

    return LanguagePreferences(
        selectedLanguages = ensuredSelected,
        primaryLanguage = ensuredPrimary,
    )
}
