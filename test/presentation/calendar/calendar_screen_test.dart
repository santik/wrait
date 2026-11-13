import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/presentation/app_lock/app_lock_gate.dart';
import 'package:wrait/presentation/calendar/calendar_controller.dart';
import 'package:wrait/presentation/calendar/calendar_day_indicator.dart';
import 'package:wrait/presentation/calendar/calendar_test_keys.dart';
import 'package:wrait/presentation/entries/entry_list_row.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../../test_doubles/fake_entry_repository.dart';

void main() {
  Finder gridText(String text) => find.descendant(
    of: find.byKey(CalendarTestKeys.grid),
    matching: find.text(text),
  );

  List<Entry> novemberEntries() => [
    fakeEntry(1, DateTime(2026, 11, 11, 9)),
    fakeEntry(2, DateTime(2026, 11, 5, 9)),
    fakeEntry(3, DateTime(2026, 11, 5, 18)),
    fakeEntry(4, DateTime(2026, 10, 15, 9)),
  ];

  testWidgets('renders the grid with indicators and the month entries', (
    tester,
  ) async {
    final repo = FakeEntryRepository(novemberEntries());
    addTearDown(repo.dispose);
    await _pumpApp(tester, repo: repo, now: DateTime(2026, 11, 11, 9));

    expect(find.byKey(CalendarTestKeys.grid), findsOneWidget);
    // One marker for day 5 (two entries) and one for day 11.
    expect(find.byType(CalendarDayMarker), findsNWidgets(2));
    // Inline list defaults to the whole month: 3 November entries.
    expect(find.byType(EntryListRow), findsNWidgets(3));
  });

  testWidgets('tapping a day with entries filters the inline list', (
    tester,
  ) async {
    final repo = FakeEntryRepository(novemberEntries());
    addTearDown(repo.dispose);
    await _pumpApp(tester, repo: repo, now: DateTime(2026, 11, 11, 9));

    await tester.tap(gridText('5'));
    await tester.pumpAndSettle();

    expect(find.byType(EntryListRow), findsNWidgets(2));
  });

  testWidgets('tapping an empty day is a no-op (D4)', (tester) async {
    final repo = FakeEntryRepository(novemberEntries());
    addTearDown(repo.dispose);
    await _pumpApp(tester, repo: repo, now: DateTime(2026, 11, 11, 9));

    await tester.tap(gridText('1'));
    await tester.pumpAndSettle();

    // Still showing the whole month.
    expect(find.byType(EntryListRow), findsNWidgets(3));
  });

  testWidgets('previous month shows Today, which returns to this month', (
    tester,
  ) async {
    final repo = FakeEntryRepository(novemberEntries());
    addTearDown(repo.dispose);
    await _pumpApp(tester, repo: repo, now: DateTime(2026, 11, 11, 9));

    expect(find.byKey(CalendarTestKeys.today), findsNothing);

    await tester.tap(find.byKey(CalendarTestKeys.previousMonth));
    await tester.pumpAndSettle();

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.byKey(CalendarTestKeys.today), findsOneWidget);
    expect(find.byType(EntryListRow), findsNWidgets(1));

    await tester.tap(find.byKey(CalendarTestKeys.today));
    await tester.pumpAndSettle();

    expect(find.byKey(CalendarTestKeys.today), findsNothing);
    expect(find.byType(EntryListRow), findsNWidgets(3));
  });

  testWidgets('back returns to the entry list', (tester) async {
    final repo = FakeEntryRepository([fakeEntry(1, DateTime(2026, 11, 11, 9))]);
    addTearDown(repo.dispose);
    await _pumpApp(
      tester,
      repo: repo,
      now: DateTime(2026, 11, 11, 9),
      initialLocation: '/entries',
    );

    await tester.tap(find.byKey(const ValueKey('entryListCalendarButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(CalendarTestKeys.grid), findsOneWidget);

    await tester.tap(find.byKey(CalendarTestKeys.back));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
  });

  testWidgets('tapping an inline entry opens the entry detail', (tester) async {
    final repo = FakeEntryRepository([fakeEntry(1, DateTime(2026, 11, 11, 9))]);
    addTearDown(repo.dispose);
    await _pumpApp(tester, repo: repo, now: DateTime(2026, 11, 11, 9));

    await tester.tap(find.byType(EntryListRow).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
  });

  testWidgets('calendar is rendered behind the app lock gate', (tester) async {
    final repo = FakeEntryRepository([fakeEntry(1, DateTime(2026, 11, 11, 9))]);
    addTearDown(repo.dispose);
    await _pumpApp(tester, repo: repo, now: DateTime(2026, 11, 11, 9));

    expect(
      find.ancestor(
        of: find.byKey(CalendarTestKeys.grid),
        matching: find.byType(AppLockGate),
      ),
      findsOneWidget,
    );
  });

  testWidgets('indicators update when an entry is added (F4)', (tester) async {
    final repo = FakeEntryRepository([fakeEntry(1, DateTime(2026, 11, 11, 9))]);
    addTearDown(repo.dispose);
    await _pumpApp(tester, repo: repo, now: DateTime(2026, 11, 11, 9));

    expect(find.byType(CalendarDayMarker), findsNWidgets(1));
    expect(find.byType(EntryListRow), findsNWidgets(1));

    repo.emit([
      fakeEntry(1, DateTime(2026, 11, 11, 9)),
      fakeEntry(2, DateTime(2026, 11, 8, 9)),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(CalendarDayMarker), findsNWidgets(2));
    expect(find.byType(EntryListRow), findsNWidgets(2));
  });

  testWidgets('reopening shows the current month, not the last viewed (P1-1)', (
    tester,
  ) async {
    final repo = FakeEntryRepository(novemberEntries());
    addTearDown(repo.dispose);
    await _pumpApp(
      tester,
      repo: repo,
      now: DateTime(2026, 11, 11, 9),
      initialLocation: '/entries',
    );

    Future<void> openCalendar() async {
      await tester.tap(find.byKey(const ValueKey('entryListCalendarButton')));
      await tester.pumpAndSettle();
    }

    await openCalendar();
    expect(find.text('November 2026'), findsOneWidget);

    // Navigate away to a different month, then leave the calendar entirely.
    await tester.tap(find.byKey(CalendarTestKeys.previousMonth));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    await tester.tap(find.byKey(CalendarTestKeys.back));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);

    // Reopening resets to the current month (no stale state).
    await openCalendar();
    expect(find.text('November 2026'), findsOneWidget);
  });

  testWidgets('shows an error state when the entry stream fails (P2-1)', (
    tester,
  ) async {
    final repo = _ErroringEntryRepository();
    addTearDown(repo.dispose);
    await _pumpApp(tester, repo: repo, now: DateTime(2026, 11, 11, 9));

    expect(find.byKey(CalendarTestKeys.loadError), findsOneWidget);
    expect(find.byKey(CalendarTestKeys.grid), findsNothing);
  });

  testWidgets('deleting the selected day\'s last entry returns to month (P2-2)', (
    tester,
  ) async {
    final repo = FakeEntryRepository([
      fakeEntry(1, DateTime(2026, 11, 11, 9)),
      fakeEntry(2, DateTime(2026, 11, 5, 9)),
    ]);
    addTearDown(repo.dispose);
    await _pumpApp(tester, repo: repo, now: DateTime(2026, 11, 11, 9));

    await tester.tap(gridText('11'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryListRow), findsNWidgets(1));

    // The selected day's only entry is removed.
    repo.emit([fakeEntry(2, DateTime(2026, 11, 5, 9))]);
    await tester.pumpAndSettle();

    // Selection is cleared: the month view shows the remaining entry, and the
    // "no entries this month" copy is not shown.
    expect(find.byKey(CalendarTestKeys.emptyMonth), findsNothing);
    expect(find.byType(EntryListRow), findsNWidgets(1));
  });

  testWidgets('day markers expose an entry-count semantics label (P2-4)', (
    tester,
  ) async {
    final repo = FakeEntryRepository(novemberEntries());
    addTearDown(repo.dispose);
    await _pumpApp(tester, repo: repo, now: DateTime(2026, 11, 11, 9));

    final markers = tester
        .widgetList<CalendarDayMarker>(find.byType(CalendarDayMarker))
        .toList();
    // Day 5 has two entries, day 11 has one.
    expect(markers.any((m) => m.semanticsLabel == '2 entries'), isTrue);
    expect(markers.any((m) => m.semanticsLabel == '1 entry'), isTrue);
  });

  testWidgets('a draft-only day carries the draft flag to its marker (P1-3)', (
    tester,
  ) async {
    final repo = FakeEntryRepository([
      fakeEntry(1, DateTime(2026, 11, 11, 9), type: EntryType.draft),
      fakeEntry(2, DateTime(2026, 11, 5, 9)),
    ]);
    addTearDown(repo.dispose);
    await _pumpApp(tester, repo: repo, now: DateTime(2026, 11, 11, 9));

    final markers = tester
        .widgetList<CalendarDayMarker>(find.byType(CalendarDayMarker))
        .toList();
    expect(markers.any((m) => m.indicator.draftOnly), isTrue);
    expect(markers.any((m) => !m.indicator.draftOnly), isTrue);
  });

  testWidgets('next-month is disabled on the current month (P1-3)', (
    tester,
  ) async {
    final repo = FakeEntryRepository(novemberEntries());
    addTearDown(repo.dispose);
    await _pumpApp(tester, repo: repo, now: DateTime(2026, 11, 11, 9));

    final next = tester.widget<IconButton>(
      find.byKey(CalendarTestKeys.nextMonth),
    );
    expect(next.onPressed, isNull);

    await tester.tap(find.byKey(CalendarTestKeys.previousMonth));
    await tester.pumpAndSettle();
    final nextAfter = tester.widget<IconButton>(
      find.byKey(CalendarTestKeys.nextMonth),
    );
    expect(nextAfter.onPressed, isNotNull);
  });

  testWidgets('deleting an entry updates indicators (P1-3)', (tester) async {
    final repo = FakeEntryRepository([
      fakeEntry(1, DateTime(2026, 11, 11, 9)),
      fakeEntry(2, DateTime(2026, 11, 5, 9)),
    ]);
    addTearDown(repo.dispose);
    await _pumpApp(tester, repo: repo, now: DateTime(2026, 11, 11, 9));
    expect(find.byType(CalendarDayMarker), findsNWidgets(2));

    await repo.deleteEntry(1);
    await tester.pumpAndSettle();

    expect(find.byType(CalendarDayMarker), findsNWidgets(1));
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakeEntryRepository repo,
  required DateTime now,
  String initialLocation = '/calendar',
}) async {
  // Use a phone-sized surface (taller than the 800x600 default) so the fixed
  // six-row grid leaves room for the inline list to build its rows.
  tester.view.physicalSize = const Size(420, 950);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues(const <String, Object>{});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            backendUrl: 'https://wrait-backend.vercel.app',
            proxySecret: '',
            recordingHardCapMs: 120000,
          ),
        ),
        appRouterProvider.overrideWithValue(
          buildAppRouter(initialLocation: initialLocation),
        ),
        appLockEnabledProvider.overrideWithValue(false),
        preferencesRepositoryProvider.overrideWithValue(
          const _TestPreferencesRepository(),
        ),
        entryRepositoryProvider.overrideWithValue(repo),
        mainRecordingControllerProvider.overrideWith(
          _TestMainRecordingController.new,
        ),
        calendarClockProvider.overrideWithValue(() => now),
      ],
      child: const WraitApp(),
    ),
  );

  await tester.pumpAndSettle();
}

class _TestMainRecordingController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();

  @override
  Future<void> onMainButtonTapped() async {}
}

class _TestPreferencesRepository implements PreferencesRepository {
  const _TestPreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => true;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}

/// Repository whose entry stream fails, to exercise the calendar error state.
class _ErroringEntryRepository extends FakeEntryRepository {
  @override
  Stream<List<Entry>> watchAllEntries() async* {
    throw Exception('entry stream failed');
  }
}
