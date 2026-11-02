import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/system_clock.dart';
import '../../domain/repository/entry_repository.dart';
import 'database_key_store.dart';
import 'draft_audio_path_codec.dart';
import 'entry_repository_impl.dart';
import 'local_entry_database.dart';

class LocalEntryStartupBootstrap {
  LocalEntryStartupBootstrap({
    required this.keyStore,
    required this.clock,
    StoreDraftAudioPathCallback? storeDraftAudioPath,
    ResolveDraftAudioPathCallback? resolveDraftAudioPath,
    Future<LocalEntryDatabase> Function(DatabaseKeyStore keyStore, File? file)?
    openDatabase,
  }) : storeDraftAudioPath = storeDraftAudioPath ?? DraftAudioPathCodec.store,
       resolveDraftAudioPath =
           resolveDraftAudioPath ?? DraftAudioPathCodec.resolve,
       openDatabase =
           openDatabase ??
           ((keyStore, file) =>
               LocalEntryDatabase.open(keyStore: keyStore, databaseFile: file));

  final DatabaseKeyStore keyStore;
  final Clock clock;
  final StoreDraftAudioPathCallback storeDraftAudioPath;
  final ResolveDraftAudioPathCallback resolveDraftAudioPath;
  final Future<LocalEntryDatabase> Function(
    DatabaseKeyStore keyStore,
    File? file,
  )
  openDatabase;

  Future<LocalEntryDatabase> prepare({File? databaseFile}) async {
    final database = await openDatabase(keyStore, databaseFile);
    final repository = EntryRepositoryImpl(
      entryDao: database.entryDao,
      tagDao: database.tagDao,
      clock: clock,
      storeDraftAudioPath: storeDraftAudioPath,
      resolveDraftAudioPath: resolveDraftAudioPath,
    );
    await repository.deleteStaleDrafts();
    return database;
  }
}

final clockProvider = Provider<Clock>((ref) => const SystemClock());

Future<LocalEntryDatabase> bootstrapLocalEntryDatabase({
  FlutterSecureStorage secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  ),
  Clock clock = const SystemClock(),
  File? databaseFile,
}) {
  final bootstrap = LocalEntryStartupBootstrap(
    keyStore: DatabaseKeyStore(FlutterSecureKeyValueStore(secureStorage)),
    clock: clock,
  );
  return bootstrap.prepare(databaseFile: databaseFile);
}

final localEntryDatabaseProvider = Provider<LocalEntryDatabase>(
  (ref) => throw StateError(
    'LocalEntryDatabase must be bootstrapped before the app ProviderContainer is created.',
  ),
);

final entryRepositoryProvider = Provider<EntryRepository>(
  (ref) => EntryRepositoryImpl(
    entryDao: ref.watch(localEntryDatabaseProvider).entryDao,
    tagDao: ref.watch(localEntryDatabaseProvider).tagDao,
    clock: ref.watch(clockProvider),
  ),
);
