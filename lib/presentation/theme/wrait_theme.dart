import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'wrait_colors.dart';
import 'wrait_typography.dart';

final ThemeData wraitLightTheme = _buildTheme(
  colorScheme: wraitLightColorScheme,
  semanticColors: wraitLightSemanticColors,
  backgroundColor: wraitLightBackground,
  bodyColor: wraitCharcoalDark,
);

final ThemeData wraitDarkTheme = _buildTheme(
  colorScheme: wraitDarkColorScheme,
  semanticColors: wraitDarkSemanticColors,
  backgroundColor: wraitDarkBackground,
  bodyColor: wraitCreamText,
);

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required WraitSemanticColors semanticColors,
  required Color backgroundColor,
  required Color bodyColor,
}) {
  final textTheme = wraitTextTheme.apply(
    bodyColor: bodyColor,
    displayColor: bodyColor,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: backgroundColor,
    canvasColor: backgroundColor,
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[semanticColors],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: bodyColor,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleMedium,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WraitRadiusTokens.card),
      ),
    ),
  );
}
