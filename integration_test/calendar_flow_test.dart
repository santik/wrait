import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/core/time/system_clock.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/presentation/calendar/calendar_controller.dart';
import 'package:wrait/presentation/calendar/calendar_day_indicator.dart';
import 'package:wrait/presentation/calendar/calendar_test_keys.dart';
import 'package:wrait/presentation/entries/entry_list_row.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../test/test_doubles/fake_secure_storage.dart';

// "Today" for the calendar. Entries are seeded in May and June 2026; June is
// the current month.
final DateTime _today = DateTime(2026, 6, 20, 9);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // Seeds: one May entry, one June draft (June 15), two June saved entries
  // (June 20). June is the current month.
  Future<void> seed(_Harness harness) async {
    final repository = harness.container.read(entryRepositoryProvider);
    harness.clock.current = DateTime(2026, 5, 10, 9);
    await repository.saveEntry('may entry', 'en-US');
    harness.clock.current = DateTime(2026, 6, 15, 9);
    await repository.saveDraft('june draft', 'en-US');
    harness.clock.current = DateTime(2026, 6, 20, 9);
    await repository.saveEntry('june morning', 'en-US');
    await repository.saveEntry('june evening', 'en-US');
  }

  Future<void> openCalendar(WidgetTester tester, _Harness harness) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entryListCalendarButton')));
    await tester.pumpAndSettle();
  }

  testWidgets('opens the calendar and shows the month with indicators', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);
    await seed(harness);
    await openCalendar(tester, harness);

    expect(find.byKey(CalendarTestKeys.grid), findsOneWidget);
    expect(find.text('June 2026'), findsOneWidget);
    // Indicators: June 15 (draft) and June 20 (two entries).
    expect(find.byType(CalendarDayMarker), findsNWidgets(2));
    // Inline list defaults to the whole month: three June entries.
    expect(find.byType(EntryListRow), findsNWidgets(3));
  });

  testWidgets('day selection filters, and an empty day is a no-op', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);
    await seed(harness);
    await openCalendar(tester, harness);

    // Empty day from the month view: no change.
    await tester.tap(_gridText('1'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryListRow), findsNWidgets(3));

    // Day with two entries: filters to that day.
    await tester.tap(_gridText('20'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryListRow), findsNWidgets(2));

    // Re-tapping clears back to the whole month.
    await tester.tap(_gridText('20'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryListRow), findsNWidgets(3));
  });

  testWidgets('previous month shows May, and Today returns to June', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);
    await seed(harness);
    await openCalendar(tester, harness);

    expect(find.byKey(CalendarTestKeys.today), findsNothing);

    await tester.tap(find.byKey(CalendarTestKeys.previousMonth));
    await tester.pumpAndSettle();
    expect(find.text('May 2026'), findsOneWidget);
    expect(find.byType(EntryListRow), findsNWidgets(1));
    expect(find.byKey(CalendarTestKeys.today), findsOneWidget);

    await tester.tap(find.byKey(CalendarTestKeys.today));
    await tester.pumpAndSettle();
    expect(find.text('June 2026'), findsOneWidget);
    expect(find.byType(EntryListRow), findsNWidgets(3));
    expect(find.byKey(CalendarTestKeys.today), findsNothing);
  });

  testWidgets('opening an entry returns to the same month and selection (D3)', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);
    await seed(harness);
    await openCalendar(tester, harness);

    await tester.tap(_gridText('20'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryListRow), findsNWidgets(2));

    await tester.tap(find.byType(EntryListRow).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entryDetailBackButton')));
    await tester.pumpAndSettle();

    // Back on the calendar, same month, same day still selected.
    expect(find.text('June 2026'), findsOneWidget);
    expect(find.byType(EntryListRow), findsNWidgets(2));
  });

  testWidgets('back returns to the entry list', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);
    await seed(harness);
    await openCalendar(tester, harness);

    await tester.tap(find.byKey(CalendarTestKeys.back));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
  });

  testWidgets('calendar elements are aligned', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);
    await seed(harness);
    await openCalendar(tester, harness);

    final screenWidth = tester.getSize(find.byType(Scaffold)).width;

    final back = tester.getRect(find.byKey(CalendarTestKeys.back));
    final title = tester.getRect(find.byKey(CalendarTestKeys.monthTitle));
    final previous = tester.getRect(find.byKey(CalendarTestKeys.previousMonth));
    final next = tester.getRect(find.byKey(CalendarTestKeys.nextMonth));

    // Header controls share one vertical center line. Tolerance is generous so
    // the check verifies alignment, not exact pixels (font scale / device).
    expect(title.center.dy, closeTo(back.center.dy, 6.0));
    expect(previous.center.dy, closeTo(back.center.dy, 6.0));
    expect(next.center.dy, closeTo(back.center.dy, 6.0));

    // Header controls are laid out left-to-right without overlap.
    expect(back.right, lessThanOrEqualTo(title.left));
    expect(title.right, lessThanOrEqualTo(previous.left));
    expect(previous.right, lessThanOrEqualTo(next.left));

    // Back sits in the left portion; next sits in the right portion.
    expect(back.left, lessThan(screenWidth * 0.5));
    expect(next.right, greaterThan(screenWidth * 0.5));

    // The grid has (roughly) symmetric left/right padding — centered, not
    // flush to one edge.
    final grid = tester.getRect(find.byKey(CalendarTestKeys.grid));
    expect(grid.left, closeTo(screenWidth - grid.right, 3.0));

    // The calendar table is inset symmetrically within the grid padding.
    final table = tester.getRect(find.byType(TableCalendar<Object?>));
    expect(table.left - grid.left, closeTo(grid.right - table.right, 3.0));

    // Inline entry rows share one left edge and one width.
    final rows = find.byType(EntryListRow);
    final first = tester.getRect(rows.at(0));
    final second = tester.getRect(rows.at(1));
    expect(first.left, closeTo(second.left, 1.0));
    expect(first.width, closeTo(second.width, 1.0));
  });
}

