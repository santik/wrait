import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';

import '../../core/time/system_clock.dart';
import '../../domain/model/entry.dart';
import '../../domain/model/supported_language.dart';
import '../../domain/repository/entry_repository.dart';
import 'draft_audio_path_codec.dart';
import 'local_entry_database.dart';
import 'tag_repository_impl.dart';

typedef StoreDraftAudioPathCallback = Future<String> Function(String audioPath);
typedef ResolveDraftAudioPathCallback = Future<String> Function(
  String storedAudioPath,
);

class EntryRepositoryImpl implements EntryRepository {
  EntryRepositoryImpl({
    required this.entryDao,
    required this.tagDao,
    required this.clock,
    StoreDraftAudioPathCallback? storeDraftAudioPath,
    ResolveDraftAudioPathCallback? resolveDraftAudioPath,
  }) : _storeDraftAudioPath = storeDraftAudioPath ?? DraftAudioPathCodec.store,
       _resolveDraftAudioPath =
           resolveDraftAudioPath ?? DraftAudioPathCodec.resolve;

  final EntryDao entryDao;
  final TagDao tagDao;
  final Clock clock;
  final StoreDraftAudioPathCallback _storeDraftAudioPath;
  final ResolveDraftAudioPathCallback _resolveDraftAudioPath;

