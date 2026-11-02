import 'package:flutter/widgets.dart';

/// Builds a localized value with graceful locale fallback.
///
/// Tries the full BCP-47 language tag first, then the bare language code, then
/// the platform default locale. Blank locale names are normalized to `null`,
/// and any attempt that throws (e.g. ICU does not know the locale) is skipped.
T formatWithLocaleFallback<T>(
  Locale locale,
  T Function(String? localeName) build,
) {
  T? attempt(String? localeName) {
    final normalized = localeName == null || localeName.trim().isEmpty
        ? null
        : localeName;
    try {
      return build(normalized);
    } catch (_) {
      return null;
    }
  }

  return attempt(locale.toLanguageTag()) ??
      attempt(locale.languageCode) ??
      attempt(null)!;
}
