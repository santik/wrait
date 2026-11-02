import 'package:flutter/material.dart';

const Color wraitWarm100 = Color(0xFFFAF9F7);
const Color wraitWarm200 = Color(0xFFF0EDE8);
const Color wraitWarm300 = Color(0xFFE8E4DD);
const Color wraitCharcoalPrimary = Color(0xFF2C2B27);
const Color wraitCharcoalDark = Color(0xFF1A1917);
const Color wraitCharcoalMid = Color(0xFF5C5953);
const Color wraitCharcoalLight = Color(0xFF8C8983);

const Color wraitDark100 = Color(0xFF0F0F0D);
const Color wraitDark200 = Color(0xFF1A1917);
const Color wraitDark300 = Color(0xFF2A2926);
const Color wraitCreamPrimary = Color(0xFFE8E4DD);
const Color wraitCreamText = Color(0xFFEDE9E3);
const Color wraitCreamMid = Color(0xFFA8A4A0);
const Color wraitCreamLight = Color(0xFF6E6B67);

const Color wraitSemanticWarning = Color(0xFFF59E0B);
const Color wraitSemanticWarningContainer = Color(0xFFFEF3C7);
const Color wraitSemanticError = Color(0xFFEF4444);
const Color wraitSemanticErrorContainer = Color(0xFFFEE2E2);
const Color wraitSemanticInfo = Color(0xFF3B82F6);
const Color wraitSemanticInfoContainer = Color(0xFFDBEAFE);
const Color wraitSemanticSuccess = Color(0xFF22C55E);
const Color wraitSemanticSuccessContainer = Color(0xFFDCFCE7);
const Color wraitOnSemantic = Colors.white;

const Color wraitDarkWarningContainer = Color(0xFF3D2B00);
const Color wraitDarkErrorContainer = Color(0xFF4A1515);
const Color wraitDarkInfoContainer = Color(0xFF0F2A5C);
const Color wraitDarkSuccessContainer = Color(0xFF0A3520);

const Color wraitLightBackground = wraitWarm100;
const Color wraitDarkBackground = wraitDark100;

const ColorScheme wraitLightColorScheme = ColorScheme.light(
  primary: wraitCharcoalPrimary,
  onPrimary: wraitWarm100,
  primaryContainer: wraitWarm300,
  onPrimaryContainer: wraitCharcoalDark,
  secondary: wraitCharcoalMid,
  onSecondary: wraitWarm100,
  secondaryContainer: wraitWarm200,
  onSecondaryContainer: wraitCharcoalDark,
  tertiary: wraitCharcoalLight,
  onTertiary: wraitWarm100,
  tertiaryContainer: wraitWarm200,
  onTertiaryContainer: wraitCharcoalMid,
  error: wraitSemanticError,
  onError: wraitOnSemantic,
  errorContainer: wraitSemanticErrorContainer,
  onErrorContainer: wraitCharcoalDark,
  surface: wraitWarm200,
  onSurface: wraitCharcoalDark,
  surfaceContainerLowest: wraitWarm100,
  surfaceContainerLow: wraitWarm100,
  surfaceContainer: wraitWarm200,
  surfaceContainerHigh: wraitWarm200,
  surfaceContainerHighest: wraitWarm300,
  surfaceDim: wraitWarm200,
  surfaceBright: wraitWarm100,
  onSurfaceVariant: wraitCharcoalMid,
  outline: wraitCharcoalLight,
  outlineVariant: wraitWarm300,
  shadow: wraitCharcoalDark,
  scrim: wraitCharcoalDark,
  inverseSurface: wraitCharcoalDark,
  onInverseSurface: wraitWarm100,
  inversePrimary: wraitCreamPrimary,
  surfaceTint: wraitCharcoalPrimary,
);

