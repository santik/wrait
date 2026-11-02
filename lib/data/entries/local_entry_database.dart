import 'dart:developer' as developer;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'database_key_store.dart';

part 'entry_dao.dart';
part 'tag_dao.dart';
part 'local_entry_database.g.dart';

typedef CipherSupportVerifier = void Function(sqlite.Database rawDb);
typedef DirectoryResolver = Future<Directory> Function();

class EntryRecords extends Table {
  @override
  String get tableName => 'entries';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get rawTranscript => text().named('raw_transcript')();
  TextColumn get cleanedText => text().named('cleaned_text').nullable()();
  TextColumn get type =>
      text().customConstraint("NOT NULL CHECK (type IN ('draft', 'saved'))")();
  TextColumn get language => text()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get wordCount =>
      integer().named('word_count').withDefault(const Constant(0))();
  TextColumn get audioPath => text().named('audio_path').nullable()();
}

class TagRecords extends Table {
  @override
  String get tableName => 'tags';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().customConstraint('NOT NULL UNIQUE COLLATE NOCASE')();
}

class EntryTagRecords extends Table {
  @override
  String get tableName => 'entry_tags';

  IntColumn get entryId => integer()
      .named('entry_id')
      .customConstraint('NOT NULL REFERENCES entries(id) ON DELETE CASCADE')();
  IntColumn get tagId => integer()
      .named('tag_id')
      .customConstraint('NOT NULL REFERENCES tags(id) ON DELETE CASCADE')();

  @override
  Set<Column> get primaryKey => {entryId, tagId};
}

@DriftDatabase(tables: [EntryRecords, TagRecords, EntryTagRecords], daos: [EntryDao, TagDao])
class LocalEntryDatabase extends _$LocalEntryDatabase {
  LocalEntryDatabase(super.e);

  // US-037 intentionally rolls out the type-based entry store as a fresh local
  // database instead of migrating the legacy is_draft-based file in place.
  static const databaseFileName = 'wrait_entries_v2.sqlite';

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(tagRecords);
        await migrator.createTable(entryTagRecords);
      }
    },
  );

  static Future<LocalEntryDatabase> open({
    required DatabaseKeyStore keyStore,
    File? databaseFile,
    bool logStatements = false,
    CipherSupportVerifier verifyCipherSupport = _ensureCipherSupport,
  }) async {
    final dbFile = databaseFile ?? await defaultDatabaseFile();
    final key = await keyStore.readOrCreateKey();
    final existedBefore = await dbFile.exists();
    final openStopwatch = Stopwatch()..start();

    try {
      final database = await _openVerified(
        dbFile,
        key,
        logStatements: logStatements,
        verifyCipherSupport: verifyCipherSupport,
      );
      developer.log(
        'Encrypted database opened in ${openStopwatch.elapsedMilliseconds}ms (existing=$existedBefore).',
        name: 'LocalEntryDatabase',
      );
      return database;
    } catch (error, stackTrace) {
      developer.log(
        existedBefore
            ? 'Encrypted database open failed after ${openStopwatch.elapsedMilliseconds}ms; existing artifacts preserved.'
            : 'Encrypted database open failed after ${openStopwatch.elapsedMilliseconds}ms.',
        name: 'LocalEntryDatabase',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<File> defaultDatabaseFile({
    DirectoryResolver? getDocumentsDirectory,
    DirectoryResolver? getSupportDirectory,
    bool? isIos,
  }) async {
    final resolveDocumentsDirectory =
        getDocumentsDirectory ?? getApplicationDocumentsDirectory;
    final documentsDirectory = await resolveDocumentsDirectory();
    final useIosSupportPath = isIos ?? Platform.isIOS;
    if (!useIosSupportPath) {
      return File(path.join(documentsDirectory.path, databaseFileName));
    }

    final supportDirectory =
        await (getSupportDirectory ?? getApplicationSupportDirectory)();
    return File(path.join(supportDirectory.path, databaseFileName));
  }

  // Destructive utility for explicit reset flows only. Do not call this from
  // automatic open-failure handling.
  static Future<void> deleteDatabaseArtifacts(File databaseFile) async {
    final candidates = <String>[
      databaseFile.path,
      '${databaseFile.path}-wal',
      '${databaseFile.path}-shm',
      '${databaseFile.path}-journal',
    ];

    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<LocalEntryDatabase> _openVerified(
    File databaseFile,
    String key, {
    required bool logStatements,
    required CipherSupportVerifier verifyCipherSupport,
  }) async {
    // Real Android installs were stalling before the first Flutter frame while
    // opening the encrypted store through createInBackground. Opening directly
    // keeps bootstrap behavior deterministic across host tests and device runs.
    final database = LocalEntryDatabase(
      NativeDatabase(
        databaseFile,
        logStatements: logStatements,
        setup: (rawDb) {
          verifyCipherSupport(rawDb);
          rawDb.execute("PRAGMA key = '${_escapePragmaValue(key)}';");
        },
      ),
    );

    await database
        .customSelect('SELECT COUNT(*) AS count FROM sqlite_master;')
        .getSingle();
    return database;
  }
}

void _ensureCipherSupport(sqlite.Database database) {
  final result = database.select('PRAGMA cipher;');
  if (result.isEmpty) {
    throw StateError(
      'Encrypted SQLite runtime unavailable. Expected the sqlite3mc build with cipher support.',
    );
  }
}

String _escapePragmaValue(String value) => value.replaceAll("'", "''");