Finder _gridText(String text) => find.descendant(
  of: find.byKey(CalendarTestKeys.grid),
  matching: find.text(text),
);

class _MutableClock implements Clock {
  _MutableClock(this.current);

  DateTime current;

  @override
  int now() => current.millisecondsSinceEpoch;
}

class _Harness {
  _Harness({
    required this.container,
    required this.database,
    required this.tempDirectory,
    required this.clock,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory tempDirectory;
  final _MutableClock clock;

  Future<void> dispose() async {
    container.dispose();
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<_Harness> _createHarness() async {
  final tempDirectory = await Directory.systemTemp.createTemp('wrait-cal-int');
  final database = await LocalEntryDatabase.open(
    keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(7)),
    databaseFile: File(
      '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
    ),
  );
  final clock = _MutableClock(_today);

  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          backendUrl: 'https://wrait-backend.vercel.app',
          proxySecret: '',
          recordingHardCapMs: 120000,
        ),
      ),
      appRouterProvider.overrideWithValue(
        buildAppRouter(initialLocation: '/entries'),
      ),
      appLockEnabledProvider.overrideWithValue(false),
      localEntryDatabaseProvider.overrideWithValue(database),
      clockProvider.overrideWithValue(clock),
      calendarClockProvider.overrideWithValue(() => _today),
      preferencesRepositoryProvider.overrideWithValue(
        const _CalendarPreferencesRepository(),
      ),
      mainRecordingControllerProvider.overrideWith(
        _IdleMainRecordingController.new,
      ),
      sessionRecordQuotaStateProvider.overrideWith(_IdleQuotaNotifier.new),
    ],
  );

  return _Harness(
    container: container,
    database: database,
    tempDirectory: tempDirectory,
    clock: clock,
  );
}

class _IdleMainRecordingController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();

  @override
  Future<void> onMainButtonTapped() async {}
}

class _IdleQuotaNotifier extends SessionRecordQuotaStateNotifier {
  @override
  RecordQuotaState? build() => null;
}

class _CalendarPreferencesRepository implements PreferencesRepository {
  const _CalendarPreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => true;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}
