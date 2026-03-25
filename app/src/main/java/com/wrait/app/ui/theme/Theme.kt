package com.wrait.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

private val LightColorScheme = lightColorScheme(
    primary = CharcoalPrimary,
    onPrimary = Warm100,
    primaryContainer = Warm300,
    onPrimaryContainer = CharcoalDark,
    secondary = CharcoalMid,
    onSecondary = Warm100,
    secondaryContainer = Warm200,
    onSecondaryContainer = CharcoalDark,
    tertiary = CharcoalLight,
    onTertiary = Warm100,
    tertiaryContainer = Warm200,
    onTertiaryContainer = CharcoalMid,
    background = Warm100,
    onBackground = CharcoalDark,
    surface = Warm200,
    onSurface = CharcoalDark,
    surfaceVariant = Warm300,
    onSurfaceVariant = CharcoalMid,
    outline = CharcoalLight,
    error = SemanticError,
    onError = OnSemantic,
    errorContainer = SemanticErrorContainer,
    onErrorContainer = CharcoalDark
)

private val DarkColorScheme = darkColorScheme(
    primary = CreamPrimary,
    onPrimary = Dark200,
    primaryContainer = Dark300,
    onPrimaryContainer = CreamText,
    secondary = CreamMid,
    onSecondary = Dark200,
    secondaryContainer = Dark300,
    onSecondaryContainer = CreamText,
    tertiary = CreamLight,
    onTertiary = Dark200,
    tertiaryContainer = Dark300,
    onTertiaryContainer = CreamMid,
    background = Dark100,
    onBackground = CreamText,
    surface = Dark200,
    onSurface = CreamText,
    surfaceVariant = Dark300,
    onSurfaceVariant = CreamMid,
    outline = CreamLight,
    error = SemanticError,
    onError = Dark200,
    errorContainer = Color(0xFF4A1515),
    onErrorContainer = SemanticErrorContainer
)

@Immutable
data class WraitSemanticColors(
    val warning: Color,
    val warningContainer: Color,
    val error: Color,
    val errorContainer: Color,
    val info: Color,
    val infoContainer: Color,
    val success: Color,
    val successContainer: Color,
    val onSemantic: Color
)

private val LightSemanticColors = WraitSemanticColors(
    warning = SemanticWarning,
    warningContainer = SemanticWarningContainer,
    error = SemanticError,
    errorContainer = SemanticErrorContainer,
    info = SemanticInfo,
    infoContainer = SemanticInfoContainer,
    success = SemanticSuccess,
    successContainer = SemanticSuccessContainer,
    onSemantic = OnSemantic
)

private val DarkSemanticColors = WraitSemanticColors(
    warning = SemanticWarning,
    warningContainer = Color(0xFF3D2B00),
    error = SemanticError,
    errorContainer = Color(0xFF4A1515),
    info = SemanticInfo,
    infoContainer = Color(0xFF0F2A5C),
    success = SemanticSuccess,
    successContainer = Color(0xFF0A3520),
    onSemantic = OnSemantic
)

val LocalWraitSemanticColors = staticCompositionLocalOf { LightSemanticColors }

object WrAItTheme {
    val semanticColors: WraitSemanticColors
        @Composable get() = LocalWraitSemanticColors.current
}

@Composable
fun WrAItTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    val semanticColors = if (darkTheme) DarkSemanticColors else LightSemanticColors

    CompositionLocalProvider(LocalWraitSemanticColors provides semanticColors) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = Typography,
            content = content
        )
    }
}
