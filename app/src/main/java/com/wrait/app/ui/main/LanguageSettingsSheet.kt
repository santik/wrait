package com.wrait.app.ui.main

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.wrait.app.domain.model.LanguagePreferences
import com.wrait.app.domain.model.SUPPORTED_LANGUAGES
import com.wrait.app.domain.model.SupportedLanguage

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun LanguageSettingsSheet(
    languagePreferences: LanguagePreferences,
    onLanguageToggled: (String) -> Unit,
    onPrimaryLanguageSelected: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val selectedLanguages = languagePreferences.selectedLanguages.toSet()
    val sortedLanguages = remember(languagePreferences) {
        SUPPORTED_LANGUAGES.sortedWith(
            compareBy<SupportedLanguage> { it.code !in selectedLanguages }
                .thenBy { SUPPORTED_LANGUAGES.indexOf(it) }
        )
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column {
            Text(
                text = "Languages",
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
            )
            Text(
                text = "Choose one or more languages. Offline mode uses your primary language.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 24.dp),
            )
            LazyColumn(
                modifier = Modifier.fillMaxWidth(),
                contentPadding = PaddingValues(top = 12.dp, bottom = 24.dp),
            ) {
                items(sortedLanguages, key = { it.code }) { language ->
                    LanguageSettingsRow(
                        language = language,
                        isSelected = language.code in selectedLanguages,
                        isPrimary = language.code == languagePreferences.primaryLanguage,
                        canDeselect = !(selectedLanguages.size == 1 && language.code in selectedLanguages),
                        onToggleSelected = { onLanguageToggled(language.code) },
                        onSetPrimary = { onPrimaryLanguageSelected(language.code) },
                    )
                }
            }
        }
    }
}

@Composable
private fun LanguageSettingsRow(
    language: SupportedLanguage,
    isSelected: Boolean,
    isPrimary: Boolean,
    canDeselect: Boolean,
    onToggleSelected: () -> Unit,
    onSetPrimary: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 64.dp)
            .clickable(onClick = onToggleSelected)
            .padding(horizontal = 12.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Checkbox(
            checked = isSelected,
            onCheckedChange = { onToggleSelected() },
            enabled = isSelected.not() || canDeselect,
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = language.displayName,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface,
            )
            if (isPrimary) {
                Text(
                    text = "Primary",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
        RadioButton(
            selected = isPrimary,
            onClick = onSetPrimary,
        )
    }
}
