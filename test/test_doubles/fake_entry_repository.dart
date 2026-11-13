import 'dart:async';

import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';

/// Configurable in-memory [EntryRepository] for tests. Emits updates through a
/// broadcast stream so reactive providers can be exercised.
///
/// This is the shared reactive repository double. Several older test files
/// still define their own private `implements EntryRepository` fakes; migrating
/// them onto this one is deliberately deferred (out of scope here, and it would
/// churn unrelated tests). New tests should prefer this shared double.
class FakeEntryRepository implements EntryRepository {
  FakeEntryRepository([List<Entry> initial = const <Entry>[]])
    : _entries = List<Entry>.of(initial);

  final StreamController<List<Entry>> _controller =
      StreamController<List<Entry>>.broadcast();
  List<Entry> _entries;

  void emit(List<Entry> entries) {
    _entries = List<Entry>.of(entries);
    _controller.add(_entries);
  }

  Future<void> dispose() => _controller.close();

  Entry? _find(int id) {
    for (final entry in _entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  @override
  Stream<List<Entry>> watchAllEntries() async* {
    yield _entries;
    yield* _controller.stream;
  }

  @override
  Stream<Entry?> watchEntryById(int id) async* {
    yield _find(id);
    yield* _controller.stream.map((_) => _find(id));
  }

  @override
  Future<Entry?> getEntryById(int id) async => _find(id);

  @override
  Future<List<int>> importEntries(List<Entry> entries) async => const <int>[];

  @override
  Future<int> saveDraft(String transcript, String language) async => 0;

  @override
  Future<int> saveEntry(String transcript, String language) async => 0;

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async => 0;

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
    _entries = _entries.where((entry) => entry.id != id).toList();
    _controller.add(_entries);
  }

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}
}

/// Builds a test entry with a local [createdAt].
Entry fakeEntry(
  int id,
  DateTime createdAt, {
  EntryType type = EntryType.saved,
}) => Entry(
  id: id,
  rawTranscript: 'entry $id',
  cleanedText: 'entry $id',
  type: type,
  language: 'en-US',
  createdAt: createdAt.millisecondsSinceEpoch,
  wordCount: 2,
);
