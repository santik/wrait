import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/entry_repository_impl.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/domain/model/entry.dart';

import '../../test_doubles/fake_clock.dart';
import '../../test_doubles/fake_secure_storage.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tempDirectory;
  LocalEntryDatabase? database;
  EntryRepositoryImpl? repository;
  late FakeClock clock;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('wrait-repo-test');
    clock = FakeClock(_ts(2026, 6, 8));

    database = await LocalEntryDatabase.open(
      keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(7)),
      databaseFile: File(
        '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
      ),
    );
    repository = EntryRepositoryImpl(
      entryDao: database!.entryDao,
      tagDao: database!.tagDao,
      clock: clock,
      storeDraftAudioPath: (audioPath) async => audioPath,
      resolveDraftAudioPath: (storedAudioPath) async => storedAudioPath,
    );
  });

  tearDown(() async {
    await database?.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'saves completed entries and exposes newest-first reactive updates',
    () async {
      await repository!.saveEntry('older entry', 'en-US');
      clock.advance(const Duration(minutes: 1));

      final updatedEntries = repository!.watchAllEntries().firstWhere(
        (entries) => entries.length == 2,
      );
      await repository!.saveEntry('newer entry', 'en-US');

      final entries = await updatedEntries;

      expect(entries.map((entry) => entry.rawTranscript), [
        'newer entry',
        'older entry',
      ]);
      expect(entries.first.type, EntryType.saved);
    },
  );

  test('stores and updates text drafts', () async {
    final id = await repository!.saveDraft('rough notes', 'en-US');

    await repository!.updateDraftTranscript(id, 'rough notes updated', 3);

    final draft = await repository!.getEntryById(id);

    expect(draft, isNotNull);
    expect(draft!.type, EntryType.draft);
    expect(draft.rawTranscript, 'rough notes updated');
    expect(draft.wordCount, 3);
    expect(draft.audioPath, isNull);
  });

  test('updates draft transcript and language atomically', () async {
    final audioFile = File('${tempDirectory.path}/atomic-audio.m4a');
    await audioFile.writeAsString('audio');
    final id = await repository!.saveAudioDraft(audioFile.path, 'en-US');

    await repository!.updateDraftTranscriptAndLanguage(
      id,
      'bonjour monde',
      2,
      'fr',
    );

    final entry = await repository!.getEntryById(id);

    expect(entry, isNotNull);
    expect(entry!.rawTranscript, 'bonjour monde');
    expect(entry.wordCount, 2);
    expect(entry.language, 'fr');
    expect(entry.audioPath, isNull);
    expect(entry.type, EntryType.draft);
  });

  test('canonicalizes supported language values before persistence', () async {
    final id = await repository!.saveEntry('bonjour monde', 'FR_fr');

    final entry = await repository!.getEntryById(id);

    expect(entry, isNotNull);
    expect(entry!.language, 'fr-FR');
  });

  test('stores audio drafts and finalizes them with cleaned text', () async {
    final audioFile = File('${tempDirectory.path}/draft-audio.m4a');
    await audioFile.writeAsString('audio');
    final id = await repository!.saveAudioDraft(audioFile.path, 'en-US');

    await repository!.finalizeDraftWithCleanedText(
      id,
      'raw transcript',
      'clean transcript',
      2,
    );

    final entry = await repository!.getEntryById(id);

    expect(entry, isNotNull);
    expect(entry!.type, EntryType.saved);
    expect(entry.rawTranscript, 'raw transcript');
    expect(entry.cleanedText, 'clean transcript');
    expect(entry.wordCount, 2);
    expect(entry.audioPath, isNull);
    expect(await audioFile.exists(), isTrue);
  });

  test(
    'updates cleaned text and language through reactive single-entry reads',
    () async {
      final id = await repository!.saveDraft('needs cleanup', 'en-US');

      final languageUpdate = repository!
          .watchEntryById(id)
          .firstWhere((entry) => entry?.language == 'nl-NL');

      await repository!.updateWithCleanedText(id, 'cleaned up', 2);
      await repository!.updateEntryLanguage(id, 'nl-NL');

      final updatedEntry = await languageUpdate;

      expect(updatedEntry, isNotNull);
      expect(updatedEntry!.cleanedText, 'cleaned up');
      expect(updatedEntry.type, EntryType.saved);
      expect(updatedEntry.language, 'nl-NL');
      expect(updatedEntry.wordCount, 2);
    },
  );

  test(
    'updates only cleaned text and recalculates word count for edits',
    () async {
      final id = await repository!.saveEntry('original transcript', 'en-US');

      await repository!.updateEditedCleanedText(id, 'edited cleaned text');

      final entry = await repository!.getEntryById(id);

      expect(entry, isNotNull);
      expect(entry!.cleanedText, 'edited cleaned text');
      expect(entry.rawTranscript, 'original transcript');
      expect(entry.wordCount, 3);
    },
  );

  test('throws when editing a missing entry', () async {
    await expectLater(
      repository!.updateEditedCleanedText(999, 'edited cleaned text'),
      throwsA(isA<StateError>()),
    );
  });

  test('canonicalizes language updates by base language', () async {
    final id = await repository!.saveEntry('hello world', 'en-US');

    await repository!.updateEntryLanguage(id, 'fr');

    final entry = await repository!.getEntryById(id);
    expect(entry, isNotNull);
    expect(entry!.language, 'fr');
  });

  test('rejects unsupported language values', () async {
    await expectLater(
      Future<int>.sync(() => repository!.saveEntry('hello world', 'zz-ZZ')),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      repository!.updateEntryLanguage(1, 'xx'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('returns pending drafts and deletes entries plus audio files', () async {
    final audioFile = File('${tempDirectory.path}/delete-me.m4a');
    await audioFile.writeAsString('audio');
    final audioDraftId = await repository!.saveAudioDraft(
      audioFile.path,
      'en-US',
    );
    await repository!.saveDraft('keep this draft', 'en-US');

    final pendingBeforeDelete = await repository!.getPendingDrafts();
    expect(pendingBeforeDelete, hasLength(2));

    await repository!.deleteEntry(audioDraftId);

    final pendingAfterDelete = await repository!.getPendingDrafts();

    expect(pendingAfterDelete, hasLength(1));
    expect(pendingAfterDelete.single.rawTranscript, 'keep this draft');
    expect(await audioFile.exists(), isFalse);
  });

  test(
    'deletes stale drafts and their audio files while keeping fresh drafts',
    () async {
      clock.currentTimeMs = _ts(2026, 5, 20);
      final staleAudioFile = File('${tempDirectory.path}/stale-file.m4a');
      await staleAudioFile.writeAsString('audio');
      await repository!.saveAudioDraft(staleAudioFile.path, 'en-US');

      clock.currentTimeMs = _ts(2026, 6, 7);
      await repository!.saveDraft('fresh draft', 'en-US');

      clock.currentTimeMs = _ts(2026, 6, 8);
      await repository!.deleteStaleDrafts(daysOld: 7);

      final pendingDrafts = await repository!.getPendingDrafts();

      expect(pendingDrafts, hasLength(1));
      expect(pendingDrafts.single.rawTranscript, 'fresh draft');
      expect(await staleAudioFile.exists(), isFalse);
    },
  );

  test(
    'resolves managed draft audio paths after the app cache root changes',
    () async {
      final originalCacheDirectory = Directory(
        '${tempDirectory.path}/cache-before-update',
      );
      await originalCacheDirectory.create(recursive: true);
      final updatedCacheDirectory = Directory(
        '${tempDirectory.path}/cache-after-update',
      );
      await updatedCacheDirectory.create(recursive: true);

      var activeCacheDirectory = originalCacheDirectory.path;
      repository = EntryRepositoryImpl(
        entryDao: database!.entryDao,
        tagDao: database!.tagDao,
        clock: clock,
        storeDraftAudioPath: (audioPath) async =>
            'app-cache://${path.basename(audioPath)}',
        resolveDraftAudioPath: (storedAudioPath) async {
          final relativePath = storedAudioPath.substring('app-cache://'.length);
          return path.join(activeCacheDirectory, relativePath);
        },
      );

      final originalAudioFile = File(
        path.join(originalCacheDirectory.path, 'draft-audio.m4a'),
      );
      await originalAudioFile.writeAsString('audio');
      final draftId = await repository!.saveAudioDraft(
        originalAudioFile.path,
        'en-US',
      );

      activeCacheDirectory = updatedCacheDirectory.path;
      final updatedAudioFile = File(
        path.join(updatedCacheDirectory.path, 'draft-audio.m4a'),
      );
      await updatedAudioFile.writeAsString('audio');

      final draft = await repository!.getEntryById(draftId);
      expect(draft, isNotNull);
      expect(draft!.audioPath, updatedAudioFile.path);

      await repository!.deleteEntry(draftId);
      expect(await updatedAudioFile.exists(), isFalse);
    },
  );

  test(
    'imports entries additively with generated ids and null audio paths',
    () async {
      await repository!.saveEntry('existing entry', 'en-US');

      await repository!.importEntries(<Entry>[
        Entry(
          id: 99,
          rawTranscript: 'imported saved',
          cleanedText: 'saved cleaned',
          type: EntryType.saved,
          language: 'fr',
          createdAt: _ts(2026, 6, 10),
          wordCount: 2,
          audioPath: '/tmp/ignored-audio.m4a',
        ),
        Entry(
          id: 100,
          rawTranscript: 'imported draft',
          cleanedText: null,
          type: EntryType.draft,
          language: 'en-US',
          createdAt: _ts(2026, 6, 11),
          wordCount: 2,
        ),
      ]);

      final entries = await repository!.watchAllEntries().first;

      expect(entries, hasLength(3));
      expect(entries.map((entry) => entry.rawTranscript), [
        'imported draft',
        'imported saved',
        'existing entry',
      ]);
      expect(entries[0].id, isNot(100));
      expect(entries[1].id, isNot(99));
      expect(entries[1].cleanedText, 'saved cleaned');
      expect(entries[1].language, 'fr');
      expect(entries[1].audioPath, isNull);
      expect(entries[0].type, EntryType.draft);
      expect(entries[0].createdAt, _ts(2026, 6, 11));
    },
  );

  test('rolls back the whole import batch when one row is invalid', () async {
    await expectLater(
      database!.entryDao.insertEntries(<EntryRecordsCompanion>[
        EntryRecordsCompanion.insert(
          rawTranscript: 'valid row',
          type: EntryType.saved.name,
          language: 'en-US',
          createdAt: _ts(2026, 6, 10),
        ),
        EntryRecordsCompanion.insert(
          rawTranscript: 'invalid row',
          type: 'archived',
          language: 'en-US',
          createdAt: _ts(2026, 6, 11),
        ),
      ]),
      throwsA(anything),
    );

    final entries = await repository!.watchAllEntries().first;

    expect(entries, isEmpty);
  });
}

int _ts(int year, int month, int day) =>
    DateTime(year, month, day).millisecondsSinceEpoch;
