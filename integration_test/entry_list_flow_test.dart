import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
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
import 'package:wrait/data/entries/entry_export_file_writer.dart';
import 'package:wrait/data/entries/entry_export_providers.dart';
import 'package:wrait/data/entries/entry_import_file_reader.dart';
import 'package:wrait/data/entries/entry_import_providers.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/domain/service/entry_export_service.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/main_screen_test_keys.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../test/test_doubles/fake_secure_storage.dart';
import 'support/managed_audio_files.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('shows the empty state on the entry list route', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-list-empty');

    expect(find.text('no entries yet'), findsOneWidget);
  });

  testWidgets('shows finalized and draft entries newest first', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    await repository.saveEntry('older final entry', 'en-US');
    harness.entryClock.advance(const Duration(days: 1));
    await repository.saveDraft('newer draft entry', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-list-populated');

    final firstRowTop = tester
        .getTopLeft(find.byKey(const ValueKey('entryRow-2')))
        .dy;
    final secondRowTop = tester
        .getTopLeft(find.byKey(const ValueKey('entryRow-1')))
        .dy;

    expect(firstRowTop, lessThan(secondRowTop));
    expect(find.text('draft'), findsOneWidget);
    expect(find.text('English'), findsNWidgets(2));
  });

  testWidgets(
    'filters persisted entries and preserves export scope while searching',
    (tester) async {
      final exportWriter = _CapturingExportFileWriter();
      final harness = await _createHarness(exportWriter: exportWriter);
      addTearDown(harness.dispose);

      final repository = harness.container.read(entryRepositoryProvider);
      final matchingId = await repository.saveEntry(
        'Monday planning session',
        'en-US',
      );
      await repository.updateEditedCleanedText(matchingId, 'Project agenda');
      harness.entryClock.advance(const Duration(days: 1));
      final otherId = await repository.saveEntry('unrelated record', 'en-US');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('entryListSearchField')),
        ' PROJECT\n monday ',
      );
      await tester.pumpAndSettle();
      await _prepareScreenshots(binding, tester);
      await binding.takeScreenshot('entry-list-search-match');

      expect(find.byKey(ValueKey('entryRow-$matchingId')), findsOneWidget);
      expect(find.byKey(ValueKey('entryRow-$otherId')), findsNothing);

      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.focusNode.hasFocus, isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(editableText.focusNode.hasFocus, isFalse);
      expect(find.byKey(ValueKey('entryRow-$matchingId')), findsOneWidget);
      expect(find.byKey(ValueKey('entryRow-$otherId')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('entryListExportButton')));
      await tester.pumpAndSettle();

      expect(exportWriter.contents, contains('Monday planning session'));
      expect(exportWriter.contents, contains('unrelated record'));

      await tester.tap(find.byKey(ValueKey('entryCard-$matchingId')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('entryDetailBackButton')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('entryListSearchField')),
            )
            .controller
            ?.text,
        ' PROJECT monday ',
      );
      expect(find.byKey(ValueKey('entryRow-$matchingId')), findsOneWidget);
      expect(find.byKey(ValueKey('entryRow-$otherId')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('entryListSearchField')),
        'project',
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(ValueKey('entryCard-$matchingId')),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('entryDeleteConfirmButton')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('entryListNoSearchResults')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('entryListNoResultsClearButton')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('entryRow-$otherId')), findsOneWidget);
    },
  );

  testWidgets('row tap navigates to the detail route', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final id = await repository.saveEntry('entry to open', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('entryCard-$id')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(find.text('entry to open'), findsOneWidget);
  });

  testWidgets('audio-only draft stays on the list when tapped', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final audioFile = await harness.writeManagedAudioFile('pending.m4a');
    final id = await repository.saveAudioDraft(audioFile.path, 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-list-audio-draft');

    expect(find.text('pending · will retry'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('entryCard-$id')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsNothing);
  });

  testWidgets('cancel keeps the row after swipe-to-delete', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final id = await repository.saveEntry('entry to keep', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(ValueKey('entryCard-$id'));
    final initialLeft = tester.getTopLeft(cardFinder).dx;

    await tester.drag(cardFinder, const Offset(120, 0));
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-list-delete-prompt-cancel');
    await tester.tap(find.byKey(const ValueKey('entryDeleteCancelButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('entryRow-$id')), findsOneWidget);
    expect(tester.getTopLeft(cardFinder).dx, initialLeft);
  });

  testWidgets('audio-only draft can be deleted from the list', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final audioFile = await harness.writeManagedAudioFile('pending-delete.m4a');
    final deletedId = await repository.saveAudioDraft(audioFile.path, 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(ValueKey('entryCard-$deletedId')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-list-audio-draft-delete-prompt');
    await tester.tap(find.byKey(const ValueKey('entryDeleteConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('entryRow-$deletedId')), findsNothing);
    expect(find.byKey(const ValueKey('entryListEmptyState')), findsOneWidget);
  });

  testWidgets('delete removes the row and stays on the list', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final deletedId = await repository.saveEntry('entry to delete', 'en-US');
    await repository.saveEntry('entry to keep', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(ValueKey('entryCard-$deletedId')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-list-delete-prompt-confirm');
    await tester.tap(find.byKey(const ValueKey('entryDeleteConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('entryRow-$deletedId')), findsNothing);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
  });

  testWidgets('back button returns to the main screen', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entryListBackButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(mainActionButtonKey), findsOneWidget);
  });

  testWidgets('system back returns to the main screen', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(mainActionButtonKey), findsOneWidget);
  });

  testWidgets('export writes saved and draft entries through the test writer', (
    tester,
  ) async {
    final exportWriter = _CapturingExportFileWriter();
    final harness = await _createHarness(exportWriter: exportWriter);
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    await repository.saveEntry('older final entry', 'en-US');
    harness.entryClock.advance(const Duration(days: 1));
    await repository.saveDraft('newer draft entry', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-list-export-success');

    await tester.tap(find.byKey(const ValueKey('entryListExportButton')));
    await tester.pumpAndSettle();

    expect(
      exportWriter.contents,
      startsWith(
        'type,created_at,language,word_count,raw_transcript,cleaned_text,tags\n',
      ),
    );
    expect(exportWriter.contents, contains('draft,'));
    expect(exportWriter.contents, contains('saved,'));
    expect(exportWriter.contents, isNot(contains('id,')));
    expect(exportWriter.contents, isNot(contains('created_at_epoch_ms')));
    expect(exportWriter.contents, isNot(contains('audioPath')));
    expect(find.text('Could not export entries.'), findsNothing);
  });

  testWidgets('real export writer can complete on-device', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    await repository.saveEntry('older final entry', 'en-US');
    harness.entryClock.advance(const Duration(days: 1));
    await repository.saveDraft('newer draft entry', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entryListExportButton')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
  });

  testWidgets('import adds saved and draft rows through the test reader', (
    tester,
  ) async {
    final importReader = _StaticImportFileReader(
      EntryImportFileReadResult(
        fileName: 'import.csv',
        contents: _validImportCsv(),
      ),
    );
    final harness = await _createHarness(importFileReader: importReader);
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entryListSearchField')),
      'imported',
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-list-import-success');

    await tester.tap(find.byKey(const ValueKey('entryListImportButton')));
    await tester.pumpAndSettle();

    expect(find.text('Imported 2 records from import.csv.'), findsOneWidget);
    expect(find.text('clean entry 21'), findsOneWidget);
    expect(find.text('imported draft entry'), findsOneWidget);
  });

  testWidgets('importing an empty Wrait csv keeps the list unchanged', (
    tester,
  ) async {
    final importReader = _StaticImportFileReader(
      const EntryImportFileReadResult(
        fileName: 'empty.csv',
        contents:
            'type,created_at,language,word_count,raw_transcript,cleaned_text\n',
      ),
    );
    final harness = await _createHarness(importFileReader: importReader);
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entryListImportButton')));
    await tester.pumpAndSettle();

    expect(find.text('Imported 0 records from empty.csv.'), findsOneWidget);
    expect(find.byKey(const ValueKey('entryListEmptyState')), findsOneWidget);
  });

  testWidgets('re-importing the same csv stays additive', (tester) async {
    final importReader = _StaticImportFileReader(
      EntryImportFileReadResult(
        fileName: 'repeat.csv',
        contents: _validImportCsv(),
      ),
    );
    final harness = await _createHarness(importFileReader: importReader);
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entryListImportButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entryListImportButton')));
    await tester.pumpAndSettle();

    expect(find.text('clean entry 21'), findsNWidgets(2));
    expect(find.text('imported draft entry'), findsNWidgets(2));
  });

  testWidgets('old-shape import failure leaves existing rows unchanged', (
    tester,
  ) async {
    final importReader = _StaticImportFileReader(
      EntryImportFileReadResult(
        fileName: 'legacy.csv',
        contents: _legacyImportCsv(),
      ),
    );
    final harness = await _createHarness(importFileReader: importReader);
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    await repository.saveEntry('existing entry', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entryListImportButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('Selected CSV is not a valid Wrait export.'),
      findsOneWidget,
    );
    expect(find.text('existing entry'), findsOneWidget);
    expect(find.text('clean entry 21'), findsNothing);
  });

  testWidgets('import failure leaves existing rows unchanged', (tester) async {
    final importReader = const _ThrowingImportFileReader();
    final harness = await _createHarness(importFileReader: importReader);
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    await repository.saveEntry('existing entry', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entryListImportButton')));
    await tester.pumpAndSettle();

    expect(find.text('Could not read the selected CSV file.'), findsOneWidget);
    expect(find.text('existing entry'), findsOneWidget);
    expect(find.text('clean entry 21'), findsNothing);
  });

  testWidgets('scroll position is preserved after navigating back from detail',
      (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    for (var i = 0; i < 20; i++) {
      await repository.saveEntry('entry number $i', 'en-US');
      harness.entryClock.advance(const Duration(hours: 1));
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('entryListView')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    final listScrollable = find.descendant(
      of: find.byKey(const ValueKey('entryListView')),
      matching: find.byType(Scrollable),
    );
    final offsetBefore =
        tester.state<ScrollableState>(listScrollable).position.pixels;
    expect(offsetBefore, greaterThan(0));

    final visibleEntry = find.byKey(const ValueKey('entryCard-10'));
    expect(visibleEntry, findsOneWidget);
    await tester.tap(visibleEntry);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entryDetailBackButton')));
    await tester.pumpAndSettle();

    final offsetAfter =
        tester.state<ScrollableState>(listScrollable).position.pixels;

    expect(offsetAfter, offsetBefore);
  });

  testWidgets(
      'scroll position is preserved after system back from detail',
      (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    for (var i = 0; i < 20; i++) {
      await repository.saveEntry('entry number $i', 'en-US');
      harness.entryClock.advance(const Duration(hours: 1));
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('entryListView')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    final listScrollable = find.descendant(
      of: find.byKey(const ValueKey('entryListView')),
      matching: find.byType(Scrollable),
    );
    final offsetBefore =
        tester.state<ScrollableState>(listScrollable).position.pixels;
    expect(offsetBefore, greaterThan(0));

    final visibleEntry = find.byKey(const ValueKey('entryCard-10'));
    expect(visibleEntry, findsOneWidget);
    await tester.tap(visibleEntry);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final offsetAfter =
        tester.state<ScrollableState>(listScrollable).position.pixels;

    expect(offsetAfter, offsetBefore);
  });
}

Future<void> _prepareScreenshots(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
) async {
  await binding.convertFlutterSurfaceToImage();
  await tester.pump();
}

class _Harness {
  _Harness({
    required this.container,
    required this.database,
    required this.tempDirectory,
    required this.entryClock,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory tempDirectory;
  final _MutableClock entryClock;
  final List<File> _managedAudioFiles = <File>[];

  Future<File> writeManagedAudioFile(String name) async {
    return writeManagedDraftAudioFile(
      managedFiles: _managedAudioFiles,
      name: name,
    );
  }

  Future<void> dispose() async {
    container.dispose();
    await database.close();
    await cleanupManagedDraftAudioFiles(_managedAudioFiles);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<_Harness> _createHarness({
  EntryExportFileWriter? exportWriter,
  EntryImportFileReader? importFileReader,
}) async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'wrait-entry-list-int',
  );
  final database = await LocalEntryDatabase.open(
    keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(7)),
    databaseFile: File(
      '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
    ),
  );
  final entryClock = _MutableClock(DateTime(2026, 6, 15, 9));

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
      clockProvider.overrideWithValue(entryClock),
      if (exportWriter != null)
        entryExportServiceProvider.overrideWithValue(
          EntryExportService(
            fileWriter: exportWriter,
            now: () => DateTime.fromMillisecondsSinceEpoch(
              entryClock.now(),
              isUtc: true,
            ),
          ),
        ),
      if (importFileReader != null)
        entryImportFileReaderProvider.overrideWithValue(importFileReader),
      preferencesRepositoryProvider.overrideWithValue(
        const _EntryListPreferencesRepository(),
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
    entryClock: entryClock,
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

class _EntryListPreferencesRepository implements PreferencesRepository {
  const _EntryListPreferencesRepository();

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

  void advance(Duration duration) {
    current = current.add(duration);
  }
}

class _CapturingExportFileWriter implements EntryExportFileWriter {
  String contents = '';

  @override
  Future<EntryExportFileWriteResult> writeCsvExport({
    required String fileName,
    required String contents,
  }) async {
    this.contents = contents;
    return EntryExportFileWriteResult(
      fileName: fileName,
      pathLabel: 'Test Downloads/Wrait',
    );
  }
}

class _StaticImportFileReader implements EntryImportFileReader {
  const _StaticImportFileReader(this.result);

  final EntryImportFileReadResult? result;

  @override
  Future<EntryImportFileReadResult?> pickCsvImport() async => result;
}

class _ThrowingImportFileReader implements EntryImportFileReader {
  const _ThrowingImportFileReader();

  @override
  Future<EntryImportFileReadResult?> pickCsvImport() async {
    throw const EntryImportFileReaderException('import failed');
  }
}

String _validImportCsv() {
  final createdAtMs = DateTime.utc(2026, 6, 30, 12).millisecondsSinceEpoch;
  return [
    'type,created_at,language,word_count,raw_transcript,cleaned_text',
    'saved,$createdAtMs,en-US,3,imported saved entry,clean entry 21',
    'draft,$createdAtMs,fr-FR,3,imported draft entry,',
  ].join('\n');
}

String _legacyImportCsv() {
  final createdAtMs = DateTime.utc(2026, 6, 30, 12).millisecondsSinceEpoch;
  return [
    'id,type,created_at,created_at_epoch_ms,language,word_count,raw_transcript,cleaned_text',
    '11,saved,$createdAtMs,$createdAtMs,en-US,3,imported saved entry,clean entry 21',
  ].join('\n');
}
