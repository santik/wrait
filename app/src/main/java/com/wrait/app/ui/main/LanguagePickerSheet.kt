package com.wrait.app.ui.main

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
import androidx.compose.ui.unit.dp

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

internal data class Language(val code: String, val displayName: String)

/** Ordered list of supported languages in v1. Names shown in their own script. */
internal val LANGUAGES: List<Language> = listOf(
    Language("en-US", "English"),
    Language("nl-NL", "Nederlands"),
    Language("ru-RU", "Русский"),
    Language("uk-UA", "Українська"),
    Language("de-DE", "Deutsch"),
    Language("es-ES", "Español"),
    Language("fr-FR", "Français"),
    Language("it-IT", "Italiano"),
    Language("pl-PL", "Polski"),
    Language("pt-PT", "Português"),
    Language("tr-TR", "Türkçe"),
)

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
    val languages  = remember { LANGUAGES }

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
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
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
