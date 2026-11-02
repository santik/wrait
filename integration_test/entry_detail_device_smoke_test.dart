import 'dart:io';
import 'dart:math';
import 'dart:ui' show SemanticsAction;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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
import 'package:wrait/presentation/entries/entry_detail_controller.dart';
import 'package:wrait/presentation/entries/entry_share_service.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../test/test_doubles/fake_secure_storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('auto-saves edited detail text and preserves raw transcript', (
    tester,
  ) async {
    final harness = await _createHarness(autoSaveDelay: Duration.zero);
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final id = await repository.saveEntry('original raw transcript', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    harness.go('/entry/$id');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entryDetailReadText')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.bySemanticsLabel('Edit entry text'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('entryDetailEditor')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    // Focus is the app contract. Visible IME insets also depend on hardware
    // keyboard and lockscreen state, so require them only in a controlled
    // emulator/simulator run with the software keyboard enabled.
    if (const bool.fromEnvironment('VERIFY_ENTRY_SOFTWARE_KEYBOARD')) {
      await _expectSoftwareKeyboardVisible(tester);
    }

    await tester.enterText(
      find.byKey(const ValueKey('entryDetailEditor')),
      'edited detail text on device',
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('entryDetailBackButton')));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('entryListView')),
      timeout: const Duration(seconds: 3),
    );

    final entryPreview = find.byKey(ValueKey('entryPreview-$id'));
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    expect(entryPreview, findsOneWidget);
    expect(
      tester.widget<Text>(entryPreview).data,
      'edited detail text on device',
    );

    final savedEntry = await repository.getEntryById(id);
    expect(savedEntry, isNotNull);
    expect(savedEntry!.cleanedText, 'edited detail text on device');
    expect(savedEntry.rawTranscript, 'original raw transcript');
    expect(savedEntry.wordCount, 5);
    await tester.pumpAndSettle();
    harness.go('/entry/$id');
    await tester.pumpAndSettle();
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('entryDetailReadText')),
    );
    expect(
      tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('entryDetailReadText')),
          )
          .data,
      'edited detail text on device',
    );
  });

  testWidgets('invalid detail route redirects safely to entries', (
    tester,
  ) async {
    final harness = await _createHarness(
      initialLocation: '/entry/not-a-number',
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryListEmptyState')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsNothing);
  });

  testWidgets('read selection and accessible edit preserve editor gestures', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);
    final semantics = tester.ensureSemantics();
    final repository = harness.container.read(entryRepositoryProvider);
    final id = await repository.saveEntry(
      'Selection remains available here',
      'en-US',
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    harness.go('/entry/$id');
    await tester.pumpAndSettle();
    final body = find.byKey(const ValueKey('entryDetailReadText'));
    await tester.longPressAt(tester.getTopLeft(body) + const Offset(25, 10));
    await tester.pumpAndSettle();
    expect(body, findsOneWidget);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText))
          .controller
          .selection
          .isCollapsed,
      isFalse,
    );
    final action = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.hint == 'Tap to edit entry',
    );
    final node = tester.getSemantics(action);
    expect(node.getSemanticsData().value, 'Selection remains available here');
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    final editor = find.byKey(const ValueKey('entryDetailEditor'));
    expect(tester.widget<TextField>(editor).focusNode!.hasFocus, isTrue);
    await tester.tapAt(tester.getTopLeft(editor) + const Offset(25, 15));
    await tester.pumpAndSettle();
    var selection = tester.widget<TextField>(editor).controller!.selection;
    expect(selection.isValid, isTrue);
    expect(selection.isCollapsed, isTrue);
    expect(
      selection.baseOffset,
      lessThan('Selection remains available here'.length),
    );
    final wordPosition = tester.getTopLeft(editor) + const Offset(25, 15);
    await tester.tapAt(wordPosition);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(wordPosition);
    await tester.pumpAndSettle();
    selection = tester.widget<TextField>(editor).controller!.selection;
    expect(selection.isCollapsed, isFalse);
    expect(find.byKey(const ValueKey('entryDetailDoneButton')), findsOneWidget);
    semantics.dispose();
  });
}

Future<void> _expectSoftwareKeyboardVisible(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 3),
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  assert(timeout > Duration.zero && pollInterval > Duration.zero);
  for (
    var elapsed = Duration.zero;
    elapsed < timeout && tester.view.viewInsets.bottom == 0;
    elapsed += pollInterval
  ) {
    await tester.pump(pollInterval);
  }
  expect(
    tester.view.viewInsets.bottom,
    greaterThan(0),
    reason:
        'Body tap must open the software keyboard within $timeout before text injection; run this check with the software keyboard enabled',
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 100),
  Duration timeout = const Duration(seconds: 2),
}) async {
  final iterations = timeout.inMicroseconds ~/ step.inMicroseconds;
  for (var index = 0; index < iterations; index += 1) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  expect(finder, findsOneWidget);
}

class _Harness {
  _Harness({
    required this.container,
    required this.database,
    required this.tempDirectory,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory tempDirectory;

  void go(String location) {
    container.read(appRouterProvider).go(location);
  }

  Future<void> dispose() async {
    container.dispose();
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<_Harness> _createHarness({
  String initialLocation = '/entries',
  Duration autoSaveDelay = const Duration(milliseconds: 250),
}) async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'wrait-entry-detail-device',
  );
  final database = await LocalEntryDatabase.open(
    keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(7)),
    databaseFile: File(
      '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
    ),
  );
  final shareService = _TestEntryShareService();

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
        buildAppRouter(initialLocation: initialLocation),
      ),
      appLockEnabledProvider.overrideWithValue(false),
      localEntryDatabaseProvider.overrideWithValue(database),
      clockProvider.overrideWithValue(_MutableClock(DateTime(2026, 6, 16, 9))),
      preferencesRepositoryProvider.overrideWithValue(
        const _EntryDetailPreferencesRepository(),
      ),
      mainRecordingControllerProvider.overrideWith(
        _IdleMainRecordingController.new,
      ),
      sessionRecordQuotaStateProvider.overrideWith(_IdleQuotaNotifier.new),
      entryShareServiceProvider.overrideWithValue(shareService),
      entryDetailAutoSaveDelayProvider.overrideWithValue(autoSaveDelay),
    ],
  );

  return _Harness(
    container: container,
    database: database,
    tempDirectory: tempDirectory,
  );
}

class _TestEntryShareService implements EntryShareService {
  @override
  Future<void> shareText(String text) async {}
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

class _EntryDetailPreferencesRepository implements PreferencesRepository {
  const _EntryDetailPreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => true;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}

class _MutableClock implements Clock {
  _MutableClock(this.current);

  DateTime current;

  @override
  int now() => current.millisecondsSinceEpoch;
}
