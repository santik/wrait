import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/local_entry_database.dart';

import '../../test_doubles/fake_secure_storage.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tempDirectory;
  late File dbFile;
  late FakeSecureKeyValueStore secureStore;
  late DatabaseKeyStore keyStore;
  late String encryptionKey;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('wrait-migration');
    dbFile = File('${tempDirectory.path}/test.sqlite');
    secureStore = FakeSecureKeyValueStore();
    keyStore = DatabaseKeyStore(secureStore, random: Random(42));
    encryptionKey = await keyStore.readOrCreateKey();
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  void createV1Database() {
    final rawDb = sqlite.sqlite3.open(dbFile.path);
    try {
      rawDb.execute("PRAGMA key = '${encryptionKey.replaceAll("'", "''")}';");
      rawDb.execute('''
        CREATE TABLE entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          raw_transcript TEXT NOT NULL,
          cleaned_text TEXT,
          type TEXT NOT NULL CHECK (type IN ('draft', 'saved')),
          language TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          word_count INTEGER NOT NULL DEFAULT 0,
          audio_path TEXT
        );
      ''');
      rawDb.execute('PRAGMA user_version = 1;');
    } finally {
      rawDb.dispose();
    }
  }

  test('v1 to v2 migration creates tags and entry_tags tables', () async {
    createV1Database();

    // Insert test entries into the v1 database.
    final rawDb = sqlite.sqlite3.open(dbFile.path);
    try {
      rawDb.execute("PRAGMA key = '${encryptionKey.replaceAll("'", "''")}';");
      rawDb.execute('''
        INSERT INTO entries (raw_transcript, cleaned_text, type, language, created_at, word_count)
        VALUES ('hello world', 'Hello World.', 'saved', 'en', 1700000000000, 2);
      ''');
      rawDb.execute('''
        INSERT INTO entries (raw_transcript, type, language, created_at, word_count)
        VALUES ('draft text', 'draft', 'de', 1700000100000, 2);
      ''');
    } finally {
      rawDb.dispose();
    }

    // Open with the current schema (v2), which triggers migration.
    final database = await LocalEntryDatabase.open(
      keyStore: keyStore,
      databaseFile: dbFile,
    );

    try {
      // Verify existing entries survived migration.
      final entries = await database.entryDao.watchAllEntries().first;
      expect(entries, hasLength(2));

      final saved = entries.firstWhere((e) => e.type == 'saved');
      expect(saved.rawTranscript, 'hello world');
      expect(saved.cleanedText, 'Hello World.');
      expect(saved.language, 'en');

      final draft = entries.firstWhere((e) => e.type == 'draft');
      expect(draft.rawTranscript, 'draft text');
      expect(draft.language, 'de');

      // Verify tags table exists and works.
      final tagId = await database.tagDao.insertTag(
        const TagRecordsCompanion(name: Value('work')),
      );
      expect(tagId, greaterThan(0));

      final tags = await database.tagDao.getAllTags();
      expect(tags, hasLength(1));
      expect(tags.first.name, 'work');

      // Verify entry_tags table exists and works.
      await database.tagDao.setTagsForEntry(saved.id, [tagId]);
      final entryTags = await database.tagDao.getTagsForEntry(saved.id);
      expect(entryTags, hasLength(1));
      expect(entryTags.first.name, 'work');

      // Tag itself should survive entry deletion.
      await database.entryDao.deleteEntryById(saved.id);
      final allTags = await database.tagDao.getAllTags();
      expect(allTags, hasLength(1));
    } finally {
      await database.close();
    }
  });

  test('v1 to v2 migration preserves empty database', () async {
    createV1Database();

    final database = await LocalEntryDatabase.open(
      keyStore: keyStore,
      databaseFile: dbFile,
    );

    try {
      final entries = await database.entryDao.watchAllEntries().first;
      expect(entries, isEmpty);

      final tags = await database.tagDao.getAllTags();
      expect(tags, isEmpty);
    } finally {
      await database.close();
    }
  });
}
