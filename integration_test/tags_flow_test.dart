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
import 'package:wrait/data/entries/entry_export_file_writer.dart';
import 'package:wrait/data/entries/entry_export_providers.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/data/entries/tag_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/domain/service/entry_export_service.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../test/test_doubles/fake_secure_storage.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('manage tags: create, see count, delete', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    await repository.saveEntry('entry one', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to manage tags via the route directly
    harness.go('/tags');
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('tags-manage-empty');

    // Verify empty state
    expect(find.byKey(const ValueKey('manageTagsEmptyState')), findsOneWidget);

    // Create first tag
    await tester.enterText(
      find.byKey(const ValueKey('manageTagsNameField')),
      'work',
    );
    await tester.tap(find.byKey(const ValueKey('manageTagsAddButton')));
    await tester.pumpAndSettle();

    expect(find.text('work'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('manageTagsEmptyState')),
      findsNothing,
    );
    await binding.takeScreenshot('tags-manage-one-tag');

    // Create second tag
    await tester.enterText(
      find.byKey(const ValueKey('manageTagsNameField')),
      'personal',
    );
    await tester.tap(find.byKey(const ValueKey('manageTagsAddButton')));
    await tester.pumpAndSettle();

    expect(find.text('personal'), findsOneWidget);
    expect(find.text('work'), findsOneWidget);

    // Delete the second tag (confirm)
    await tester.tap(find.byKey(const ValueKey('manageTagDelete-2')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('tags-delete-confirm-dialog');

    // Confirm deletion
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('personal'), findsNothing);
    expect(find.text('work'), findsOneWidget);
    await binding.takeScreenshot('tags-manage-after-delete');
  });

  testWidgets('tag name validation: duplicate and too long', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    harness.go('/tags');
    await tester.pumpAndSettle();

    // Create a tag
    await tester.enterText(
      find.byKey(const ValueKey('manageTagsNameField')),
      'work',
    );
    await tester.tap(find.byKey(const ValueKey('manageTagsAddButton')));
    await tester.pumpAndSettle();

    // Try creating a duplicate (case-insensitive)
    await tester.enterText(
      find.byKey(const ValueKey('manageTagsNameField')),
      'Work',
    );
    await tester.tap(find.byKey(const ValueKey('manageTagsAddButton')));
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('tags-duplicate-error');

    // Only one 'work' tag should exist
    expect(find.byKey(const ValueKey('manageTag-1')), findsOneWidget);
  });

  testWidgets('10-tag limit shows limit message', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    // Pre-create 10 tags via repository
    final tagRepo = harness.container.read(tagRepositoryProvider);
    for (var i = 1; i <= 10; i++) {
      await tagRepo.createTag('tag$i');
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    harness.go('/tags');
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('tags-limit-reached');

    // The add field should not be visible; limit message should be shown
    expect(find.byKey(const ValueKey('manageTagsNameField')), findsNothing);
    expect(find.textContaining('10'), findsWidgets);
  });

  testWidgets('assign tags from entry detail', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    // Create tags and an entry
    final tagRepo = harness.container.read(tagRepositoryProvider);
    await tagRepo.createTag('work');
    await tagRepo.createTag('personal');
    final entryRepo = harness.container.read(entryRepositoryProvider);
    final entryId = await entryRepo.saveEntry('my journal entry', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to entry detail
    harness.go('/entry/$entryId');
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('detail-before-tag-assign');

    // Tap the "+" tag assign button
    await tester.tap(find.byKey(const ValueKey('detailTagAdd')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('tag-assignment-sheet');

    // Select 'work' tag
    await tester.tap(find.byKey(const ValueKey('assignTag-1')));
    await tester.pumpAndSettle();

    // Close the bottom sheet
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('detail-with-tag-assigned');

    // Verify tag chip shows on detail
    expect(find.byKey(const ValueKey('detailTag-1')), findsOneWidget);
    expect(find.text('work'), findsOneWidget);
  });

  testWidgets('create tag inline from assignment sheet', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final entryRepo = harness.container.read(entryRepositoryProvider);
    final entryId = await entryRepo.saveEntry('my entry', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    harness.go('/entry/$entryId');
    await tester.pumpAndSettle();

    // Open assignment sheet
    await tester.tap(find.byKey(const ValueKey('detailTagAdd')));
    await tester.pumpAndSettle();

    // Type a new tag name and submit
    final createFields = find.byType(TextField);
    await tester.enterText(createFields.last, 'newtag');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('tag-assignment-inline-create');

    // The new tag should appear and be selected
    expect(find.text('newtag'), findsWidgets);

    // Close sheet
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Verify tag shows on detail
    expect(find.text('newtag'), findsWidgets);
  });

  testWidgets('remove tag from entry via assignment sheet', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    // Create tag and entry, assign the tag
    final tagRepo = harness.container.read(tagRepositoryProvider);
    final tag = await tagRepo.createTag('removeme');
    final entryRepo = harness.container.read(entryRepositoryProvider);
    final entryId = await entryRepo.saveEntry('tagged entry', 'en-US');
    await tagRepo.setTagsForEntry(entryId, [tag.id]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    harness.go('/entry/$entryId');
    await tester.pumpAndSettle();

    // Verify tag is visible
    expect(find.byKey(ValueKey('detailTag-${tag.id}')), findsOneWidget);

    // Open assignment sheet and deselect
    await tester.tap(find.byKey(const ValueKey('detailTagAdd')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('assignTag-${tag.id}')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('detail-tag-removed');

    expect(find.byKey(ValueKey('detailTag-${tag.id}')), findsNothing);
  });

  testWidgets('filter entries by tag on the list screen', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    // Create tags and entries
    final tagRepo = harness.container.read(tagRepositoryProvider);
    final workTag = await tagRepo.createTag('work');
    final funTag = await tagRepo.createTag('fun');
    final entryRepo = harness.container.read(entryRepositoryProvider);
    final entry1 = await entryRepo.saveEntry('work meeting notes', 'en-US');
    harness.entryClock.advance(const Duration(hours: 1));
    final entry2 = await entryRepo.saveEntry('fun weekend trip', 'en-US');
    await tagRepo.setTagsForEntry(entry1, [workTag.id]);
    await tagRepo.setTagsForEntry(entry2, [funTag.id]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('list-with-tags-all');

    // Both entries visible, filter chip row present
    expect(find.byKey(const ValueKey('tagFilterAll')), findsOneWidget);
    expect(find.byKey(ValueKey('entryRow-$entry1')), findsOneWidget);
    expect(find.byKey(ValueKey('entryRow-$entry2')), findsOneWidget);

    // Filter by "work"
    await tester.tap(find.byKey(ValueKey('tagFilter-${workTag.id}')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('list-filtered-by-work');

    expect(find.byKey(ValueKey('entryRow-$entry1')), findsOneWidget);
    expect(find.byKey(ValueKey('entryRow-$entry2')), findsNothing);

    // Switch filter to "fun"
    await tester.tap(find.byKey(ValueKey('tagFilter-${funTag.id}')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('entryRow-$entry1')), findsNothing);
    expect(find.byKey(ValueKey('entryRow-$entry2')), findsOneWidget);

    // Clear filter via "All" chip
    await tester.tap(find.byKey(const ValueKey('tagFilterAll')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('entryRow-$entry1')), findsOneWidget);
    expect(find.byKey(ValueKey('entryRow-$entry2')), findsOneWidget);
  });

  testWidgets('tag filter empty state shows message and clear button', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    // Create a tag with no entries
    final tagRepo = harness.container.read(tagRepositoryProvider);
    final tag = await tagRepo.createTag('empty');
    final entryRepo = harness.container.read(entryRepositoryProvider);
    await entryRepo.saveEntry('untagged entry', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Filter by the empty tag
    await tester.tap(find.byKey(ValueKey('tagFilter-${tag.id}')));
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('list-tag-filter-empty');

    expect(
      find.byKey(const ValueKey('entryListNoTagResults')),
      findsOneWidget,
    );

    // Clear via the clear filter button
    await tester.tap(
      find.byKey(const ValueKey('entryListNoTagResultsClearButton')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
  });

  testWidgets('tag filter persists during navigation to detail and back', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final tagRepo = harness.container.read(tagRepositoryProvider);
    final tag = await tagRepo.createTag('sticky');
    final entryRepo = harness.container.read(entryRepositoryProvider);
    final entry1 = await entryRepo.saveEntry('tagged entry', 'en-US');
    harness.entryClock.advance(const Duration(hours: 1));
    await entryRepo.saveEntry('other entry', 'en-US');
    await tagRepo.setTagsForEntry(entry1, [tag.id]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Filter by "sticky" tag
    await tester.tap(find.byKey(ValueKey('tagFilter-${tag.id}')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('entryRow-$entry1')), findsOneWidget);

    // Navigate to detail
    await tester.tap(find.byKey(ValueKey('entryCard-$entry1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);

    // Go back
    await tester.tap(find.byKey(const ValueKey('entryDetailBackButton')));
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('list-tag-filter-persisted');

    // Filter should still be active
    expect(find.byKey(ValueKey('entryRow-$entry1')), findsOneWidget);
  });

  testWidgets('tag chips show on entry list rows', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final tagRepo = harness.container.read(tagRepositoryProvider);
    final tag = await tagRepo.createTag('visible');
    final entryRepo = harness.container.read(entryRepositoryProvider);
    final entryId = await entryRepo.saveEntry('tagged entry', 'en-US');
    await tagRepo.setTagsForEntry(entryId, [tag.id]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('list-row-with-tag-chip');

    // The tag name should be visible within the entry row
    expect(
      find.descendant(
        of: find.byKey(ValueKey('entryRow-$entryId')),
        matching: find.text('visible'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('search includes tag names', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final tagRepo = harness.container.read(tagRepositoryProvider);
    final tag = await tagRepo.createTag('searchable');
    final entryRepo = harness.container.read(entryRepositoryProvider);
    final entry1 = await entryRepo.saveEntry('entry one', 'en-US');
    harness.entryClock.advance(const Duration(hours: 1));
    await entryRepo.saveEntry('entry two', 'en-US');
    await tagRepo.setTagsForEntry(entry1, [tag.id]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Search by tag name
    await tester.enterText(
      find.byKey(const ValueKey('entryListSearchField')),
      'searchable',
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('list-search-by-tag-name');

    expect(find.byKey(ValueKey('entryRow-$entry1')), findsOneWidget);
  });

  testWidgets('draft entry can have tags assigned', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final tagRepo = harness.container.read(tagRepositoryProvider);
    await tagRepo.createTag('drafttag');
    final entryRepo = harness.container.read(entryRepositoryProvider);
    final draftId = await entryRepo.saveDraft('draft content', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    harness.go('/entry/$draftId');
    await tester.pumpAndSettle();

    // Open tag assignment
    await tester.tap(find.byKey(const ValueKey('detailTagAdd')));
    await tester.pumpAndSettle();

    // Select the tag
    await tester.tap(find.byKey(const ValueKey('assignTag-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('draft-with-tag');

    expect(find.byKey(const ValueKey('detailTag-1')), findsOneWidget);
  });

  testWidgets('exported CSV includes tags column', (tester) async {
    final exportWriter = _CapturingExportFileWriter();
    final harness = await _createHarness(exportWriter: exportWriter);
    addTearDown(harness.dispose);

    final tagRepo = harness.container.read(tagRepositoryProvider);
    final tag = await tagRepo.createTag('exported');
    final entryRepo = harness.container.read(entryRepositoryProvider);
    final entryId = await entryRepo.saveEntry('export me', 'en-US');
    await tagRepo.setTagsForEntry(entryId, [tag.id]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entryListExportButton')));
    await tester.pumpAndSettle();

    expect(
      exportWriter.contents,
      startsWith(
        'type,created_at,language,word_count,raw_transcript,cleaned_text,tags\n',
      ),
    );
    expect(exportWriter.contents, contains('exported'));
  });

  testWidgets('navigate to manage tags from filter chip row', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    // Need at least one tag so the chip row appears
    final tagRepo = harness.container.read(tagRepositoryProvider);
    await tagRepo.createTag('anytag');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the manage icon in the filter chip row
    await tester.tap(find.byKey(const ValueKey('tagFilterManage')));
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('navigate-to-manage-tags');

    // Should be on the manage tags screen
    expect(find.text('anytag'), findsOneWidget);
    expect(find.byKey(const ValueKey('manageTagsNameField')), findsOneWidget);
  });

  testWidgets('filter chip row hidden when no tags exist', (tester) async {
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
    await binding.takeScreenshot('list-no-tags-no-chip-row');

    // Filter chip row should not be visible
    expect(find.byKey(const ValueKey('tagFilterAll')), findsNothing);
    expect(find.byKey(const ValueKey('tagFilterManage')), findsNothing);
  });

  testWidgets('deleting a tag removes it from filtered entries', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final tagRepo = harness.container.read(tagRepositoryProvider);
    final tag = await tagRepo.createTag('doomed');
    final entryRepo = harness.container.read(entryRepositoryProvider);
    final entryId = await entryRepo.saveEntry('an entry', 'en-US');
    await tagRepo.setTagsForEntry(entryId, [tag.id]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify tag chip shows on entry row
    expect(
      find.descendant(
        of: find.byKey(ValueKey('entryRow-$entryId')),
        matching: find.text('doomed'),
      ),
      findsOneWidget,
    );

    // Delete the tag via manage screen
    harness.go('/tags');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('manageTagDelete-${tag.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Go back to entries
    await tester.tap(find.byKey(const ValueKey('manageTagsBackButton')));
    await tester.pumpAndSettle();

    // Tag should no longer show on the entry row
    expect(
      find.descendant(
        of: find.byKey(ValueKey('entryRow-$entryId')),
        matching: find.text('doomed'),
      ),
      findsNothing,
    );
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
  EntryExportFileWriter? exportWriter,
}) async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'wrait-tags-int',
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
      preferencesRepositoryProvider.overrideWithValue(
        const _TagsPreferencesRepository(),
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

class _TagsPreferencesRepository implements PreferencesRepository {
  const _TagsPreferencesRepository();

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
