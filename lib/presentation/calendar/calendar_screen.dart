import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../domain/model/entry.dart';
import '../../l10n/app_localizations.dart';
import '../entries/entry_delete_confirmation.dart';
import '../entries/entry_list_controller.dart';
import '../entries/entry_list_row.dart';
import '../entries/locale_date_format.dart';
import '../theme/design_tokens.dart';
import 'calendar_controller.dart';
import 'calendar_day_indicator.dart';
import 'calendar_month_model.dart';
import 'calendar_test_keys.dart';

/// Dedicated month calendar screen reached from the entry list. Shows a grid
/// with per-day indicators and an inline list of the displayed month's entries
/// that narrows to a single day when one is selected.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reconcile the displayed month / selection whenever the shared entry list
    // changes: clamp the month into the current entry-derived bounds, and drop
    // a selection whose day no longer has entries (e.g. its last entry was just
    // deleted from the inline list).
    ref.listen<AsyncValue<List<Entry>>>(entryListEntriesProvider, (_, next) {
      final entries = next.value;
      if (entries == null) {
        return;
      }
      final controller = ref.read(calendarControllerProvider.notifier);
      final state = ref.read(calendarControllerProvider);
      final now = ref.read(calendarClockProvider)();
      final firstMonth = calendarMonthStart(calendarFirstDay(entries, now));
      final currentMonth = calendarMonthStart(now);
      final clamped = clampMonth(state.displayedMonth, firstMonth, currentMonth);
      if (clamped != state.displayedMonth) {
        controller.showMonth(clamped);
        return;
      }
      final selectedDay = state.selectedDay;
      if (selectedDay != null && entriesForDay(entries, selectedDay).isEmpty) {
        controller.clearSelection();
      }
    });

    // Wait for the shared entry list to load before building the grid: the
    // calendar's first/last day depend on the loaded entries, and
    // table_calendar fixes its page geometry from them at first build.
    final entriesAsync = ref.watch(entryListEntriesProvider);
    return Scaffold(
      body: SafeArea(
        child: entriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _buildError(context, ref),
          data: (entries) => _buildLoaded(context, ref, entries),
        ),
      ),
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    WidgetRef ref,
    List<Entry> allEntries,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);

    final state = ref.watch(calendarControllerProvider);
    final controller = ref.read(calendarControllerProvider.notifier);
    final indicators = ref.watch(calendarMonthIndicatorsProvider);
    final inlineEntries = ref.watch(calendarInlineEntriesProvider);

    final now = ref.watch(calendarClockProvider)();
    final firstDay = calendarFirstDay(allEntries, now);
    final lastDay = calendarLastDay(now);
    final currentMonth = calendarMonthStart(now);
    // Clamp to the current bounds so a stale month (e.g. after the earliest
    // entry was deleted) never drives the grid outside its navigable range.
    final displayedMonth = clampMonth(
      state.displayedMonth,
      calendarMonthStart(firstDay),
      currentMonth,
    );

    final previousMonth = DateTime(
      displayedMonth.year,
      displayedMonth.month - 1,
    );
    final nextMonth = DateTime(displayedMonth.year, displayedMonth.month + 1);
    final isCurrentMonth = displayedMonth == currentMonth;
    final canGoPrevious = !previousMonth.isBefore(calendarMonthStart(firstDay));
    final canGoNext = displayedMonth.isBefore(currentMonth);

    final monthLabel = formatWithLocaleFallback(
      locale,
      (name) => DateFormat.yMMMM(name).format(displayedMonth),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          context,
          theme: theme,
          l10n: l10n,
          monthLabel: monthLabel,
          isCurrentMonth: isCurrentMonth,
          canGoPrevious: canGoPrevious,
          canGoNext: canGoNext,
          onPrevious: () => controller.showMonth(previousMonth),
          onNext: () => controller.showMonth(nextMonth),
          onToday: controller.goToToday,
        ),
        Padding(
          key: CalendarTestKeys.grid,
          padding: const EdgeInsets.only(
            left: WraitSpacingTokens.sm,
            right: WraitSpacingTokens.sm,
            bottom: WraitSpacingTokens.md,
          ),
          child: TableCalendar<Object?>(
            // Re-key when the navigable range changes so table_calendar
            // re-derives its page geometry from the new first day.
            key: ValueKey('calendar-${firstDay.millisecondsSinceEpoch}'),
            locale: locale.toString(),
            firstDay: firstDay,
            lastDay: lastDay,
            focusedDay: displayedMonth,
            headerVisible: false,
            calendarFormat: CalendarFormat.month,
            // Always render six week-rows so the grid keeps a fixed height as
            // months vary between 4, 5 and 6 rows (no layout jump on paging).
            sixWeekMonthsEnforced: true,
            availableGestures: AvailableGestures.horizontalSwipe,
            startingDayOfWeek: startingDayOfWeekFromIndex(
              MaterialLocalizations.of(context).firstDayOfWeekIndex,
            ),
            selectedDayPredicate: (day) =>
                state.selectedDay != null && isSameDay(state.selectedDay, day),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              isTodayHighlighted: true,
              todayDecoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.primary),
              ),
              todayTextStyle: TextStyle(color: theme.colorScheme.primary),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(color: theme.colorScheme.onPrimary),
            ),
            calendarBuilders: CalendarBuilders<Object?>(
              markerBuilder: (context, day, events) {
                final indicator = indicators[dateOnly(day)];
                if (indicator == null) {
                  return null;
                }
                return Padding(
                  padding: const EdgeInsets.only(top: kCalendarMarkerReserve),
                  child: CalendarDayMarker(
                    indicator: indicator,
                    semanticsLabel: l10n.tagsEntryCount(indicator.entryCount),
                  ),
                );
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              final hasEntries =
                  (indicators[dateOnly(selectedDay)]?.entryCount ?? 0) > 0;
              if (hasEntries) {
                controller.toggleDay(selectedDay);
              }
              // Tapping an empty day is a no-op (D4).
            },
            onPageChanged: controller.showMonth,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildInlineEntries(
            context,
            ref,
            theme: theme,
            l10n: l10n,
            entries: inlineEntries,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required ThemeData theme,
    required AppLocalizations l10n,
    required String monthLabel,
    required bool isCurrentMonth,
    required bool canGoPrevious,
    required bool canGoNext,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    required VoidCallback onToday,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        top: WraitSpacingTokens.sm,
        left: WraitSpacingTokens.xs,
        right: WraitSpacingTokens.xs,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l10n.calendarBackSemanticsLabel,
            child: IconButton(
              key: CalendarTestKeys.back,
              onPressed: () => _navigateBack(context),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: l10n.calendarBackSemanticsLabel,
            ),
          ),
          Expanded(
            child: Text(
              monthLabel,
              key: CalendarTestKeys.monthTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Semantics(
            button: true,
            enabled: canGoPrevious,
            label: l10n.calendarPreviousMonthSemanticsLabel,
            child: IconButton(
              key: CalendarTestKeys.previousMonth,
              onPressed: canGoPrevious ? onPrevious : null,
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: l10n.calendarPreviousMonthSemanticsLabel,
            ),
          ),
          // "Today" sits between the month arrows; hidden on the current month.
          if (!isCurrentMonth)
            TextButton(
              key: CalendarTestKeys.today,
              onPressed: onToday,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: WraitSpacingTokens.xs,
                ),
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l10n.calendarToday),
            ),
          Semantics(
            button: true,
            enabled: canGoNext,
            label: l10n.calendarNextMonthSemanticsLabel,
            child: IconButton(
              key: CalendarTestKeys.nextMonth,
              onPressed: canGoNext ? onNext : null,
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: l10n.calendarNextMonthSemanticsLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineEntries(
    BuildContext context,
    WidgetRef ref, {
    required ThemeData theme,
    required AppLocalizations l10n,
    required List<Entry> entries,
  }) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          l10n.calendarMonthEmpty,
          key: CalendarTestKeys.emptyMonth,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.secondary,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      key: CalendarTestKeys.inlineList,
      padding: const EdgeInsets.all(WraitSpacingTokens.lg),
      itemCount: entries.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: WraitSpacingTokens.sm),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return EntryListRow(
          key: ValueKey('calendarEntryRow-${entry.id}'),
          entry: entry,
          onTap: (entryId) => context.push('/entry/$entryId'),
          onDeleteRequested: (entryId) => _confirmDelete(context, ref, entryId),
        );
      },
    );
  }

  /// Shown when the shared entry stream errors: the back control plus an error
  /// message with retry, rather than a calendar that falsely reads as empty.
  Widget _buildError(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(
              top: WraitSpacingTokens.sm,
              left: WraitSpacingTokens.xs,
            ),
            child: Semantics(
              button: true,
              label: l10n.calendarBackSemanticsLabel,
              child: IconButton(
                key: CalendarTestKeys.back,
                onPressed: () => _navigateBack(context),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: l10n.calendarBackSemanticsLabel,
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(WraitSpacingTokens.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.calendarLoadError,
                    key: CalendarTestKeys.loadError,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: WraitSpacingTokens.sm),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(entryListEntriesProvider),
                    child: Text(l10n.bootstrapRetryButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/entries');
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int entryId,
  ) async {
    final shouldDelete = await showEntryDeleteConfirmationDialog(context);
    if (!shouldDelete) {
      return;
    }
    await ref.read(entryListControllerProvider.notifier).deleteEntry(entryId);
  }
}
