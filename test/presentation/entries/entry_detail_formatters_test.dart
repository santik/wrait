import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/l10n/app_localizations.dart';
import 'package:wrait/presentation/entries/entry_detail_formatters.dart';

import '../../test_doubles/l10n_test_helper.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() {
    l10n = testL10n();
  });
  test('prefers cleaned text when it is available', () {
    final entry = _entry(cleanedText: 'clean text', rawTranscript: 'raw text');

    expect(entryDetailDisplayText(entry), 'clean text');
  });

  test('falls back to raw transcript when cleaned text is unavailable', () {
    final entry = _entry(cleanedText: null, rawTranscript: 'raw text');

    expect(entryDetailDisplayText(entry), 'raw text');
  });

  test('treats blank entries as unreadable', () {
    final entry = _entry(cleanedText: null, rawTranscript: '');

    expect(entryDetailIsReadable(entry), isFalse);
  });

  test('formats a full weekday and date label', () {
    final label = formatEntryDetailDate(
      createdAt: DateTime(2026, 6, 16, 9).millisecondsSinceEpoch,
      locale: const Locale('en', 'US'),
    );

    expect(label.weekday, 'Tuesday');
    expect(label.date, contains('June'));
  });

  test('formats the share timestamp using the in-app date and time style', () {
    final label = formatEntryDetailShareTimestamp(
      createdAt: DateTime(2026, 6, 16, 9).millisecondsSinceEpoch,
      locale: const Locale('en', 'US'),
    );

    expect(label, startsWith('Tuesday, June 16, 2026 · 9:00'));
    expect(label, contains('AM'));
  });

  test('falls back safely for unsupported locales', () {
    final label = formatEntryDetailDate(
      createdAt: DateTime(2026, 6, 16, 9).millisecondsSinceEpoch,
      locale: const Locale('zz', 'ZZ'),
    );

    expect(label.weekday, isNotEmpty);
    expect(label.date, isNotEmpty);
  });

  test('share timestamp falls back safely for unsupported locales', () {
    final label = formatEntryDetailShareTimestamp(
      createdAt: DateTime(2026, 6, 16, 9).millisecondsSinceEpoch,
      locale: const Locale('zz', 'ZZ'),
    );

    expect(label, isNotEmpty);
  });

  test('formats singular and plural word counts', () {
    expect(formatEntryWordCount(1, l10n), '1 word');
    expect(formatEntryWordCount(4, l10n), '4 words');
  });
}

Entry _entry({required String? cleanedText, required String rawTranscript}) {
  return Entry(
    id: 1,
    rawTranscript: rawTranscript,
    cleanedText: cleanedText,
    type: EntryType.saved,
    language: 'en-US',
    createdAt: DateTime(2026, 6, 16, 9).millisecondsSinceEpoch,
    wordCount: 2,
  );
}
