import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/domain/model/supported_language.dart';

void main() {
  group('normalizeLocaleLikeLanguageCode', () {
    test('sanitizes whitespace, separators, and casing', () {
      expect(normalizeLocaleLikeLanguageCode(' FR_fr '), 'fr-FR');
      expect(normalizeLocaleLikeLanguageCode('en'), 'en');
    });

    test('rejects non-locale-shaped values', () {
      expect(normalizeLocaleLikeLanguageCode('zh-Hans-CN'), isNull);
      expect(normalizeLocaleLikeLanguageCode('en-001'), isNull);
      expect(normalizeLocaleLikeLanguageCode('abcd'), isNull);
      expect(normalizeLocaleLikeLanguageCode('   '), isNull);
    });
  });

  group('resolveSupportedLanguageCode', () {
    test('contains all automatically detected languages with native names', () {
      expect(supportedLanguages, hasLength(61));
      expect(
        supportedLanguages
            .map((language) => '${language.code}:${language.displayName}')
            .toList(),
        [
          'af:Afrikaans',
          'ar:العربية',
          'as:অসমীয়া',
          'be:Беларуская',
          'bg:Български',
          'bn:বাংলা',
          'bs:Bosanski',
          'ca:Català',
          'cs:Čeština',
          'da:Dansk',
          'de:Deutsch',
          'de-CH:Deutsch (Schweiz)',
          'el:Ελληνικά',
          'en:English',
          'es:Español',
          'et:Eesti',
          'fa:فارسی',
          'fi:Suomi',
          'fr:Français',
          'gu:ગુજરાતી',
          'he:עברית',
          'hi:हिन्दी',
          'hr:Hrvatski',
          'hu:Magyar',
          'hy:Հայերեն',
          'id:Bahasa Indonesia',
          'it:Italiano',
          'ja:日本語',
          'ka:ქართული',
          'kk:Қазақша',
          'kn:ಕನ್ನಡ',
          'ko:한국어',
          'lt:Lietuvių',
          'lv:Latviešu',
          'mk:Македонски',
          'mn:Монгол',
          'mr:मराठी',
          'ms:Bahasa Melayu',
          'ne:नेपाली',
          'nl:Nederlands',
          'nl-BE:Vlaams',
          'no:Norsk',
          'pa:ਪੰਜਾਬੀ',
          'pl:Polski',
          'ps:پښتو',
          'pt:Português',
          'ro:Română',
          'ru:Русский',
          'sk:Slovenčina',
          'sl:Slovenščina',
          'sr:Српски',
          'sv:Svenska',
          'ta:தமிழ்',
          'te:తెలుగు',
          'th:ไทย',
          'tl:Filipino',
          'tr:Türkçe',
          'uk:Українська',
          'ur:اردو',
          'vi:Tiếng Việt',
          'zh:中文',
        ],
      );
    });

    test('starts every cased display label with an uppercase character', () {
      for (final language in supportedLanguages) {
        final firstCharacter = language.displayName.substring(0, 1);
        final hasCase =
            firstCharacter.toLowerCase() != firstCharacter.toUpperCase();
        if (hasCase) {
          expect(
            firstCharacter,
            firstCharacter.toUpperCase(),
            reason: language.code,
          );
        }
      }
    });

    test('returns canonical code for exact supported value', () {
      for (final supportedLanguage in supportedLanguages) {
        expect(
          resolveSupportedLanguageCode(supportedLanguage.code),
          supportedLanguage.code,
        );
      }
    });

    test('normalizes case and underscores', () {
      expect(resolveSupportedLanguageCode('FR_fr'), 'fr-FR');
    });

    test('resolves base language to supported canonical value', () {
      expect(resolveSupportedLanguageCode('en'), 'en');
      expect(resolveSupportedLanguageCode('fr'), 'fr');
      expect(resolveSupportedLanguageCode(' pt '), 'pt');
    });

    test('preserves legacy regional tags used by existing records', () {
      expect(resolveSupportedLanguageCode('en-US'), 'en-US');
      expect(resolveSupportedLanguageCode('FR_fr'), 'fr-FR');
      expect(resolveSupportedLanguageCode('nl-NL'), 'nl-NL');
    });

    test('returns null for unsupported or blank values', () {
      expect(resolveSupportedLanguageCode(''), isNull);
      expect(resolveSupportedLanguageCode('zz-ZZ'), isNull);
      expect(resolveSupportedLanguageCode('zh-Hans-CN'), isNull);
      expect(resolveSupportedLanguageCode('en-001'), isNull);
      expect(resolveSupportedLanguageCode(null), isNull);
    });
  });
}
