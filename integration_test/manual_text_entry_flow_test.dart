import 'dart:io';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../test/test_doubles/fake_secure_storage.dart';
import 'support/microphone_test_overrides.dart';
import 'support/screenshot_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('add button creates and persists a typed entry', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Start a manual entry from the entries list.
    await tester.tap(find.byKey(const ValueKey('entryListAddButton')));
    await tester.pumpAndSettle();

    // The detail screen opens directly in edit mode on a blank entry.
    final editor = find.byKey(const ValueKey('entryDetailEditor'));
    expect(editor, findsOneWidget);

    await tester.enterText(editor, 'typed integration entry');
    await tester.pumpAndSettle();
    await prepareScreenshots(binding, tester);
    await binding.takeScreenshot('manual-entry-compose');

    // Returning to the list persists the typed entry as a real entry.
    await tester.tap(find.byKey(const ValueKey('entryDetailBackButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    expect(find.text('typed integration entry'), findsOneWidget);

    // It persists in the database as a saved, audio-less entry.
    final repository = harness.container.read(entryRepositoryProvider);
    final entries = await repository.watchAllEntries().first;
    expect(entries, hasLength(1));
    expect(entries.single.displayText, 'typed integration entry');
    expect(entries.single.audioPath, isNull);
  });

  testWidgets('leaving a new entry empty leaves no entry behind', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entryListAddButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entryDetailEditor')), findsOneWidget);

    // Back out without typing anything.
    await tester.tap(find.byKey(const ValueKey('entryDetailBackButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryListEmptyState')), findsOneWidget);

    final repository = harness.container.read(entryRepositoryProvider);
    final entries = await repository.watchAllEntries().first;
    expect(entries, isEmpty);
  });
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

  Future<void> dispose() async {
    container.dispose();
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<_Harness> _createHarness() async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'wrait-manual-entry-int',
  );
  final database = await LocalEntryDatabase.open(
    keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(7)),
    databaseFile: File(
      '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
    ),
  );

  final container = ProviderContainer(
    overrides: [
      ...grantedMicrophoneOverrides,
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
      clockProvider.overrideWithValue(const SystemClock()),
      preferencesRepositoryProvider.overrideWithValue(
        const _ManualEntryPreferencesRepository(),
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

class _ManualEntryPreferencesRepository implements PreferencesRepository {
  const _ManualEntryPreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => true;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}
