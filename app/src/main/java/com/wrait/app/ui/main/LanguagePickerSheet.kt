package com.wrait.app.ui.main

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import java.util.Locale

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

internal data class Language(val code: String, val displayName: String)

/** Ordered list of supported languages in v1. Names shown in their own script. */
internal val LANGUAGES: List<Language> = listOf(
    Language("en-US", "English (US)"),
    Language("nl-NL", "Nederlands"),
    Language("ru-RU", "Русский"),
    Language("uk-UA", "Українська"),
    Language("en-GB", "English (UK)"),
    Language("de-DE", "Deutsch"),
    Language("fr-FR", "Français"),
    Language("es-ES", "Español"),
    Language("pl-PL", "Polski"),
    Language("it-IT", "Italiano"),
    Language("pt-PT", "Português"),
    Language("tr-TR", "Türkçe"),
)

/**
 * Returns the LANGUAGES list with the device locale entry pinned to the top and
 * the remaining entries sorted alphabetically by display name.
 *
 * Matching tries exact BCP-47 tag first, then the language subtag prefix
 * (e.g. device locale "en" matches "en-US"). Returns a purely alphabetical list
 * when the device locale has no match in LANGUAGES.
 */
internal fun sortedLanguages(): List<Language> {
    val deviceTag  = Locale.getDefault().toLanguageTag()
    val deviceLang = Locale.getDefault().language

    val deviceEntry = LANGUAGES.firstOrNull { it.code == deviceTag }
        ?: LANGUAGES.firstOrNull { it.code.startsWith("$deviceLang-") }

    val rest = LANGUAGES
        .filter { it != deviceEntry }
        .sortedBy { it.displayName }

    return if (deviceEntry != null) listOf(deviceEntry) + rest else rest
}

// ---------------------------------------------------------------------------
// Composable
// ---------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun LanguagePickerSheet(
    selectedLanguage: String,
    onLanguageSelected: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val languages  = remember { sortedLanguages() }

    // Code of the device-locale entry (used only to apply the subtle tint).
    val deviceLocaleCode = remember {
        val deviceTag  = Locale.getDefault().toLanguageTag()
        val deviceLang = Locale.getDefault().language
        (LANGUAGES.firstOrNull { it.code == deviceTag }
            ?: LANGUAGES.firstOrNull { it.code.startsWith("$deviceLang-") })?.code
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(bottom = 16.dp),
        ) {
            items(languages, key = { it.code }) { lang ->
                LanguageRow(
                    language      = lang,
                    isSelected    = lang.code == selectedLanguage,
                    isDeviceLocale = lang.code == deviceLocaleCode,
                    onClick       = {
                        onLanguageSelected(lang.code)
                        onDismiss()
                    },
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Row
// ---------------------------------------------------------------------------

@Composable
private fun LanguageRow(
    language: Language,
    isSelected: Boolean,
    isDeviceLocale: Boolean,
    onClick: () -> Unit,
) {
    val bgColor = if (isDeviceLocale)
        MaterialTheme.colorScheme.primary.copy(alpha = 0.08f)
    else
        Color.Transparent

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .background(bgColor)
            .clickable(onClick = onClick)
            .padding(horizontal = 24.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text     = language.displayName,
            style    = MaterialTheme.typography.labelLarge,
            color    = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        if (isSelected) {
            Icon(
                imageVector        = Icons.Filled.Check,
                contentDescription = null,
                tint               = MaterialTheme.colorScheme.primary,
            )
        }
    }
}