const ColorScheme wraitDarkColorScheme = ColorScheme.dark(
  primary: wraitCreamPrimary,
  onPrimary: wraitDark200,
  primaryContainer: wraitDark300,
  onPrimaryContainer: wraitCreamText,
  secondary: wraitCreamMid,
  onSecondary: wraitDark200,
  secondaryContainer: wraitDark300,
  onSecondaryContainer: wraitCreamText,
  tertiary: wraitCreamLight,
  onTertiary: wraitDark200,
  tertiaryContainer: wraitDark300,
  onTertiaryContainer: wraitCreamMid,
  error: wraitSemanticError,
  onError: wraitDark200,
  errorContainer: wraitDarkErrorContainer,
  onErrorContainer: wraitSemanticErrorContainer,
  surface: wraitDark200,
  onSurface: wraitCreamText,
  surfaceContainerLowest: wraitDark100,
  surfaceContainerLow: wraitDark100,
  surfaceContainer: wraitDark200,
  surfaceContainerHigh: wraitDark200,
  surfaceContainerHighest: wraitDark300,
  surfaceDim: wraitDark200,
  surfaceBright: wraitDark300,
  onSurfaceVariant: wraitCreamMid,
  outline: wraitCreamLight,
  outlineVariant: wraitDark300,
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: wraitCreamText,
  onInverseSurface: wraitDark200,
  inversePrimary: wraitCharcoalPrimary,
  surfaceTint: wraitCreamPrimary,
);

class WraitSemanticColors extends ThemeExtension<WraitSemanticColors> {
  const WraitSemanticColors({
    required this.warning,
    required this.warningContainer,
    required this.error,
    required this.errorContainer,
    required this.info,
    required this.infoContainer,
    required this.success,
    required this.successContainer,
    required this.onSemantic,
  });

  final Color warning;
  final Color warningContainer;
  final Color error;
  final Color errorContainer;
  final Color info;
  final Color infoContainer;
  final Color success;
  final Color successContainer;
  final Color onSemantic;

  @override
  WraitSemanticColors copyWith({
    Color? warning,
    Color? warningContainer,
    Color? error,
    Color? errorContainer,
    Color? info,
    Color? infoContainer,
    Color? success,
    Color? successContainer,
    Color? onSemantic,
  }) {
    return WraitSemanticColors(
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      error: error ?? this.error,
      errorContainer: errorContainer ?? this.errorContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSemantic: onSemantic ?? this.onSemantic,
    );
  }

  @override
  WraitSemanticColors lerp(
    covariant ThemeExtension<WraitSemanticColors>? other,
    double t,
  ) {
    if (other is! WraitSemanticColors) {
      return this;
    }

    return WraitSemanticColors(
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t) ??
          warningContainer,
      error: Color.lerp(error, other.error, t) ?? error,
      errorContainer:
          Color.lerp(errorContainer, other.errorContainer, t) ?? errorContainer,
      info: Color.lerp(info, other.info, t) ?? info,
      infoContainer:
          Color.lerp(infoContainer, other.infoContainer, t) ?? infoContainer,
      success: Color.lerp(success, other.success, t) ?? success,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t) ??
          successContainer,
      onSemantic: Color.lerp(onSemantic, other.onSemantic, t) ?? onSemantic,
    );
  }
}

const WraitSemanticColors wraitLightSemanticColors = WraitSemanticColors(
  warning: wraitSemanticWarning,
  warningContainer: wraitSemanticWarningContainer,
  error: wraitSemanticError,
  errorContainer: wraitSemanticErrorContainer,
  info: wraitSemanticInfo,
  infoContainer: wraitSemanticInfoContainer,
  success: wraitSemanticSuccess,
  successContainer: wraitSemanticSuccessContainer,
  onSemantic: wraitOnSemantic,
);

const WraitSemanticColors wraitDarkSemanticColors = WraitSemanticColors(
  warning: wraitSemanticWarning,
  warningContainer: wraitDarkWarningContainer,
  error: wraitSemanticError,
  errorContainer: wraitDarkErrorContainer,
  info: wraitSemanticInfo,
  infoContainer: wraitDarkInfoContainer,
  success: wraitSemanticSuccess,
  successContainer: wraitDarkSuccessContainer,
  onSemantic: wraitOnSemantic,
);
