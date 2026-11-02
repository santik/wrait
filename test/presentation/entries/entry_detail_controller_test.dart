import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/presentation/entries/entry_detail_controller.dart';
import 'package:wrait/presentation/entries/entry_detail_formatters.dart';
import 'package:wrait/presentation/entries/entry_share_service.dart';

void main() {
  test('auto-saves only the latest edited text', () async {
    final repository = _FakeEntryRepository();
    final shareService = _FakeEntryShareService();
    final container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repository),
        entryShareServiceProvider.overrideWithValue(shareService),
        entryDetailAutoSaveDelayProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      entryDetailControllerProvider(1).notifier,
    );
    controller.syncFromEntry('initial text');
    controller.startEditing('initial text');
    controller.updateDraftText('first edit');
    controller.updateDraftText('final edit');

    final didSave = await controller.flushPendingEdits();

    expect(didSave, isTrue);
    expect(repository.editedTexts, ['final edit']);
    expect(
      container.read(entryDetailControllerProvider(1)).saveFailed,
      isFalse,
    );
  });

  test('reports save failures without a false saved state', () async {
    final repository = _FakeEntryRepository()..throwOnEdit = true;
    final container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repository),
        entryShareServiceProvider.overrideWithValue(_FakeEntryShareService()),
        entryDetailAutoSaveDelayProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      entryDetailControllerProvider(1),
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final controller = container.read(
      entryDetailControllerProvider(1).notifier,
    );
    controller.syncFromEntry('initial text');
    controller.startEditing('initial text');
    controller.updateDraftText('new text');

    final didSave = await controller.flushPendingEdits();

    expect(didSave, isFalse);
    expect(container.read(entryDetailControllerProvider(1)).saveFailed, isTrue);
  });

  test(
    'persists a newer revision after an earlier in-flight save completes',
    () async {
      final repository = _FakeEntryRepository();
      final firstSaveBlocker = Completer<void>();
      repository.editBlockers.add(firstSaveBlocker);
      final container = ProviderContainer(
        overrides: [
          entryRepositoryProvider.overrideWithValue(repository),
          entryShareServiceProvider.overrideWithValue(_FakeEntryShareService()),
          entryDetailAutoSaveDelayProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        entryDetailControllerProvider(1).notifier,
      );
      controller.syncFromEntry('initial text');
      controller.startEditing('initial text');
      controller.updateDraftText('first edit');

      final firstFlush = controller.flushPendingEdits();
      controller.updateDraftText('second edit');
      final secondFlush = controller.flushPendingEdits();

      firstSaveBlocker.complete();

      expect(await firstFlush, isTrue);
      expect(await secondFlush, isTrue);
      expect(repository.editedTexts, ['first edit', 'second edit']);
      expect(
        container.read(entryDetailControllerProvider(1)).saveFailed,
        isFalse,
      );
    },
  );

  test('delegates timestamped sharing through the share service', () async {
    final shareService = _FakeEntryShareService();
    final container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(_FakeEntryRepository()),
        entryShareServiceProvider.overrideWithValue(shareService),
      ],
    );
    addTearDown(container.dispose);

    final didShare = await container
        .read(entryDetailControllerProvider(1).notifier)
        .shareDisplayedText(
          text: 'share me',
          shareTimestamp: 'share timestamp',
        );

    expect(didShare, isTrue);
    expect(shareService.sharedTexts, [
      'share timestamp${entryDetailShareSectionSeparator}share me',
    ]);
  });

  test('delegates deletion through the shared deletion controller', () async {
    final repository = _FakeEntryRepository();
    final container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repository),
        entryShareServiceProvider.overrideWithValue(_FakeEntryShareService()),
      ],
    );
    addTearDown(container.dispose);

    final didDelete = await container
        .read(entryDetailControllerProvider(1).notifier)
        .deleteEntry();

    expect(didDelete, isTrue);
    expect(repository.deletedIds, [1]);
  });

  test(
    'disposing during an in-flight auto-save ignores completion safely',
    () async {
      final repository = _FakeEntryRepository();
      final saveBlocker = Completer<void>();
      repository.editBlockers.add(saveBlocker);
      final container = ProviderContainer(
        overrides: [
          entryRepositoryProvider.overrideWithValue(repository),
          entryShareServiceProvider.overrideWithValue(_FakeEntryShareService()),
          entryDetailAutoSaveDelayProvider.overrideWithValue(Duration.zero),
        ],
      );

      final controller = container.read(
        entryDetailControllerProvider(1).notifier,
      );
      controller.syncFromEntry('initial text');
      controller.startEditing('initial text');
      controller.updateDraftText('final edit');

      final flushFuture = controller.flushPendingEdits();
      container.dispose();
      saveBlocker.complete();

      await flushFuture;
    },
  );
}

class _FakeEntryRepository implements EntryRepository {
  final List<String> editedTexts = <String>[];
  final List<int> deletedIds = <int>[];
  final List<Completer<void>> editBlockers = <Completer<void>>[];
  bool throwOnEdit = false;

  @override
  Stream<List<Entry>> watchAllEntries() =>
      Stream<List<Entry>>.value(const <Entry>[]);

  @override
  Stream<Entry?> watchEntryById(int id) => const Stream<Entry?>.empty();

  @override
  Future<Entry?> getEntryById(int id) async => null;

  @override
  Future<List<int>> importEntries(List<Entry> entries) async => const [];

  @override
  Future<int> saveDraft(String transcript, String language) async => 1;

  @override
  Future<int> saveEntry(String transcript, String language) async => 1;

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async => 1;

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {
    if (throwOnEdit) {
      throw StateError('edit failed');
    }
    editedTexts.add(cleanedText);
    if (editBlockers.isNotEmpty) {
      await editBlockers.removeAt(0).future;
    }
  }

  @override
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<void> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  ) async {}

  @override
  Future<void> updateDraftTranscriptAndLanguage(
    int id,
    String rawTranscript,
    int wordCount,
    String language,
  ) async {}

  @override
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<void> updateEntryLanguage(int id, String language) async {}

  @override
  Future<List<Entry>> getPendingDrafts() async => const <Entry>[];

  @override
  Future<void> deleteEntry(int id) async {
    deletedIds.add(id);
  }

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}
}

class _FakeEntryShareService implements EntryShareService {
  final List<String> sharedTexts = <String>[];

  @override
  Future<void> shareText(String text) async {
    sharedTexts.add(text);
  }
}
