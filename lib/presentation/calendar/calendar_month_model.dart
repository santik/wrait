import 'package:table_calendar/table_calendar.dart' show StartingDayOfWeek;

import '../../domain/model/entry.dart';

/// Immutable per-day indicator derived from the entry list for a month.
class CalendarDayIndicator {
  const CalendarDayIndicator({
    required this.entryCount,
    required this.draftOnly,
  });

  /// Number of entries recorded on the day. Always greater than zero for days
  /// that appear in an indicator map.
  final int entryCount;

  /// True when every entry on the day is a draft (no finalized entries).
  final bool draftOnly;

  @override
  bool operator ==(Object other) =>
      other is CalendarDayIndicator &&
      other.entryCount == entryCount &&
      other.draftOnly == draftOnly;

  @override
  int get hashCode => Object.hash(entryCount, draftOnly);
}

/// The local calendar day (midnight, device-local time zone) an entry falls on.
///
/// Uses the device's current local time zone so an entry always lands on the
/// day the user experienced, regardless of the stored timestamp's zone.
DateTime calendarDayForEntry(Entry entry) =>
    dateOnly(DateTime.fromMillisecondsSinceEpoch(entry.createdAt).toLocal());

/// Strips the time-of-day, keeping the local calendar day.
DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

/// The first day (midnight) of the month that contains [day].
DateTime calendarMonthStart(DateTime day) => DateTime(day.year, day.month);

/// Clamps [month] to the inclusive first-of-month range
/// `[firstMonth, lastMonth]`. Keeps the displayed month reachable even after
/// the entry-derived bounds shift (e.g. the earliest entry is deleted).
DateTime clampMonth(DateTime month, DateTime firstMonth, DateTime lastMonth) {
  final value = calendarMonthStart(month);
  final lower = calendarMonthStart(firstMonth);
  final upper = calendarMonthStart(lastMonth);
  if (value.isBefore(lower)) {
    return lower;
  }
  if (value.isAfter(upper)) {
    return upper;
  }
  return value;
}

/// Buckets [entries] by their local calendar day in a single pass, preserving
/// each day's input order (newest-first when the source list is newest-first).
Map<DateTime, List<Entry>> entriesByDay(List<Entry> entries) {
  final byDay = <DateTime, List<Entry>>{};
  for (final entry in entries) {
    byDay.putIfAbsent(calendarDayForEntry(entry), () => <Entry>[]).add(entry);
  }
  return byDay;
}

/// Per-day indicator map for [month] from pre-bucketed day entries (see
/// [entriesByDay]). Days outside [month] or without entries are absent.
Map<DateTime, CalendarDayIndicator> indicatorsFromBuckets(
  Map<DateTime, List<Entry>> byDay,
  DateTime month,
) {
  final result = <DateTime, CalendarDayIndicator>{};
  byDay.forEach((day, dayEntries) {
    if (!_isSameMonth(day, month)) {
      return;
    }
    final draftOnly = dayEntries.every((entry) => entry.type == EntryType.draft);
    result[day] = CalendarDayIndicator(
      entryCount: dayEntries.length,
      draftOnly: draftOnly,
    );
  });
  return result;
}

/// All entries of [month] from pre-bucketed day entries, newest day first and
/// preserving each day's order — matching the entry list's newest-first order.
List<Entry> monthEntriesFromBuckets(
  Map<DateTime, List<Entry>> byDay,
  DateTime month,
) {
  final days = byDay.keys.where((day) => _isSameMonth(day, month)).toList()
    ..sort((a, b) => b.compareTo(a));
  return <Entry>[for (final day in days) ...byDay[day]!];
}

/// The entries for [day] from pre-bucketed day entries (empty when none).
List<Entry> dayEntriesFromBuckets(
  Map<DateTime, List<Entry>> byDay,
  DateTime day,
) => byDay[dateOnly(day)] ?? const <Entry>[];

