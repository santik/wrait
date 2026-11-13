import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/entry.dart';
import '../entries/entry_list_controller.dart';
import 'calendar_month_model.dart';

/// Returns "now"; overridable in tests for deterministic month bounds.
typedef CalendarClock = DateTime Function();

final calendarClockProvider = Provider<CalendarClock>((ref) => DateTime.now);

/// Immutable calendar screen state: the month on screen and the selected day.
class CalendarState {
  CalendarState({required DateTime displayedMonth, DateTime? selectedDay})
    : displayedMonth = calendarMonthStart(displayedMonth),
      selectedDay = selectedDay == null ? null : dateOnly(selectedDay);

  /// The first day of the month currently displayed in the grid.
  final DateTime displayedMonth;

  /// The selected day (date only), or null when the whole month is shown.
  final DateTime? selectedDay;

  @override
  bool operator ==(Object other) =>
      other is CalendarState &&
      other.displayedMonth == displayedMonth &&
      other.selectedDay == selectedDay;

  @override
  int get hashCode => Object.hash(displayedMonth, selectedDay);
}

/// Holds the displayed month and selected day for the calendar screen.
///
/// `autoDispose`, but kept alive for as long as the calendar screen is mounted.
/// While the entry detail screen is pushed on top, the calendar route stays in
/// the navigator stack and keeps watching this provider, so the month and
/// selection survive the round trip (D3). When the user leaves the calendar
/// entirely the screen unmounts, the provider disposes, and the next open
/// rebuilds on the current month with no stale selection (spec "on open, shows
/// the current month").
final calendarControllerProvider =
    NotifierProvider.autoDispose<CalendarController, CalendarState>(
      CalendarController.new,
    );

class CalendarController extends Notifier<CalendarState> {
  @override
  CalendarState build() {
    final now = ref.read(calendarClockProvider)();
    return CalendarState(displayedMonth: now);
  }

  /// Shows [month] and clears any day selection (D2).
  void showMonth(DateTime month) {
    state = CalendarState(displayedMonth: month);
  }

  /// Returns to the current month, clearing any selection.
  void goToToday() {
    final now = ref.read(calendarClockProvider)();
    state = CalendarState(displayedMonth: now);
  }

  /// Selects [day], or clears the selection when [day] is already selected
  /// (re-tap returns to the whole-month list).
  void toggleDay(DateTime day) {
    final target = dateOnly(day);
    if (state.selectedDay == target) {
      state = CalendarState(displayedMonth: state.displayedMonth);
    } else {
      state = CalendarState(
        displayedMonth: state.displayedMonth,
        selectedDay: target,
      );
    }
  }

  /// Clears any day selection, returning to the whole-month list while keeping
  /// the displayed month. Used to reconcile a selection whose day no longer has
  /// entries (e.g. the last entry of the selected day was deleted).
  void clearSelection() {
    if (state.selectedDay == null) {
      return;
    }
    state = CalendarState(displayedMonth: state.displayedMonth);
  }
}

/// The shared entry list bucketed by local calendar day, computed in a single
/// pass and reused by the indicators, inline list, and bounds so each entries
/// emission is scanned once (not once per consumer).
final calendarEntriesByDayProvider =
    Provider.autoDispose<Map<DateTime, List<Entry>>>((ref) {
      final entries =
          ref.watch(entryListEntriesProvider).value ?? const <Entry>[];
      return entriesByDay(entries);
    });

/// The displayed month clamped to the current entry-derived bounds, so a stale
/// month (e.g. after the earliest entry is deleted) never drives the grid or
/// the derived lists outside the navigable range.
DateTime _effectiveMonth(Ref ref, Map<DateTime, List<Entry>> byDay) {
  final now = ref.watch(calendarClockProvider)();
  final firstMonth = calendarMonthStart(calendarFirstDayFromBuckets(byDay, now));
  final lastMonth = calendarMonthStart(now);
  final displayedMonth = ref.watch(
    calendarControllerProvider.select((s) => s.displayedMonth),
  );
  return clampMonth(displayedMonth, firstMonth, lastMonth);
}

/// Entries shown in the inline list below the grid: the selected day's entries
/// when a day is selected, otherwise all entries for the displayed month. Order
/// follows [entryListEntriesProvider] (newest first).
final calendarInlineEntriesProvider = Provider.autoDispose<List<Entry>>((ref) {
  final byDay = ref.watch(calendarEntriesByDayProvider);
  final selectedDay = ref.watch(
    calendarControllerProvider.select((s) => s.selectedDay),
  );
  if (selectedDay != null) {
    return dayEntriesFromBuckets(byDay, selectedDay);
  }
  return monthEntriesFromBuckets(byDay, _effectiveMonth(ref, byDay));
});

/// Per-day indicators for the displayed month, recomputed reactively whenever
/// the shared entry list changes (no manual refresh — F4).
final calendarMonthIndicatorsProvider =
    Provider.autoDispose<Map<DateTime, CalendarDayIndicator>>((ref) {
      final byDay = ref.watch(calendarEntriesByDayProvider);
      return indicatorsFromBuckets(byDay, _effectiveMonth(ref, byDay));
    });
