import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/l10n/app_localizations.dart';
import 'package:wrait/presentation/entries/entry_list_formatters.dart';

import '../../test_doubles/l10n_test_helper.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    await initializeDateFormatting('en_US');
    await initializeDateFormatting('nl_NL');
    l10n = testL10n();
  });

  test('uses the first line of cleaned text when available', () {
    const entry = Entry(
      id: 1,
      rawTranscript: 'raw line one\nraw line two',
      cleanedText: 'clean line one\nclean line two',
      type: EntryType.saved,
      language: 'en-US',
      createdAt: 0,
      wordCount: 4,
    );

    expect(entryListPreviewText(entry, l10n), 'clean line one');
  });

  test('falls back to the first line of raw transcript', () {
    const entry = Entry(
      id: 1,
      rawTranscript: 'raw line one\nraw line two',
      cleanedText: null,
      type: EntryType.saved,
      language: 'en-US',
      createdAt: 0,
      wordCount: 4,
    );

    expect(entryListPreviewText(entry, l10n), 'raw line one');
  });

  test('returns an empty preview for audio-only drafts', () {
    const entry = Entry(
      id: 1,
      rawTranscript: '',
      cleanedText: null,
      type: EntryType.draft,
      language: 'en-US',
      createdAt: 0,
      wordCount: 0,
      audioPath: '/tmp/audio.m4a',
    );

    expect(entryListPreviewText(entry, l10n), l10n.entryListAudioDraftPreview);
    expect(entryListIsAudioOnlyDraft(entry), isTrue);
  });

  test('returns the first non-blank line when text starts with whitespace', () {
    const entry = Entry(
      id: 1,
      rawTranscript: '\n\nraw line one\nraw line two',
      cleanedText: null,
      type: EntryType.saved,
      language: 'en-US',
      createdAt: 0,
      wordCount: 4,
    );

    expect(entryListPreviewText(entry, l10n), 'raw line one');
  });

  test(
    'resolves supported language display names and falls back to raw code',
    () {
      expect(entryListLanguageLabel('fr'), 'Français');
      expect(entryListLanguageLabel('ru'), 'Русский');
      expect(entryListLanguageLabel('fr-FR'), 'Français');
      expect(entryListLanguageLabel('zz-ZZ'), 'zz-ZZ');
    },
  );

  test('builds locale-aware short weekday, date, and time labels', () {
    final createdAt = DateTime(2026, 6, 15, 21, 5).millisecondsSinceEpoch;

    final english = formatEntryListTimestamp(
      createdAt: createdAt,
      locale: const Locale('en', 'US'),
    );
    final dutch = formatEntryListTimestamp(
      createdAt: createdAt,
      locale: const Locale('nl', 'NL'),
    );

    expect(english.shortWeekday, isNotEmpty);
    expect(english.date, isNotEmpty);
    expect(english.time, isNotEmpty);
    expect(english.displayLabel, contains(english.shortWeekday));
    expect(english.displayLabel, contains(english.date));
    expect(english.displayLabel, contains(english.time));
    expect(dutch.displayLabel, isNot(equals(english.displayLabel)));
  });

  test('falls back to default formatting for unsupported locales', () {
    final createdAt = DateTime(2026, 6, 15, 21, 5).millisecondsSinceEpoch;

    final label = formatEntryListTimestamp(
      createdAt: createdAt,
      locale: const Locale('zz', 'ZZ'),
    );

    expect(label.shortWeekday, isNotEmpty);
    expect(label.date, isNotEmpty);
    expect(label.time, isNotEmpty);
  });
}
