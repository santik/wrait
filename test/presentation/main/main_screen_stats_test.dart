import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/l10n/app_localizations.dart';
import 'package:wrait/presentation/main/main_screen_stats.dart';

import '../../test_doubles/l10n_test_helper.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() {
    l10n = testL10n();
  });

  test('formats zero entries with zero active days', () {
    final stats = buildMainScreenStats(const <Entry>[]);

    expect(stats.entryCount, 0);
    expect(stats.activeDays, 0);
    expect(stats.displayText(l10n), '0 entries - 0 days');
  });

  test('uses singular wording for singular values', () {
    final stats = buildMainScreenStats([
      Entry(
        id: 1,
        rawTranscript: 'hello',
        type: EntryType.saved,
        language: 'en-US',
        createdAt: DateTime(2026, 6, 13, 9).millisecondsSinceEpoch,
        wordCount: 1,
      ),
    ]);

    expect(stats.displayText(l10n), '1 entry - 1 day');
  });

  test('includes draft and finalized entries in the count', () {
    final entries = [
      Entry(
        id: 1,
        rawTranscript: 'draft',
        type: EntryType.draft,
        language: 'en-US',
        createdAt: DateTime(2026, 6, 13, 9).millisecondsSinceEpoch,
        wordCount: 1,
      ),
      Entry(
        id: 2,
        rawTranscript: 'final',
        type: EntryType.saved,
        language: 'en-US',
        createdAt: DateTime(2026, 6, 13, 10).millisecondsSinceEpoch,
        wordCount: 1,
      ),
    ];

    final stats = buildMainScreenStats(entries);
    expect(stats.entryCount, 2);
  });

  test('counts unique local calendar dates', () {
    final stats = buildMainScreenStats([
      Entry(
        id: 1,
        rawTranscript: 'one',
        type: EntryType.saved,
        language: 'en-US',
        createdAt: DateTime(2026, 6, 13, 9).millisecondsSinceEpoch,
        wordCount: 1,
      ),
      Entry(
        id: 2,
        rawTranscript: 'two',
        type: EntryType.draft,
        language: 'en-US',
        createdAt: DateTime(2026, 6, 13, 22).millisecondsSinceEpoch,
        wordCount: 1,
      ),
      Entry(
        id: 3,
        rawTranscript: 'three',
        type: EntryType.saved,
        language: 'en-US',
        createdAt: DateTime(2026, 6, 14, 8).millisecondsSinceEpoch,
        wordCount: 1,
      ),
    ]);

    expect(stats.activeDays, 2);
    expect(stats.displayText(l10n), '3 entries - 2 days');
  });

  test('uses correct plural forms in English', () {
    expect(l10n.statsEntryCount(1), '1 entry');
    expect(l10n.statsEntryCount(2), '2 entries');
    expect(l10n.statsActiveDays(1), '1 day');
    expect(l10n.statsActiveDays(5), '5 days');
  });

  test('uses correct plural forms in Russian', () {
    final ru = lookupAppLocalizations(const Locale('ru'));

    expect(ru.statsEntryCount(1), '1 запись');
    expect(ru.statsEntryCount(2), '2 записи');
    expect(ru.statsEntryCount(5), '5 записей');
    expect(ru.statsEntryCount(21), '21 запись');
    expect(ru.statsEntryCount(11), '11 записей');
    expect(ru.statsActiveDays(1), '1 день');
    expect(ru.statsActiveDays(3), '3 дня');
    expect(ru.statsActiveDays(5), '5 дней');
    expect(
      ru.statsDisplay(ru.statsEntryCount(1), ru.statsActiveDays(2)),
      '1 запись - 2 дня',
    );
  });
}
