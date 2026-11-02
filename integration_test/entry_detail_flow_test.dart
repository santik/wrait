import 'dart:io';
import 'dart:math';

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
import 'package:wrait/presentation/entries/entry_detail_formatters.dart';
import 'package:wrait/presentation/entries/entry_share_service.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../test/test_doubles/fake_secure_storage.dart';
import 'support/managed_audio_files.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('opens a readable entry directly and supports long-text scroll', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final id = await repository.saveEntry(_longText(), 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    harness.go('/entry/$id');
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-detail-readable');

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.runtimeType.toString() == 'SelectableText' &&
            (widget as dynamic).data.toString().contains('line 01'),
      ),
      findsOneWidget,
    );

    final beforeScroll = tester
        .getTopLeft(find.byKey(const ValueKey('entryDetailReadText')))
        .dy;
    await tester.drag(
      find.byKey(const ValueKey('entryDetailScrollView')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('entry-detail-long-after-scroll');

    final afterScroll = tester
        .getTopLeft(find.byKey(const ValueKey('entryDetailReadText')))
        .dy;
    expect(afterScroll, lessThan(beforeScroll));
    expect(find.byKey(const ValueKey('entryDetailEditor')), findsNothing);
    for (final key in [
      'entryDetailWeekday',
      'entryDetailDate',
      'entryDetailWordCount',
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entryDetailEditor')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('entryDetailShareButton')));
    await tester.pumpAndSettle();

    expect(harness.shareService.sharedTexts, [_expectedShareText(_longText())]);
    expect(_longText().length, greaterThan(10000));
    final viewport = tester.getRect(
      find.byKey(const ValueKey('entryDetailScrollView')),
    );
    await tester.tapAt(viewport.topLeft + const Offset(25, 25));
    await tester.pumpAndSettle();
    final editor = tester.widget<TextField>(
      find.byKey(const ValueKey('entryDetailEditor')),
    );
    expect(editor.controller!.text, _longText());
    expect(editor.focusNode!.hasFocus, isTrue);
  });

  testWidgets('opens detail from an entry-list row and shares short text', (
    tester,
  ) async {
    final harness = await _createHarness(initialLocation: '/entries');
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final id = await repository.saveEntry('entry from list', 'en-US');

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
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.key == const ValueKey('entryDetailReadText') &&
            widget.data == 'entry from list',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('entryDetailShareButton')));
    await tester.pumpAndSettle();

    expect(harness.shareService.sharedTexts, [
      _expectedShareText('entry from list'),
    ]);
  });

  testWidgets(
    'shows raw transcript fallback when cleaned text is unavailable',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      final repository = harness.container.read(entryRepositoryProvider);
      final id = await repository.saveDraft('raw fallback text', 'en-US');
      await repository.updateEntryLanguage(id, 'en-US');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const WraitApp(),
        ),
      );
      harness.go('/entry/$id');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              widget.key == const ValueKey('entryDetailReadText') &&
              widget.data == 'raw fallback text',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('entryDetailShareButton')));
      await tester.pumpAndSettle();

      expect(harness.shareService.sharedTexts, [
        _expectedShareText('raw fallback text'),
      ]);
      await tester.tap(find.byKey(const ValueKey('entryDetailReadText')));
      await tester.pumpAndSettle();
      final editor = tester.widget<TextField>(
        find.byKey(const ValueKey('entryDetailEditor')),
      );
      expect(editor.controller!.text, 'raw fallback text');
      expect(editor.focusNode!.hasFocus, isTrue);
      await tester.tap(find.byKey(const ValueKey('entryDetailDoneButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    },
  );

  testWidgets('invalid and missing detail routes redirect to the entry list', (
    tester,
  ) async {
    final invalidHarness = await _createHarness(
      initialLocation: '/entry/not-a-number',
    );
    addTearDown(invalidHarness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: invalidHarness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-detail-invalid-redirect');

    expect(find.byKey(const ValueKey('entryListEmptyState')), findsOneWidget);

    final missingHarness = await _createHarness();
    addTearDown(missingHarness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: missingHarness.container,
        child: const WraitApp(),
      ),
    );
    missingHarness.go('/entry/99');
    await tester.pumpAndSettle();
    await binding.takeScreenshot('entry-detail-missing-redirect');

    expect(find.byKey(const ValueKey('entryListEmptyState')), findsOneWidget);
  });

  testWidgets('unreadable entries redirect back to the entries list', (
    tester,
  ) async {
    final harness = await _createHarness(initialLocation: '/entries');
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

    harness.go('/entry/$id');
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-detail-unreadable-redirect');

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsNothing);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    expect(find.text('pending · will retry'), findsOneWidget);
  });

  testWidgets(
    'edits auto-save, preserve raw transcript, share with timestamp, and flush on system back',
    (tester) async {
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
      harness.go('/entry/$id');
      await tester.pumpAndSettle();

      await repository.updateEditedCleanedText(id, 'initial cleaned text');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('entryDetailReadText')));
      await tester.pumpAndSettle();
      final initialEditor = tester.widget<TextField>(
        find.byKey(const ValueKey('entryDetailEditor')),
      );
      expect(initialEditor.controller!.text, 'initial cleaned text');
      expect(initialEditor.focusNode!.hasFocus, isTrue);
      await _prepareScreenshots(binding, tester);
      await binding.takeScreenshot('entry-detail-edit-mode');

      await tester.enterText(
        find.byKey(const ValueKey('entryDetailEditor')),
        'edited cleaned text for sharing',
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('entryDetailDoneButton')));
      await tester.pumpAndSettle();
      expect(
        (await repository.getEntryById(id))!.cleanedText,
        'edited cleaned text for sharing',
      );
      await tester.tap(find.byKey(const ValueKey('entryDetailEditButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('entryDetailDoneButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('entryDetailReadText')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('entryDetailShareButton')));
      await tester.pumpAndSettle();
      expect(harness.shareService.sharedTexts, [
        _expectedShareText('edited cleaned text for sharing'),
      ]);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('entry-detail-edited-back-to-list');

      final entryPreview = find.byKey(ValueKey('entryPreview-$id'));
      expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
      expect(entryPreview, findsOneWidget);
      expect(
        tester.widget<Text>(entryPreview).data,
        'edited cleaned text for sharing',
      );

      final entry = await repository.getEntryById(id);
      expect(entry, isNotNull);
      expect(entry!.cleanedText, 'edited cleaned text for sharing');
      expect(entry.rawTranscript, 'original raw transcript');
      expect(entry.wordCount, 5);
    },
  );

  testWidgets('delete cancel keeps detail open and confirm removes the entry', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final id = await repository.saveEntry('entry to delete', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    harness.go('/entry/$id');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entryDetailDeleteButton')));
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-detail-delete-confirmation');

    await tester.tap(find.byKey(const ValueKey('entryDeleteCancelButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entryDetailDeleteButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entryDeleteConfirmButton')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('entry-detail-after-delete');

    expect(find.byKey(ValueKey('entryRow-$id')), findsNothing);
    expect(find.byKey(const ValueKey('entryListEmptyState')), findsOneWidget);
    expect(await repository.getEntryById(id), isNull);

    harness.go('/entry/$id');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entryListEmptyState')), findsOneWidget);
  });
}

String _expectedShareText(String body) {
  final shareTimestamp = formatEntryDetailShareTimestamp(
    createdAt: DateTime(2026, 6, 16, 9).millisecondsSinceEpoch,
    locale: const Locale('en', 'US'),
  );
  return '$shareTimestamp$entryDetailShareSectionSeparator$body';
}

Future<void> _prepareScreenshots(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
) async {
  await binding.convertFlutterSurfaceToImage();
  await tester.pump();
}

String _longText() {
  return List<String>.generate(
    400,
    (index) =>
        'line ${index.toString().padLeft(2, '0')} preserves every word in this long journal entry.',
  ).join('\n');
}

class _Harness {
  _Harness({
    required this.container,
    required this.database,
    required this.tempDirectory,
    required this.entryClock,
    required this.shareService,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory tempDirectory;
  final _MutableClock entryClock;
  final _TestEntryShareService shareService;
  final List<File> _managedAudioFiles = <File>[];

  void go(String location) {
    container.read(appRouterProvider).go(location);
  }

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
  String initialLocation = '/entries',
  Duration autoSaveDelay = const Duration(milliseconds: 250),
}) async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'wrait-entry-detail-int',
  );
  final database = await LocalEntryDatabase.open(
    keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(7)),
    databaseFile: File(
      '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
    ),
  );
  final entryClock = _MutableClock(DateTime(2026, 6, 16, 9));
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
      clockProvider.overrideWithValue(entryClock),
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
    entryClock: entryClock,
    shareService: shareService,
  );
}

class _TestEntryShareService implements EntryShareService {
  final List<String> sharedTexts = <String>[];

  @override
  Future<void> shareText(String text) async {
    sharedTexts.add(text);
  }
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

  void advance(Duration duration) {
    current = current.add(duration);
  }
}
