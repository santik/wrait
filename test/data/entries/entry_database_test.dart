import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:wrait/core/time/system_clock.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/entry_repository_impl.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';

import '../../test_doubles/fake_clock.dart';
import '../../test_doubles/fake_secure_storage.dart';

const _legacyDatabaseFileName = 'wrait_entries.sqlite';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('wrait-db-test');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('generates and persists a database key once', () async {
    final storage = FakeSecureKeyValueStore();
    final keyStore = DatabaseKeyStore(storage, random: Random(1));

    final first = await keyStore.readOrCreateKey();
    final second = await keyStore.readOrCreateKey();

    expect(first, isNotEmpty);
    expect(second, first);
    expect(await storage.read(DatabaseKeyStore.storageKey), first);
  });

  test('fails fast when encrypted sqlite support is unavailable', () async {
    await expectLater(
      LocalEntryDatabase.open(
        keyStore: DatabaseKeyStore(
          FakeSecureKeyValueStore(),
          random: Random(9),
        ),
        databaseFile: _databaseFile(tempDirectory),
        verifyCipherSupport: (_) {
          throw StateError('cipher support unavailable');
        },
      ),
      throwsA(
        predicate(
          (error) => error.toString().contains('cipher support unavailable'),
          'error containing the injected cipher-support failure message',
        ),
      ),
    );
  });

  test(
    'fresh install ignores the legacy entry database file and starts clean',
    () async {
      final storage = FakeSecureKeyValueStore();
      final keyStore = DatabaseKeyStore(storage, random: Random(10));
      final legacyDatabaseFile = _legacyDatabaseFile(tempDirectory);
      final key = await keyStore.readOrCreateKey();
      await _seedLegacyVersion1Database(
        databaseFile: legacyDatabaseFile,
        key: key,
        rows: const <Map<String, Object?>>[
          <String, Object?>{
            'id': 1,
            'raw_transcript': 'saved raw',
            'cleaned_text': 'saved clean',
            'is_draft': 0,
            'language': 'en-US',
            'created_at': 1000,
            'word_count': 2,
            'audio_path': null,
          },
          <String, Object?>{
            'id': 2,
            'raw_transcript': '',
            'cleaned_text': null,
            'is_draft': 1,
            'language': 'fr-FR',
            'created_at': 2000,
            'word_count': 0,
            'audio_path': '/tmp/draft-audio.m4a',
          },
        ],
      );

      final database = await LocalEntryDatabase.open(
        keyStore: keyStore,
        databaseFile: _databaseFile(tempDirectory),
      );
      final repository = EntryRepositoryImpl(
        entryDao: database.entryDao,
        tagDao: database.tagDao,
        clock: FakeClock(_ts(2026, 6, 8)),
        storeDraftAudioPath: (audioPath) async => audioPath,
        resolveDraftAudioPath: (storedAudioPath) async => storedAudioPath,
      );

      final entries = await repository.watchAllEntries().first;
      final currentColumns = await database
          .customSelect('PRAGMA table_info(entries);')
          .get();
      final currentColumnNames = currentColumns
          .map((row) => row.data['name'] as String)
          .toList(growable: false);

      expect(entries, isEmpty);
      expect(currentColumnNames, contains('type'));
      expect(currentColumnNames, isNot(contains('is_draft')));
      expect(await legacyDatabaseFile.exists(), isTrue);
      expect(await _databaseFile(tempDirectory).exists(), isTrue);
      await database.close();
    },
  );

  test('entry schema rejects invalid persisted type values', () async {
    final harness = await _createHarness(
      directory: tempDirectory,
      storage: FakeSecureKeyValueStore(),
      clock: FakeClock(_ts(2026, 6, 8)),
      random: Random(14),
    );
    addTearDown(harness.database.close);

    await expectLater(
      harness.database.customStatement('''
        INSERT INTO entries (
          raw_transcript,
          cleaned_text,
          type,
          language,
          created_at,
          word_count,
          audio_path
        ) VALUES (
          'bad entry',
          NULL,
          'mystery',
          'en-US',
          ${_ts(2026, 6, 8)},
          2,
          NULL
        );
      '''),
      throwsA(
        predicate(
          (error) =>
              error.toString().contains('CHECK constraint failed') ||
              error.toString().contains('constraint failed'),
          'constraint failure for invalid entry type',
        ),
      ),
    );
  });

  test('repository rejects corrupted current-shape rows with unsupported type values', () async {
    final storage = FakeSecureKeyValueStore();
    final keyStore = DatabaseKeyStore(storage, random: Random(15));
    final databaseFile = _databaseFile(tempDirectory);
    final key = await keyStore.readOrCreateKey();
    await _seedCorruptedCurrentSchemaDatabase(
      databaseFile: databaseFile,
      key: key,
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'id': 1,
          'raw_transcript': 'bad entry',
          'cleaned_text': null,
          'type': 'mystery',
          'language': 'en-US',
          'created_at': 1000,
          'word_count': 2,
          'audio_path': null,
        },
      ],
    );

    final database = await LocalEntryDatabase.open(
      keyStore: keyStore,
      databaseFile: databaseFile,
    );
    final repository = EntryRepositoryImpl(
      entryDao: database.entryDao,
      tagDao: database.tagDao,
      clock: FakeClock(_ts(2026, 6, 8)),
      storeDraftAudioPath: (audioPath) async => audioPath,
      resolveDraftAudioPath: (storedAudioPath) async => storedAudioPath,
    );

    await expectLater(
      repository.getEntryById(1),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('unsupported persisted type'),
        ),
      ),
    );
    await database.close();
  });

  test('repository fails explicitly when a corrupted current-shape row has a null type', () async {
    final storage = FakeSecureKeyValueStore();
    final keyStore = DatabaseKeyStore(storage, random: Random(16));
    final databaseFile = _databaseFile(tempDirectory);
    final key = await keyStore.readOrCreateKey();
    await _seedCorruptedCurrentSchemaDatabase(
      databaseFile: databaseFile,
      key: key,
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'id': 1,
          'raw_transcript': 'bad entry',
          'cleaned_text': null,
          'type': null,
          'language': 'en-US',
          'created_at': 1000,
          'word_count': 2,
          'audio_path': null,
        },
      ],
    );

    final database = await LocalEntryDatabase.open(
      keyStore: keyStore,
      databaseFile: databaseFile,
    );
    final repository = EntryRepositoryImpl(
      entryDao: database.entryDao,
      tagDao: database.tagDao,
      clock: FakeClock(_ts(2026, 6, 8)),
      storeDraftAudioPath: (audioPath) async => audioPath,
      resolveDraftAudioPath: (storedAudioPath) async => storedAudioPath,
    );

    await expectLater(repository.getEntryById(1), throwsA(isA<Object>()));
    await database.close();
  });

  test(
    'creates an encrypted database file whose plaintext transcript is absent',
    () async {
      final harness = await _createHarness(
        directory: tempDirectory,
        storage: FakeSecureKeyValueStore(),
        clock: FakeClock(_ts(2026, 6, 8)),
        random: Random(2),
      );

      await harness.repository.saveEntry('very secret journal line', 'en-US');
      await harness.database.close();

      final fileContents = utf8.decode(
        await harness.databaseFile.readAsBytes(),
        allowMalformed: true,
      );

      expect(await harness.databaseFile.exists(), isTrue);
      expect(fileContents, isNot(contains('very secret journal line')));
    },
  );

  test(
    'fails to open an existing database after key loss without replacing it',
    () async {
      final initialStorage = FakeSecureKeyValueStore();
      final initialHarness = await _createHarness(
        directory: tempDirectory,
        storage: initialStorage,
        clock: FakeClock(_ts(2026, 6, 8)),
        random: Random(3),
      );
      await initialHarness.repository.saveEntry(
        'persisted before key loss',
        'en-US',
      );
      await initialHarness.database.close();

      final lostKeyStorage = FakeSecureKeyValueStore();
      await expectLater(
        LocalEntryDatabase.open(
          keyStore: DatabaseKeyStore(lostKeyStorage, random: Random(4)),
          databaseFile: _databaseFile(tempDirectory),
        ),
        throwsA(isA<Exception>()),
      );

      expect(await initialHarness.databaseFile.exists(), isTrue);

      final reopenedWithOriginalKey = await _createHarness(
        directory: tempDirectory,
        storage: initialStorage,
        clock: FakeClock(_ts(2026, 6, 9)),
        random: Random(3),
      );
      final entries = await reopenedWithOriginalKey.repository
          .watchAllEntries()
          .first;

      expect(entries, hasLength(1));
      expect(entries.single.rawTranscript, 'persisted before key loss');
      await reopenedWithOriginalKey.database.close();
    },
  );

  test('preserves existing database artifacts when open fails', () async {
    final harness = await _createHarness(
      directory: tempDirectory,
      storage: FakeSecureKeyValueStore(),
      clock: FakeClock(_ts(2026, 6, 8)),
      random: Random(4),
    );
    await harness.repository.saveEntry('persisted entry', 'en-US');
    await harness.database.close();

    final databaseFile = harness.databaseFile;
    final walFile = File('${databaseFile.path}-wal');
    final shmFile = File('${databaseFile.path}-shm');
    final journalFile = File('${databaseFile.path}-journal');
    await walFile.writeAsString('wal');
    await shmFile.writeAsString('shm');
    await journalFile.writeAsString('journal');

    await expectLater(
      LocalEntryDatabase.open(
        keyStore: DatabaseKeyStore(
          FakeSecureKeyValueStore(),
          random: Random(5),
        ),
        databaseFile: databaseFile,
        verifyCipherSupport: (_) {
          throw StateError('simulated existing database open failure');
        },
      ),
      throwsA(
        predicate(
          (error) => error.toString().contains(
            'simulated existing database open failure',
          ),
          'error containing the injected failure message',
        ),
      ),
    );

    expect(await databaseFile.exists(), isTrue);
    expect(await walFile.exists(), isTrue);
    expect(await shmFile.exists(), isTrue);
    expect(await journalFile.exists(), isTrue);
  });

  test(
    'preserves database artifacts when the database file is corrupted',
    () async {
      final storage = FakeSecureKeyValueStore();
      final harness = await _createHarness(
        directory: tempDirectory,
        storage: storage,
        clock: FakeClock(_ts(2026, 6, 8)),
        random: Random(12),
      );
      await harness.repository.saveEntry('entry before corruption', 'en-US');
      await harness.database.close();

      final databaseFile = harness.databaseFile;
      final originalBytes = await databaseFile.readAsBytes();
      expect(originalBytes, isNotEmpty);

      final corruptedBytes = Uint8List.fromList(originalBytes);
      final overwriteLength = min(32, corruptedBytes.length);
      for (var index = 0; index < overwriteLength; index++) {
        corruptedBytes[index] = 0xFF;
      }
      await databaseFile.writeAsBytes(corruptedBytes, flush: true);

      await expectLater(
        LocalEntryDatabase.open(
          keyStore: DatabaseKeyStore(storage, random: Random(12)),
          databaseFile: databaseFile,
        ),
        throwsA(isA<Exception>()),
      );

      expect(await databaseFile.exists(), isTrue);
    },
  );

  test(
    'startup bootstrap initializes the store and deletes stale drafts',
    () async {
      final storage = FakeSecureKeyValueStore();
      final keyStore = DatabaseKeyStore(storage, random: Random(5));
      final seedDatabase = await LocalEntryDatabase.open(
        keyStore: keyStore,
        databaseFile: _databaseFile(tempDirectory),
      );

      final oldClock = FakeClock(_ts(2026, 5, 20));
      final seedRepository = EntryRepositoryImpl(
        entryDao: seedDatabase.entryDao,
        tagDao: seedDatabase.tagDao,
        clock: oldClock,
        storeDraftAudioPath: (audioPath) async => audioPath,
        resolveDraftAudioPath: (storedAudioPath) async => storedAudioPath,
      );
      final staleAudioFile = File('${tempDirectory.path}/stale-audio.m4a');
      await staleAudioFile.writeAsString('audio');
      await seedRepository.saveAudioDraft(staleAudioFile.path, 'en-US');

      final freshClock = FakeClock(_ts(2026, 6, 6));
      final freshRepository = EntryRepositoryImpl(
        entryDao: seedDatabase.entryDao,
        tagDao: seedDatabase.tagDao,
        clock: freshClock,
        storeDraftAudioPath: (audioPath) async => audioPath,
        resolveDraftAudioPath: (storedAudioPath) async => storedAudioPath,
      );
      await freshRepository.saveDraft('keep me', 'en-US');
      await seedDatabase.close();

      final bootstrap = LocalEntryStartupBootstrap(
        keyStore: keyStore,
        clock: FakeClock(_ts(2026, 6, 8)),
        storeDraftAudioPath: (audioPath) async => audioPath,
        resolveDraftAudioPath: (storedAudioPath) async => storedAudioPath,
        openDatabase: (keyStore, file) =>
            LocalEntryDatabase.open(keyStore: keyStore, databaseFile: file),
      );

      final bootstrappedDatabase = await bootstrap.prepare(
        databaseFile: _databaseFile(tempDirectory),
      );
      final bootstrappedRepository = EntryRepositoryImpl(
        entryDao: bootstrappedDatabase.entryDao,
        tagDao: bootstrappedDatabase.tagDao,
        clock: const SystemClock(),
        storeDraftAudioPath: (audioPath) async => audioPath,
        resolveDraftAudioPath: (storedAudioPath) async => storedAudioPath,
      );

      final remainingDrafts = await bootstrappedRepository.getPendingDrafts();

      expect(remainingDrafts, hasLength(1));
      expect(remainingDrafts.single.rawTranscript, 'keep me');
      expect(await staleAudioFile.exists(), isFalse);
      await bootstrappedDatabase.close();
    },
  );

  test('reopens a seeded database with 1000 entries within a host-side startup budget', () async {
    final storage = FakeSecureKeyValueStore();
    final keyStore = DatabaseKeyStore(storage, random: Random(6));
    final file = _databaseFile(tempDirectory);
    final seedDatabase = await LocalEntryDatabase.open(
      keyStore: keyStore,
      databaseFile: file,
    );
    final createdAt = _ts(2026, 6, 8);

    await seedDatabase.batch((batch) {
      batch.insertAll(
        seedDatabase.entryRecords,
        List<EntryRecordsCompanion>.generate(
          1000,
          (index) => EntryRecordsCompanion.insert(
            rawTranscript: 'seeded entry $index',
            type: EntryType.saved.name,
            language: 'en-US',
            createdAt: createdAt,
            cleanedText: const Value.absent(),
            wordCount: const Value(3),
            audioPath: const Value.absent(),
          ),
        ),
      );
    });
    await seedDatabase.close();

    final reopenStopwatch = Stopwatch()..start();
    final reopenedDatabase = await LocalEntryDatabase.open(
      keyStore: keyStore,
      databaseFile: file,
    );
    reopenStopwatch.stop();

    final countRow = await reopenedDatabase
        .customSelect('SELECT COUNT(*) AS count FROM entries;')
        .getSingle();
    final entryCount = countRow.data['count'] as int;
    debugPrint(
      'LocalEntryDatabase reopen with 1000 entries took ${reopenStopwatch.elapsedMilliseconds}ms.',
    );

    expect(entryCount, 1000);
    expect(reopenStopwatch.elapsed, lessThan(const Duration(seconds: 3)));
    await reopenedDatabase.close();
  });
}