  @override
  Stream<List<Entry>> watchAllEntries() {
    // Re-emit when entries or any tag assignment changes.
    List<EntryRecord> latestRows = const [];
    var entriesReady = false;
    var tagsReady = false;

    final controller = StreamController<List<Entry>>.broadcast();

    Future<void> emit() async {
      if (!entriesReady || !tagsReady) return;
      controller.add(
        await Future.wait(
          latestRows.map(_mapEntryRecord),
          eagerError: true,
        ),
      );
    }

    final entriesSub = entryDao.watchAllEntries().listen((rows) {
      latestRows = rows;
      entriesReady = true;
      emit();
    });
    // Watch the entry-tag join table; any assignment change re-maps.
    final tagsSub = tagDao.watchAllAssignments().listen((_) {
      tagsReady = true;
      if (entriesReady) emit();
    });

    controller.onCancel = () {
      entriesSub.cancel();
      tagsSub.cancel();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Stream<Entry?> watchEntryById(int id) {
    // Re-emit when either the entry row or its tags change.
    EntryRecord? latestRow;
    var entryReady = false;
    var tagsReady = false;

    final controller = StreamController<Entry?>.broadcast();

    Future<void> emit() async {
      if (!entryReady || !tagsReady) return;
      if (latestRow == null) {
        controller.add(null);
        return;
      }
      controller.add(await _mapEntryRecord(latestRow!));
    }

    final entrySub = entryDao.watchEntryById(id).listen((row) {
      latestRow = row;
      entryReady = true;
      emit();
    });
    final tagsSub = tagDao.watchTagsForEntry(id).listen((_) {
      tagsReady = true;
      emit();
    });

    controller.onCancel = () {
      entrySub.cancel();
      tagsSub.cancel();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<Entry?> getEntryById(int id) async {
    final row = await entryDao.getEntryById(id);
    if (row == null) {
      return null;
    }

    return _mapEntryRecord(row);
  }

  @override
  Future<void> importEntries(List<Entry> entries) async {
    if (entries.isEmpty) {
      return;
    }

    final importedEntries = entries
        .map((entry) {
          final canonicalLanguage = _requireSupportedLanguage(entry.language);
          return EntryRecordsCompanion.insert(
            rawTranscript: entry.rawTranscript,
            type: entry.type.name,
            language: canonicalLanguage,
            createdAt: entry.createdAt,
            wordCount: Value(entry.wordCount),
            cleanedText: Value(entry.cleanedText),
            audioPath: const Value(null),
          );
        })
        .toList(growable: false);

    await entryDao.insertEntries(importedEntries);
  }

  @override
  Future<int> saveDraft(String transcript, String language) {
    final canonicalLanguage = _requireSupportedLanguage(language);

    return entryDao.insertEntry(
      EntryRecordsCompanion.insert(
        rawTranscript: transcript,
        type: EntryType.draft.name,
        language: canonicalLanguage,
        createdAt: clock.now(),
        wordCount: Value(_countWords(transcript)),
      ),
    );
  }

  @override
  Future<int> saveEntry(String transcript, String language) {
    final canonicalLanguage = _requireSupportedLanguage(language);

    return entryDao.insertEntry(
      EntryRecordsCompanion.insert(
        rawTranscript: transcript,
        type: EntryType.saved.name,
        language: canonicalLanguage,
        createdAt: clock.now(),
        wordCount: Value(_countWords(transcript)),
      ),
    );
  }

  @override
  Future<int> saveAudioDraft(String audioPath, String language) {
    if (audioPath.trim().isEmpty) {
      throw ArgumentError.value(audioPath, 'audioPath', 'must not be empty');
    }
    final canonicalLanguage = _requireSupportedLanguage(language);
    return _saveAudioDraft(
      audioPath: audioPath,
      canonicalLanguage: canonicalLanguage,
    );
  }

  Future<int> _saveAudioDraft({
    required String audioPath,
    required String canonicalLanguage,
  }) async {
    final storedAudioPath = await _storeDraftAudioPath(audioPath);
    return entryDao.insertEntry(
      EntryRecordsCompanion.insert(
        rawTranscript: '',
        type: EntryType.draft.name,
        language: canonicalLanguage,
        createdAt: clock.now(),
        audioPath: Value(storedAudioPath),
      ),
    );
  }

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {
    final affectedRows = await entryDao.updateEditedCleanedText(
      id,
      cleanedText,
      _countWords(cleanedText),
    );
    _throwIfMissing(id, affectedRows);
  }

  @override
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) async {
    final affectedRows = await entryDao.updateWithCleanedText(
      id,
      cleanedText,
      wordCount,
    );
    _throwIfMissing(id, affectedRows);
  }

  @override
  Future<void> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  ) async {
    final affectedRows = await entryDao.updateDraftTranscript(
      id,
      rawTranscript,
      wordCount,
    );
    _throwIfMissing(id, affectedRows);
  }

  @override
  Future<void> updateDraftTranscriptAndLanguage(
    int id,
    String rawTranscript,
    int wordCount,
    String language,
  ) async {
    final canonicalLanguage = _requireSupportedLanguage(language);
    final affectedRows = await entryDao.updateDraftTranscriptAndLanguage(
      id,
      rawTranscript,
      wordCount,
      canonicalLanguage,
    );
    _throwIfMissing(id, affectedRows);
  }

  @override
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) async {
    final affectedRows = await entryDao.finalizeDraftWithCleanedText(
      id,
      rawTranscript,
      cleanedText,
      wordCount,
    );
    _throwIfMissing(id, affectedRows);
  }

  @override
  Future<void> updateEntryLanguage(int id, String language) async {
    final canonicalLanguage = _requireSupportedLanguage(language);
    final affectedRows = await entryDao.updateEntryLanguage(
      id,
      canonicalLanguage,
    );
    _throwIfMissing(id, affectedRows);
  }

  @override
  Future<List<Entry>> getPendingDrafts() async {
    final drafts = await entryDao.getPendingDrafts();
    return Future.wait(drafts.map(_mapEntryRecord), eagerError: true);
  }

  @override
  Future<void> deleteEntry(int id) async {
    final existing = await entryDao.getEntryById(id);
    if (existing == null) {
      throw StateError('Entry with id $id not found or already deleted');
    }

    await entryDao.deleteEntryById(id);
    await _deleteFileIfPresent(await _resolveAudioPath(existing.audioPath));
  }

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {
    if (daysOld < 0) {
      throw ArgumentError.value(daysOld, 'daysOld', 'must not be negative');
    }

    final cutoffTimestamp =
        clock.now() - Duration(days: daysOld).inMilliseconds;
    final staleDrafts = await entryDao.getStaleDraftsOlderThan(cutoffTimestamp);
    await entryDao.deleteStaleDraftsOlderThan(cutoffTimestamp);

    for (final draft in staleDrafts) {
      await _deleteFileIfPresent(await _resolveAudioPath(draft.audioPath));
    }
  }

  Future<Entry> _mapEntryRecord(EntryRecord row) async {
    final entryType = EntryType.tryParse(row.type);
    if (entryType == null) {
      throw StateError(
        'Entry ${row.id} has unsupported persisted type: ${row.type}',
      );
    }

    final tagRecords = await tagDao.getTagsForEntry(row.id);
    final tags = tagRecords
        .map(TagRepositoryImpl.mapTagRecord)
        .toList(growable: false);

    return Entry(
      id: row.id,
      rawTranscript: row.rawTranscript,
      cleanedText: row.cleanedText,
      type: entryType,
      language: row.language,
      createdAt: row.createdAt,
      wordCount: row.wordCount,
      audioPath: await _resolveAudioPath(row.audioPath),
      tags: tags,
    );
  }

  Future<String?> _resolveAudioPath(String? storedAudioPath) async {
    if (storedAudioPath == null || storedAudioPath.trim().isEmpty) {
      return storedAudioPath;
    }

    return _resolveDraftAudioPath(storedAudioPath);
  }

  void _throwIfMissing(int id, int affectedRows) {
    if (affectedRows == 0) {
      throw StateError('Entry with id $id not found or already deleted');
    }
  }

  String _requireSupportedLanguage(String language) {
    final resolved = resolveSupportedLanguageCode(language);
    if (resolved != null) {
      return resolved;
    }

    throw ArgumentError.value(
      language,
      'language',
      'must resolve to a supported BCP-47 language code',
    );
  }

  int _countWords(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .length;
  }

  Future<void> _deleteFileIfPresent(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) {
      return;
    }

    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup only.
    }
  }
}