/// The first day of the earliest month that has entries, from pre-bucketed day
/// entries, or null when empty.
DateTime? earliestEntryMonthFromBuckets(Map<DateTime, List<Entry>> byDay) {
  DateTime? earliest;
  for (final day in byDay.keys) {
    if (earliest == null || day.isBefore(earliest)) {
      earliest = day;
    }
  }
  return earliest == null ? null : calendarMonthStart(earliest);
}

/// Earliest selectable day from pre-bucketed day entries (a year before the
/// earliest entry's month, or a year before [today] when empty) — see
/// [calendarFirstDay].
DateTime calendarFirstDayFromBuckets(
  Map<DateTime, List<Entry>> byDay,
  DateTime today,
) {
  final base = earliestEntryMonthFromBuckets(byDay) ?? calendarMonthStart(today);
  return DateTime(base.year - 1, base.month);
}

bool _isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// Entries whose local day falls within [month], preserving input order.
List<Entry> entriesForMonth(List<Entry> entries, DateTime month) => entries
    .where((entry) => _isSameMonth(calendarDayForEntry(entry), month))
    .toList(growable: false);

/// Entries whose local day equals [day], preserving input order.
List<Entry> entriesForDay(List<Entry> entries, DateTime day) {
  final target = dateOnly(day);
  return entries
      .where((entry) => calendarDayForEntry(entry) == target)
      .toList(growable: false);
}

/// Per-day indicator map for [month]. Days without entries are absent.
Map<DateTime, CalendarDayIndicator> indicatorsForMonth(
  List<Entry> entries,
  DateTime month,
) {
  final byDay = <DateTime, List<Entry>>{};
  for (final entry in entries) {
    final day = calendarDayForEntry(entry);
    if (!_isSameMonth(day, month)) {
      continue;
    }
    byDay.putIfAbsent(day, () => <Entry>[]).add(entry);
  }

  return byDay.map((day, dayEntries) {
    final draftOnly = dayEntries.every((entry) => entry.type == EntryType.draft);
    return MapEntry(
      day,
      CalendarDayIndicator(entryCount: dayEntries.length, draftOnly: draftOnly),
    );
  });
}

/// The first day of the earliest month that contains an entry, or null when
/// there are no entries.
DateTime? earliestEntryMonth(List<Entry> entries) {
  DateTime? earliest;
  for (final entry in entries) {
    final day = calendarDayForEntry(entry);
    if (earliest == null || day.isBefore(earliest)) {
      earliest = day;
    }
  }
  return earliest == null ? null : calendarMonthStart(earliest);
}

/// The earliest selectable day. Starts a year before the earliest entry (or a
/// year before the current month when empty) so that months before the first
/// entry remain reachable while still bounding navigation.
DateTime calendarFirstDay(List<Entry> entries, DateTime today) {
  final base = earliestEntryMonth(entries) ?? calendarMonthStart(today);
  return DateTime(base.year - 1, base.month);
}

/// The latest selectable day: the last day of the current month. Future months
/// are not navigable (D1).
DateTime calendarLastDay(DateTime today) =>
    DateTime(today.year, today.month + 1, 0);

/// Maps Flutter's [MaterialLocalizations.firstDayOfWeekIndex] (0 = Sunday … 6 =
/// Saturday) to table_calendar's [StartingDayOfWeek], so the grid's first
/// column follows the device locale (F1).
StartingDayOfWeek startingDayOfWeekFromIndex(int firstDayOfWeekIndex) {
  switch (firstDayOfWeekIndex % 7) {
    case 0:
      return StartingDayOfWeek.sunday;
    case 1:
      return StartingDayOfWeek.monday;
    case 2:
      return StartingDayOfWeek.tuesday;
    case 3:
      return StartingDayOfWeek.wednesday;
    case 4:
      return StartingDayOfWeek.thursday;
    case 5:
      return StartingDayOfWeek.friday;
    case 6:
      return StartingDayOfWeek.saturday;
    default:
      return StartingDayOfWeek.monday;
  }
}
