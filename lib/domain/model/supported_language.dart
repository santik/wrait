class SupportedLanguage {
  const SupportedLanguage({required this.code, required this.displayName});

  final String code;
  final String displayName;
}

const supportedLanguages = <SupportedLanguage>[
  SupportedLanguage(code: 'af', displayName: 'Afrikaans'),
  SupportedLanguage(code: 'ar', displayName: 'العربية'),
  SupportedLanguage(code: 'as', displayName: 'অসমীয়া'),
  SupportedLanguage(code: 'be', displayName: 'Беларуская'),
  SupportedLanguage(code: 'bg', displayName: 'Български'),
  SupportedLanguage(code: 'bn', displayName: 'বাংলা'),
  SupportedLanguage(code: 'bs', displayName: 'Bosanski'),
  SupportedLanguage(code: 'ca', displayName: 'Català'),
  SupportedLanguage(code: 'cs', displayName: 'Čeština'),
  SupportedLanguage(code: 'da', displayName: 'Dansk'),
  SupportedLanguage(code: 'de', displayName: 'Deutsch'),
  SupportedLanguage(code: 'de-CH', displayName: 'Deutsch (Schweiz)'),
  SupportedLanguage(code: 'el', displayName: 'Ελληνικά'),
  SupportedLanguage(code: 'en', displayName: 'English'),
  SupportedLanguage(code: 'es', displayName: 'Español'),
  SupportedLanguage(code: 'et', displayName: 'Eesti'),
  SupportedLanguage(code: 'fa', displayName: 'فارسی'),
  SupportedLanguage(code: 'fi', displayName: 'Suomi'),
  SupportedLanguage(code: 'fr', displayName: 'Français'),
  SupportedLanguage(code: 'gu', displayName: 'ગુજરાતી'),
  SupportedLanguage(code: 'he', displayName: 'עברית'),
  SupportedLanguage(code: 'hi', displayName: 'हिन्दी'),
  SupportedLanguage(code: 'hr', displayName: 'Hrvatski'),
  SupportedLanguage(code: 'hu', displayName: 'Magyar'),
  SupportedLanguage(code: 'hy', displayName: 'Հայերեն'),
  SupportedLanguage(code: 'id', displayName: 'Bahasa Indonesia'),
  SupportedLanguage(code: 'it', displayName: 'Italiano'),
  SupportedLanguage(code: 'ja', displayName: '日本語'),
  SupportedLanguage(code: 'ka', displayName: 'ქართული'),
  SupportedLanguage(code: 'kk', displayName: 'Қазақша'),
  SupportedLanguage(code: 'kn', displayName: 'ಕನ್ನಡ'),
  SupportedLanguage(code: 'ko', displayName: '한국어'),
  SupportedLanguage(code: 'lt', displayName: 'Lietuvių'),
  SupportedLanguage(code: 'lv', displayName: 'Latviešu'),
  SupportedLanguage(code: 'mk', displayName: 'Македонски'),
  SupportedLanguage(code: 'mn', displayName: 'Монгол'),
  SupportedLanguage(code: 'mr', displayName: 'मराठी'),
  SupportedLanguage(code: 'ms', displayName: 'Bahasa Melayu'),
  SupportedLanguage(code: 'ne', displayName: 'नेपाली'),
  SupportedLanguage(code: 'nl', displayName: 'Nederlands'),
  SupportedLanguage(code: 'nl-BE', displayName: 'Vlaams'),
  SupportedLanguage(code: 'no', displayName: 'Norsk'),
  SupportedLanguage(code: 'pa', displayName: 'ਪੰਜਾਬੀ'),
  SupportedLanguage(code: 'pl', displayName: 'Polski'),
  SupportedLanguage(code: 'ps', displayName: 'پښتو'),
  SupportedLanguage(code: 'pt', displayName: 'Português'),
  SupportedLanguage(code: 'ro', displayName: 'Română'),
  SupportedLanguage(code: 'ru', displayName: 'Русский'),
  SupportedLanguage(code: 'sk', displayName: 'Slovenčina'),
  SupportedLanguage(code: 'sl', displayName: 'Slovenščina'),
  SupportedLanguage(code: 'sr', displayName: 'Српски'),
  SupportedLanguage(code: 'sv', displayName: 'Svenska'),
  SupportedLanguage(code: 'ta', displayName: 'தமிழ்'),
  SupportedLanguage(code: 'te', displayName: 'తెలుగు'),
  SupportedLanguage(code: 'th', displayName: 'ไทย'),
  SupportedLanguage(code: 'tl', displayName: 'Filipino'),
  SupportedLanguage(code: 'tr', displayName: 'Türkçe'),
  SupportedLanguage(code: 'uk', displayName: 'Українська'),
  SupportedLanguage(code: 'ur', displayName: 'اردو'),
  SupportedLanguage(code: 'vi', displayName: 'Tiếng Việt'),
  SupportedLanguage(code: 'zh', displayName: '中文'),
];

