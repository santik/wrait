import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:wrait/data/entries/local_entry_database.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('wrait-db-path-test');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('uses the documents directory on non-iOS platforms', () async {
    final documentsDirectory = await Directory(
      path.join(tempDirectory.path, 'documents'),
    ).create(recursive: true);

    final databaseFile = await LocalEntryDatabase.defaultDatabaseFile(
      getDocumentsDirectory: () async => documentsDirectory,
      isIos: false,
    );

    expect(
      databaseFile.path,
      path.join(documentsDirectory.path, LocalEntryDatabase.databaseFileName),
    );
  });

  test('uses application support on iOS', () async {
    final documentsDirectory = await Directory(
      path.join(tempDirectory.path, 'documents'),
    ).create(recursive: true);
    final supportDirectory = await Directory(
      path.join(tempDirectory.path, 'support'),
    ).create(recursive: true);

    final databaseFile = await LocalEntryDatabase.defaultDatabaseFile(
      getDocumentsDirectory: () async => documentsDirectory,
      getSupportDirectory: () async => supportDirectory,
      isIos: true,
    );

    expect(
      databaseFile.path,
      path.join(supportDirectory.path, LocalEntryDatabase.databaseFileName),
    );
  });
}
