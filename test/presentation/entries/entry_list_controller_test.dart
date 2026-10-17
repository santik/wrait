import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/entries/entry_export_file_writer.dart';
import 'package:wrait/data/entries/entry_export_providers.dart';
import 'package:wrait/data/entries/entry_import_file_reader.dart';
import 'package:wrait/data/entries/entry_import_providers.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/service/entry_export_service.dart';
import 'package:wrait/domain/service/entry_import_service.dart';
import 'package:wrait/presentation/entries/entry_list_controller.dart';

void main() {
  test('includes drafts and sorts entries newest first', () async {
    final repository = _FakeEntryRepository(
      entries: [
        _entry(id: 1, createdAt: DateTime(2026, 6, 14, 9)),
        _entry(
          id: 2,
          createdAt: DateTime(2026, 6, 15, 9),
          type: EntryType.draft,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [entryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final entriesCompleter = Completer<List<Entry>>();
    final subscription = container.listen<AsyncValue<List<Entry>>>(
      entryListEntriesProvider,
      (previous, next) {
        final entries = next.asData?.value;
        if (entries != null && !entriesCompleter.isCompleted) {
          entriesCompleter.complete(entries);
        }
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final entries = await entriesCompleter.future;

    expect(entries.map((entry) => entry.id), [2, 1]);
    expect(entries.first.type, EntryType.draft);
  });

  test('delete success calls the repository', () async {
    final repository = _FakeEntryRepository(entries: [_entry(id: 1)]);
    final container = ProviderContainer(
      overrides: [entryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(entryListControllerProvider.notifier).deleteEntry(1);

    expect(repository.deletedIds, [1]);
  });

  test('delete failure is caught without throwing', () async {
    final repository = _FakeEntryRepository(
      entries: [_entry(id: 1)],
      throwsOnDelete: true,
    );
    final container = ProviderContainer(
      overrides: [entryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(entryListControllerProvider.notifier).deleteEntry(1);

    expect(repository.deletedIds, [1]);
  });

  test('export success returns the exported file metadata', () async {
    final repository = _FakeEntryRepository(entries: [_entry(id: 1)]);
    final service = EntryExportService(
      fileWriter: const _TestFileWriter(
        result: EntryExportFileWriteResult(
          fileName: 'entries.csv',
          pathLabel: 'Downloads/Wrait',
        ),
      ),
      now: () => DateTime.utc(2026, 6, 30, 12),
    );
    final container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repository),
        entryExportServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(entryListControllerProvider.notifier)
        .exportEntries(repository.entriesSnapshot);

    expect(result.didExport, isTrue);
    expect(result.fileName, 'entries.csv');
    expect(result.pathLabel, 'Downloads/Wrait');
    expect(container.read(entryListControllerProvider).isExporting, isFalse);
  });

  test('export failure is caught without throwing and resets state', () async {
    final repository = _FakeEntryRepository(entries: [_entry(id: 1)]);
    final service = EntryExportService(
      fileWriter: const _ThrowingTestFileWriter(),
      now: () => DateTime.utc(2026, 6, 30, 12),
    );
    final container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repository),
        entryExportServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(entryListControllerProvider.notifier)
        .exportEntries(repository.entriesSnapshot);

    expect(result.didExport, isFalse);
    expect(container.read(entryListControllerProvider).isExporting, isFalse);
    expect(repository.entriesSnapshot.single.id, 1);
  });

  test('import success appends parsed entries and resets state', () async {
    final repository = _FakeEntryRepository(entries: [_entry(id: 1)]);
    final service = EntryImportService(
      fileReader: _TestImportFileReader(
        result: EntryImportFileReadResult(
          fileName: 'import.csv',
          contents: _validCsv(),
        ),
      ),
      entryRepository: repository,
    );
    final container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repository),
        entryImportServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(entryListControllerProvider.notifier)
        .importEntries();

    expect(result.didImport, isTrue);
    expect(result.importedCount, 2);
    expect(container.read(entryListControllerProvider).isImporting, isFalse);
    expect(repository.entriesSnapshot, hasLength(3));
  });

  test('import cancellation is silent and resets state', () async {
    final repository = _FakeEntryRepository(entries: [_entry(id: 1)]);
    final service = EntryImportService(
      fileReader: _TestImportFileReader(result: null),
      entryRepository: repository,
    );
    final container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repository),
        entryImportServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(entryListControllerProvider.notifier)
        .importEntries();

    expect(result.wasCancelled, isTrue);
    expect(container.read(entryListControllerProvider).isImporting, isFalse);
    expect(repository.entriesSnapshot, hasLength(1));
  });

  test('import failure is caught without throwing and resets state', () async {
    final repository = _FakeEntryRepository(entries: [_entry(id: 1)]);
    final service = EntryImportService(
      fileReader: const _ThrowingImportFileReader(),
      entryRepository: repository,
    );
    final container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repository),
        entryImportServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(entryListControllerProvider.notifier)
        .importEntries();

    expect(result.didImport, isFalse);
    expect(result.wasCancelled, isFalse);
    expect(result.failureCategory, EntryImportFailureCategory.unreadableFile);
    expect(container.read(entryListControllerProvider).isImporting, isFalse);
    expect(repository.entriesSnapshot.single.id, 1);
  });

  test('import progress prevents duplicate picker calls', () async {
    final repository = _FakeEntryRepository(entries: const <Entry>[]);
    final completer = Completer<EntryImportFileReadResult?>();
    final reader = _TestImportFileReader(completer: completer);
    final service = EntryImportService(
      fileReader: reader,
      entryRepository: repository,
    );
    final container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repository),
        entryImportServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final firstImport = container
        .read(entryListControllerProvider.notifier)
        .importEntries();
    final secondImport = container
        .read(entryListControllerProvider.notifier)
        .importEntries();

    expect(container.read(entryListControllerProvider).isImporting, isTrue);
    expect(reader.callCount, 1);

    completer.complete(
      EntryImportFileReadResult(fileName: 'import.csv', contents: _validCsv()),
    );

    final firstResult = await firstImport;
    final secondResult = await secondImport;

    expect(firstResult.didImport, isTrue);
    expect(secondResult.wasCancelled, isTrue);
    expect(container.read(entryListControllerProvider).isImporting, isFalse);
    expect(reader.callCount, 1);
  });

  test('search query updates and clears without persistence', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen<String>(
      entryListSearchQueryProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final notifier = container.read(entryListSearchQueryProvider.notifier);
    notifier.update('  Project notes  ');

    expect(container.read(entryListSearchQueryProvider), '  Project notes  ');

    notifier.clear();

    expect(container.read(entryListSearchQueryProvider), isEmpty);
  });

  test('empty and whitespace-only queries retain the incoming list', () {
    final entries = [
      _entry(id: 2, createdAt: DateTime(2026, 6, 15)),
      _entry(id: 1, createdAt: DateTime(2026, 6, 14)),
    ];

    expect(EntryListController.filterEntries(entries, ''), same(entries));
    expect(EntryListController.filterEntries(entries, ' \n\t '), same(entries));
  });

  test('filters every case-insensitive term across cleaned and raw text', () {
    final entries = [
      _entry(
        id: 3,
        rawTranscript: 'Monday walk through the park',
        cleanedText: 'Project notes for Monday',
      ),
      _entry(
        id: 2,
        rawTranscript: 'Project update only',
        cleanedText: 'No matching day',
      ),
      _entry(
        id: 1,
        rawTranscript: 'A quiet Monday',
        cleanedText: 'No matching topic',
      ),
    ];

    final matches = EntryListController.filterEntries(
      entries,
      '  PROJECT\n monday ',
    );

    expect(matches.map((entry) => entry.id), [3]);
  });

  test(
    'treats special and SQL-like input as literal repeated search terms',
    () {
      final entries = [
        _entry(
          id: 1,
          rawTranscript: 'Café ☕ C++ notes',
          cleanedText: 'Weekly review',
        ),
        _entry(
          id: 2,
          rawTranscript: 'ordinary entry',
          cleanedText: 'unrelated text',
        ),
      ];

      final specialMatches = EntryListController.filterEntries(
        entries,
        ' C++ café ☕ C++ ',
      );
      final sqlLikeMatches = EntryListController.filterEntries(
        entries,
        "' OR 1=1 --",
      );
      final longQuery = List<String>.filled(512, 'x').join();

      expect(specialMatches.map((entry) => entry.id), [1]);
      expect(sqlLikeMatches, isEmpty);
      expect(EntryListController.filterEntries(entries, longQuery), isEmpty);
    },
  );

  test('preserves source ordering and does not match across text fields', () {
    final entries = [
      _entry(id: 3, rawTranscript: 'budget review', cleanedText: 'today'),
      _entry(id: 2, rawTranscript: 'budget ideas', cleanedText: 'tomorrow'),
      _entry(id: 1, rawTranscript: 'text', cleanedText: 'clean'),
    ];

    final orderedMatches = EntryListController.filterEntries(entries, 'budget');
    final boundaryMatches = EntryListController.filterEntries(entries, 'ntex');

    expect(orderedMatches.map((entry) => entry.id), [3, 2]);
    expect(boundaryMatches, isEmpty);
  });

  test('includes saved and text drafts but excludes audio-only drafts', () {
    final entries = [
      _entry(id: 1, rawTranscript: 'weekly reflection'),
      _entry(id: 2, type: EntryType.draft, rawTranscript: 'weekly draft'),
      Entry(
        id: 3,
        rawTranscript: '',
        cleanedText: null,
        type: EntryType.draft,
        language: 'en-US',
        createdAt: DateTime(2026, 6, 15).millisecondsSinceEpoch,
        wordCount: 0,
        audioPath: '/tmp/pending.m4a',
      ),
    ];

    final matches = EntryListController.filterEntries(entries, 'weekly');

    expect(matches.map((entry) => entry.id), [1, 2]);
  });
}

class _FakeEntryRepository implements EntryRepository {
  _FakeEntryRepository({
    required List<Entry> entries,
    this.throwsOnDelete = false,
  }) : _entries = List<Entry>.from(entries);

  final bool throwsOnDelete;
  final List<int> deletedIds = <int>[];
  final List<Entry> _entries;

  List<Entry> get entriesSnapshot => List<Entry>.from(_entries);

  @override
  Stream<List<Entry>> watchAllEntries() => Stream<List<Entry>>.value(_entries);

  @override
  Stream<Entry?> watchEntryById(int id) => const Stream<Entry?>.empty();

  @override
  Future<Entry?> getEntryById(int id) async => null;

  @override
  Future<List<int>> importEntries(List<Entry> entries) async {
    final ids = <int>[];
    var nextId = _entries.fold<int>(
      0,
      (current, entry) => entry.id > current ? entry.id : current,
    );
    for (final entry in entries) {
      nextId += 1;
      ids.add(nextId);
      _entries.add(entry.copyWith(id: nextId));
    }
    return ids;
  }

  @override
  Future<int> saveDraft(String transcript, String language) async => 1;

  @override
  Future<int> saveEntry(String transcript, String language) async => 1;

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async => 1;

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {}

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
    if (throwsOnDelete) {
      throw StateError('delete failed');
    }
    _entries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}
}

class _TestFileWriter implements EntryExportFileWriter {
  const _TestFileWriter({required this.result});

  final EntryExportFileWriteResult result;

  @override
  Future<EntryExportFileWriteResult> writeCsvExport({
    required String fileName,
    required String contents,
  }) async {
    return result;
  }
}

class _ThrowingTestFileWriter implements EntryExportFileWriter {
  const _ThrowingTestFileWriter();

  @override
  Future<EntryExportFileWriteResult> writeCsvExport({
    required String fileName,
    required String contents,
  }) async {
    throw StateError('write failed');
  }
}

class _TestImportFileReader implements EntryImportFileReader {
  _TestImportFileReader({this.result, this.completer});

  final EntryImportFileReadResult? result;
  final Completer<EntryImportFileReadResult?>? completer;
  int callCount = 0;

  @override
  Future<EntryImportFileReadResult?> pickCsvImport() async {
    callCount += 1;
    return completer?.future ?? result;
  }
}

class _ThrowingImportFileReader implements EntryImportFileReader {
  const _ThrowingImportFileReader();

  @override
  Future<EntryImportFileReadResult?> pickCsvImport() async {
    throw const EntryImportFileReaderException('read failed');
  }
}

String _validCsv() {
  final createdAtMs = DateTime.utc(2026, 6, 30, 12).millisecondsSinceEpoch;
  return [
    'type,created_at,language,word_count,raw_transcript,cleaned_text',
    'saved,$createdAtMs,en-US,2,imported saved,clean saved',
    'draft,$createdAtMs,fr-FR,2,imported draft,',
  ].join('\n');
}

Entry _entry({
  required int id,
  DateTime? createdAt,
  EntryType type = EntryType.saved,
  String? rawTranscript,
  String? cleanedText,
}) {
  return Entry(
    id: id,
    rawTranscript: rawTranscript ?? 'entry $id',
    cleanedText: cleanedText,
    type: type,
    language: 'en-US',
    createdAt: (createdAt ?? DateTime(2026, 6, 15)).millisecondsSinceEpoch,
    wordCount: 2,
  );
}
