package com.wrait.app.domain.model

/**
 * BCP-47 codes of all languages the app supports for transcription.
 * Single source of truth shared by the language picker (UI) and the
 * preferences repository (data) — add or remove languages here only.
 */
val SUPPORTED_LANGUAGE_CODES: Set<String> = setOf(
    "en-US", "nl-NL", "ru-RU", "uk-UA",
    "de-DE", "es-ES", "fr-FR", "it-IT",
    "pl-PL", "pt-PT", "tr-TR"
)