// These regional tags were persisted by earlier app versions. Keep resolving
// them to their original canonical values so reading or retrying an existing
// entry does not rewrite its stored language tag.
const _legacySupportedLanguageAliases = <String, String>{
  'en-us': 'en-US',
  'nl-nl': 'nl-NL',
  'ru-ru': 'ru-RU',
  'uk-ua': 'uk-UA',
  'de-de': 'de-DE',
  'es-es': 'es-ES',
  'fr-fr': 'fr-FR',
  'it-it': 'it-IT',
  'pl-pl': 'pl-PL',
  'pt-pt': 'pt-PT',
  'tr-tr': 'tr-TR',
};

final supportedLanguageCodes = supportedLanguages
    .map((language) => language.code)
    .toSet();

SupportedLanguage? _findExactMatch(String normalizedCode) {
  final lower = normalizedCode.toLowerCase();
  for (final language in supportedLanguages) {
    if (language.code.toLowerCase() == lower) {
      return language;
    }
  }
  return null;
}

String? supportedLanguageDisplayName(String? code) {
  final normalized = normalizeLocaleLikeLanguageCode(code);
  if (normalized == null) {
    return null;
  }

  final exact = _findExactMatch(normalized);
  if (exact != null) {
    return exact.displayName;
  }

  return _findExactMatch(normalized.split('-').first)?.displayName;
}

String? sanitizeLanguageCode(String? code) {
  if (code == null) {
    return null;
  }

  final sanitized = code.trim().replaceAll('_', '-');
  if (sanitized.isEmpty) {
    return null;
  }

  return sanitized;
}

String? normalizeLocaleLikeLanguageCode(String? code) {
  final sanitized = sanitizeLanguageCode(code);
  if (sanitized == null) {
    return null;
  }

  final parts = sanitized.split('-');
  if (parts.length > 2) {
    return null;
  }

  final languageCode = parts.first;
  if (!_languageCodePattern.hasMatch(languageCode)) {
    return null;
  }

  if (parts.length == 1) {
    return languageCode.toLowerCase();
  }

  final countryCode = parts[1];
  if (!_countryCodePattern.hasMatch(countryCode)) {
    return null;
  }

  return '${languageCode.toLowerCase()}-${countryCode.toUpperCase()}';
}

String? resolveSupportedLanguageCode(String? code) {
  final normalized = normalizeLocaleLikeLanguageCode(code);
  if (normalized == null) {
    return null;
  }

  final exact = _findExactMatch(normalized);
  if (exact != null) {
    return exact.code;
  }

  final legacyAlias = _legacySupportedLanguageAliases[normalized.toLowerCase()];
  if (legacyAlias != null) {
    return legacyAlias;
  }

  final baseLanguage = normalized.split('-').first.toLowerCase();
  for (final language in supportedLanguages) {
    if (language.code.split('-').first.toLowerCase() == baseLanguage) {
      return language.code;
    }
  }

  return null;
}

final _languageCodePattern = RegExp(r'^[A-Za-z]{2,3}$');
final _countryCodePattern = RegExp(r'^[A-Za-z]{2}$');