class _DatabaseHarness {
  _DatabaseHarness({
    required this.database,
    required this.repository,
    required this.databaseFile,
  });

  final LocalEntryDatabase database;
  final EntryRepository repository;
  final File databaseFile;
}

Future<_DatabaseHarness> _createHarness({
  required Directory directory,
  required FakeSecureKeyValueStore storage,
  required Clock clock,
  required Random random,
}) async {
  final keyStore = DatabaseKeyStore(storage, random: random);
  final databaseFile = _databaseFile(directory);
  final database = await LocalEntryDatabase.open(
    keyStore: keyStore,
    databaseFile: databaseFile,
  );
  final repository = EntryRepositoryImpl(
    entryDao: database.entryDao,
    tagDao: database.tagDao,
    clock: clock,
  );

  return _DatabaseHarness(
    database: database,
    repository: repository,
    databaseFile: databaseFile,
  );
}

File _databaseFile(Directory directory) =>
    File('${directory.path}/${LocalEntryDatabase.databaseFileName}');

File _legacyDatabaseFile(Directory directory) =>
    File('${directory.path}/$_legacyDatabaseFileName');

int _ts(int year, int month, int day) =>
    DateTime(year, month, day).millisecondsSinceEpoch;

Future<void> _seedLegacyVersion1Database({
  required File databaseFile,
  required String key,
  required List<Map<String, Object?>> rows,
}) async {
  final rawDb = sqlite.sqlite3.open(databaseFile.path);
  try {
    rawDb.execute("PRAGMA key = '${_escapePragmaValue(key)}';");
    rawDb.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        raw_transcript TEXT NOT NULL,
        cleaned_text TEXT NULL,
        is_draft INTEGER NOT NULL CHECK (is_draft IN (0, 1)),
        language TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        word_count INTEGER NOT NULL DEFAULT 0,
        audio_path TEXT NULL
      );
    ''');
    rawDb.execute('PRAGMA user_version = 1;');

    final statement = rawDb.prepare('''
      INSERT INTO entries (
        id,
        raw_transcript,
        cleaned_text,
        is_draft,
        language,
        created_at,
        word_count,
        audio_path
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    ''');
    try {
      for (final row in rows) {
        statement.execute(<Object?>[
          row['id'],
          row['raw_transcript'],
          row['cleaned_text'],
          row['is_draft'],
          row['language'],
          row['created_at'],
          row['word_count'],
          row['audio_path'],
        ]);
      }
    } finally {
      statement.close();
    }
  } finally {
    rawDb.close();
  }
}

Future<void> _seedCorruptedCurrentSchemaDatabase({
  required File databaseFile,
  required String key,
  required List<Map<String, Object?>> rows,
}) async {
  final rawDb = sqlite.sqlite3.open(databaseFile.path);
  try {
    rawDb.execute("PRAGMA key = '${_escapePragmaValue(key)}';");
    rawDb.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        raw_transcript TEXT NOT NULL,
        cleaned_text TEXT NULL,
        type TEXT NULL,
        language TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        word_count INTEGER NOT NULL DEFAULT 0,
        audio_path TEXT NULL
      );
    ''');
    rawDb.execute('PRAGMA user_version = 1;');

    final statement = rawDb.prepare('''
      INSERT INTO entries (
        id,
        raw_transcript,
        cleaned_text,
        type,
        language,
        created_at,
        word_count,
        audio_path
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    ''');
    try {
      for (final row in rows) {
        statement.execute(<Object?>[
          row['id'],
          row['raw_transcript'],
          row['cleaned_text'],
          row['type'],
          row['language'],
          row['created_at'],
          row['word_count'],
          row['audio_path'],
        ]);
      }
    } finally {
      statement.close();
    }
  } finally {
    rawDb.close();
  }
}

String _escapePragmaValue(String value) => value.replaceAll("'", "''");
