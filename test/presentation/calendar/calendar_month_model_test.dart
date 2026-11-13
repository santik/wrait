import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/presentation/calendar/calendar_month_model.dart';

import '../../test_doubles/fake_entry_repository.dart';

void main() {
  group('indicatorsForMonth', () {
    test('counts entries per day; days without entries are absent', () {
      final entries = [
        fakeEntry(1, DateTime(2026, 11, 5, 9)),
        fakeEntry(2, DateTime(2026, 11, 5, 18)),
        fakeEntry(3, DateTime(2026, 11, 11, 8)),
        fakeEntry(4, DateTime(2026, 10, 15, 8)),
      ];

      final map = indicatorsForMonth(entries, DateTime(2026, 11));

      expect(map[DateTime(2026, 11, 5)]!.entryCount, 2);
      expect(map[DateTime(2026, 11, 11)]!.entryCount, 1);
      expect(map.containsKey(DateTime(2026, 11, 6)), isFalse);
      expect(map.containsKey(DateTime(2026, 10, 15)), isFalse);
    });

    test('flags draft-only days and not mixed days', () {
      final entries = [
        fakeEntry(1, DateTime(2026, 11, 5, 9), type: EntryType.draft),
        fakeEntry(2, DateTime(2026, 11, 6, 9), type: EntryType.draft),
        fakeEntry(3, DateTime(2026, 11, 6, 10)),
      ];

      final map = indicatorsForMonth(entries, DateTime(2026, 11));

      expect(map[DateTime(2026, 11, 5)]!.draftOnly, isTrue);
      expect(map[DateTime(2026, 11, 6)]!.draftOnly, isFalse);
    });
  });

  group('local-day bucketing', () {
    test('buckets a local timestamp to its local day', () {
      final entry = fakeEntry(1, DateTime(2026, 3, 15, 23, 30));
      expect(calendarDayForEntry(entry), DateTime(2026, 3, 15));
    });

    test('buckets a UTC instant to its local day', () {
      final instant = DateTime.utc(2026, 3, 15, 23, 30);
      final entry = Entry(
        id: 1,
        rawTranscript: 'x',
        type: EntryType.saved,
        language: 'en-US',
        createdAt: instant.millisecondsSinceEpoch,
        wordCount: 1,
      );
      expect(calendarDayForEntry(entry), dateOnly(instant.toLocal()));
    });
  });

  group('month bounds', () {
    test('earliestEntryMonth returns the first entry month', () {
      final entries = [
        fakeEntry(1, DateTime(2026, 10, 15)),
        fakeEntry(2, DateTime(2026, 8, 2)),
      ];
      expect(earliestEntryMonth(entries), DateTime(2026, 8));
    });

    test('calendarFirstDay starts a year before the earliest entry', () {
      final entries = [fakeEntry(1, DateTime(2026, 8, 2))];
      expect(
        calendarFirstDay(entries, DateTime(2026, 11, 11)),
        DateTime(2025, 8),
      );
    });

    test('calendarFirstDay with no entries is a year before this month', () {
      expect(
        calendarFirstDay(const <Entry>[], DateTime(2026, 11, 11)),
        DateTime(2025, 11),
      );
    });

    test('calendarLastDay is the last day of the current month (no future)', () {
      expect(calendarLastDay(DateTime(2026, 11, 11)), DateTime(2026, 11, 30));
      expect(calendarLastDay(DateTime(2026, 2, 10)), DateTime(2026, 2, 28));
    });
  });

  group('startingDayOfWeekFromIndex (F1)', () {
    test('maps the Flutter first-day index (0 = Sunday)', () {
      expect(startingDayOfWeekFromIndex(0), StartingDayOfWeek.sunday);
      expect(startingDayOfWeekFromIndex(1), StartingDayOfWeek.monday);
      expect(startingDayOfWeekFromIndex(6), StartingDayOfWeek.saturday);
    });
  });

  group('clampMonth', () {
    final first = DateTime(2025, 8);
    final last = DateTime(2026, 11);

    test('returns the month unchanged when within bounds', () {
      expect(clampMonth(DateTime(2026, 5), first, last), DateTime(2026, 5));
    });

    test('clamps a month before the lower bound up to it', () {
      expect(clampMonth(DateTime(2025, 1), first, last), first);
    });

    test('clamps a future month down to the last bound', () {
      expect(clampMonth(DateTime(2027, 3), first, last), last);
    });

    test('normalizes any day to the first of its clamped month', () {
      expect(clampMonth(DateTime(2026, 5, 19), first, last), DateTime(2026, 5));
    });
  });

  group('single-pass buckets (P3-2)', () {
    final entries = [
      fakeEntry(1, DateTime(2026, 11, 20, 18)),
      fakeEntry(2, DateTime(2026, 11, 20, 9)),
      fakeEntry(3, DateTime(2026, 11, 5, 9), type: EntryType.draft),
      fakeEntry(4, DateTime(2026, 10, 15, 9)),
    ];

    test('indicatorsFromBuckets matches indicatorsForMonth', () {
      final byDay = entriesByDay(entries);
      expect(
        indicatorsFromBuckets(byDay, DateTime(2026, 11)),
        indicatorsForMonth(entries, DateTime(2026, 11)),
      );
    });

    test('monthEntriesFromBuckets keeps newest-first order', () {
      final byDay = entriesByDay(entries);
      final ids = monthEntriesFromBuckets(
        byDay,
        DateTime(2026, 11),
      ).map((e) => e.id).toList();
      // Nov entries newest day first, newest-within-day first: 1,2 (20th) then 3 (5th).
      expect(ids, [1, 2, 3]);
    });

    test('dayEntriesFromBuckets returns a day, empty when none', () {
      final byDay = entriesByDay(entries);
      expect(
        dayEntriesFromBuckets(byDay, DateTime(2026, 11, 20)).map((e) => e.id),
        [1, 2],
      );
      expect(dayEntriesFromBuckets(byDay, DateTime(2026, 11, 1)), isEmpty);
    });
  });
}
