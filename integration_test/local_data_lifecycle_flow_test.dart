import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/core/time/system_clock.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/draft_audio_path_codec.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/data/launch/app_launch_providers.dart';
import 'package:wrait/data/preferences/platform_device_id_provider.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/transcription/transcription_providers.dart';
import 'package:wrait/data/transcription/transcription_service.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/domain/usecase/register_device_on_launch_use_case.dart';
import 'package:wrait/main.dart';

import '../test/test_doubles/fake_secure_storage.dart';

const _scenario = String.fromEnvironment(
  'US030_SCENARIO',
  defaultValue: 'isolated',
);
const _platformRawDeviceId = 'us030-platform-device';
const _savedRawTranscript = 'raw transcript seed';
const _savedCleanedText = 'cleaned transcript seed';
const _draftLanguage = 'en-US';
const _textDraftTranscript = 'preserved text draft';
const _draftAudioContents = 'draft audio bytes';
const _platformSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: true),
);
const _savedLanguage = 'en-US';
const _deviceIdSalt = 'wrait-v1';
const _seededStatePrefsPrefix = 'us030.seeded_state.';
const _retriedRawTranscript = 'audio retry transcript';
const _retriedCleanedText = 'Audio retry cleaned';
const _retriedDetectedLanguage = 'fr-FR';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  switch (_scenario) {
    case 'platform-seed':
      _registerPlatformSeedScenario();
      break;
    case 'platform-update-verify':
      _registerPlatformUpdateVerifyScenario();
      break;
    case 'platform-update-retry-verify':
      _registerPlatformUpdateRetryVerifyScenario();
      break;
    case 'platform-fresh-state':
      _registerPlatformFreshStateScenario();
      break;
    default:
      _registerIsolatedScenario();
      break;
  }
}

void _registerIsolatedScenario() {
  testWidgets(
    'isolated lifecycle preserves update state and resets after explicit data removal',
    (tester) async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'wrait-us030-lifecycle',
      );
      final secureStorage = FakeSecureKeyValueStore();
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();

      _LifecycleRuntime? runtime;
      try {
        final seedClock = _MutableClock(DateTime(2026, 6, 20, 9));
        runtime = await _createIsolatedRuntime(
          tempDirectory: tempDirectory,
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          clock: seedClock,
          initialLocation: '/entries',
        );
        final seededState = await _seedLifecycleState(
          database: runtime.database,
          repository: runtime.container.read(entryRepositoryProvider),
          preferencesRepository: runtime.container.read(
            preferencesRepositoryProvider,
          ),
          clock: seedClock,
          draftAudioFile: await _isolatedDraftAudioFile(),
        );
        await runtime.dispose(deleteTempDirectory: false);

        runtime = await _createIsolatedRuntime(
          tempDirectory: tempDirectory,
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          clock: _MutableClock(DateTime(2026, 6, 20, 10)),
          initialLocation: '/entries',
        );

        await _expectLifecycleState(
          database: runtime.database,
          repository: runtime.container.read(entryRepositoryProvider),
          preferencesRepository: runtime.container.read(
            preferencesRepositoryProvider,
          ),
          expected: seededState,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: runtime.container,
            child: const WraitApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
        expect(find.textContaining(_savedCleanedText), findsOneWidget);

        await runtime.dispose(deleteTempDirectory: false);

        await _clearIsolatedState(
          tempDirectory: tempDirectory,
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
        );

        runtime = await _createIsolatedRuntime(
          tempDirectory: tempDirectory,
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          clock: _MutableClock(DateTime(2026, 6, 20, 11)),
          initialLocation: '/entries',
        );

        await _expectFreshState(
          repository: runtime.container.read(entryRepositoryProvider),
          preferencesRepository: runtime.container.read(
            preferencesRepositoryProvider,
          ),
        );
      } finally {
        await runtime?.dispose();
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      }
    },
  );
}

void _registerPlatformSeedScenario() {
  testWidgets('platform seed scenario prepares persistent update data', (
    tester,
  ) async {
    await _clearPlatformState();

    final seedClock = _MutableClock(DateTime(2026, 6, 20, 12));
    final runtime = await _createPlatformRuntime(clock: seedClock);
    try {
      final seededState = await _seedLifecycleState(
        database: runtime.database,
        repository: runtime.container.read(entryRepositoryProvider),
        preferencesRepository: runtime.container.read(
          preferencesRepositoryProvider,
        ),
        clock: seedClock,
        draftAudioFile: await _platformDraftAudioFile(),
      );
      await _persistPlatformExpectedState(seededState);
      await _expectLifecycleState(
        database: runtime.database,
        repository: runtime.container.read(entryRepositoryProvider),
        preferencesRepository: runtime.container.read(
          preferencesRepositoryProvider,
        ),
        expected: seededState,
      );
    } finally {
      await runtime.dispose(deleteTempDirectory: false);
    }
  });
}

void _registerPlatformUpdateVerifyScenario() {
  testWidgets('platform update verify scenario keeps local data intact', (
    tester,
  ) async {
    final runtime = await _createPlatformRuntime();

    try {
      await _expectLifecycleState(
        database: runtime.database,
        repository: runtime.container.read(entryRepositoryProvider),
        preferencesRepository: runtime.container.read(
          preferencesRepositoryProvider,
        ),
        expected: await _loadPlatformExpectedState(),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: runtime.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
      expect(find.textContaining(_savedCleanedText), findsOneWidget);
    } finally {
      await runtime.dispose(deleteTempDirectory: false);
    }
  });
}

void _registerPlatformUpdateRetryVerifyScenario() {
  testWidgets(
    'platform update retry verify scenario finalizes the preserved audio draft after launch',
    (tester) async {
      final transcriptionService = _LaunchRetryTranscriptionService();
      final cleanupCallbackHolder = _CleanupCallbackHolder();
      cleanupCallbackHolder
          .callback = ({required transcript, required language}) async {
        if (transcript == _textDraftTranscript) {
          expect(language, _draftLanguage);
          return const backend.CleanupSuccess(
            cleanedText: 'Recovered text draft',
          );
        }
        expect(transcript, _retriedRawTranscript);
        expect(language, _retriedDetectedLanguage);
        return const backend.CleanupSuccess(cleanedText: _retriedCleanedText);
      };

      final runtime = await _createPlatformRuntime(
        overrides: [
          registerDeviceOnLaunchUseCaseProvider.overrideWithValue(
            _StubRegisterDeviceOnLaunchUseCase(
              LaunchDeviceRegistrationResult.success,
            ),
          ),
          transcriptionServiceProvider.overrideWithValue(transcriptionService),
          cleanupTranscriptCallbackProvider.overrideWithValue(({
            required transcript,
            required language,
          }) {
            return cleanupCallbackHolder.call(
              transcript: transcript,
              language: language,
            );
          }),
        ],
      );

      try {
        final expected = await _loadPlatformExpectedState();
        await _expectLifecycleState(
          database: runtime.database,
          repository: runtime.container.read(entryRepositoryProvider),
          preferencesRepository: runtime.container.read(
            preferencesRepositoryProvider,
          ),
          expected: expected,
        );

        transcriptionService.nextDraftResults.add(
          const TranscriptionSuccess(
            transcript: _retriedRawTranscript,
            detectedLanguage: _retriedDetectedLanguage,
          ),
        );

        await runtime.container.read(appLaunchWorkUseCaseProvider).call();

        final finalizedEntry = await runtime.container
            .read(entryRepositoryProvider)
            .getEntryById(expected.draftEntryId);
        final rawFinalizedEntry = await runtime.database.entryDao.getEntryById(
          expected.draftEntryId,
        );

        final recoveredText = await runtime.container
            .read(entryRepositoryProvider)
            .getEntryById(expected.textDraftEntryId);
        expect(recoveredText!.type, EntryType.saved);
        expect(recoveredText.cleanedText, 'Recovered text draft');
        expect(finalizedEntry, isNotNull);
        expect(finalizedEntry!.type, EntryType.saved);
        expect(finalizedEntry.rawTranscript, _retriedRawTranscript);
        expect(finalizedEntry.cleanedText, _retriedCleanedText);
        expect(finalizedEntry.language, _retriedDetectedLanguage);
        expect(finalizedEntry.audioPath, isNull);
        expect(rawFinalizedEntry, isNotNull);
        expect(rawFinalizedEntry!.audioPath, isNull);
        expect(transcriptionService.transcribedAudioPaths, [
          expected.draftAudioPath,
        ]);
        expect(await File(expected.draftAudioPath).exists(), isFalse);
      } finally {
        await runtime.dispose(deleteTempDirectory: false);
      }
    },
  );
}

void _registerPlatformFreshStateScenario() {
  testWidgets('platform fresh state scenario starts without prior diary data', (
    tester,
  ) async {
    final runtime = await _createPlatformRuntime();

    try {
      await _expectFreshState(
        repository: runtime.container.read(entryRepositoryProvider),
        preferencesRepository: runtime.container.read(
          preferencesRepositoryProvider,
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: runtime.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('entryListEmptyState')), findsOneWidget);
    } finally {
      await runtime.dispose(deleteTempDirectory: false);
    }
  });
}

class _LifecycleRuntime {
  _LifecycleRuntime({
    required this.container,
    required this.database,
    this.tempDirectory,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory? tempDirectory;

  Future<void> dispose({bool deleteTempDirectory = true}) async {
    container.dispose();
    await database.close();
    if (deleteTempDirectory && tempDirectory != null) {
      final directory = tempDirectory!;
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }
}

class _SeededLifecycleState {
  const _SeededLifecycleState({
    required this.savedEntryId,
    required this.draftEntryId,
    required this.textDraftEntryId,
    required this.storedDraftAudioReference,
    required this.savedCreatedAt,
    required this.draftCreatedAt,
    required this.savedLanguage,
    required this.draftLanguage,
    required this.savedRawTranscript,
    required this.savedCleanedText,
    required this.savedWordCount,
    required this.draftAudioPath,
    required this.storedDeviceId,
  });

  final int savedEntryId;
  final int draftEntryId;
  final int textDraftEntryId;
  final String storedDraftAudioReference;
  final int savedCreatedAt;
  final int draftCreatedAt;
  final String savedLanguage;
  final String draftLanguage;
  final String savedRawTranscript;
  final String savedCleanedText;
  final int savedWordCount;
  final String draftAudioPath;
  final String storedDeviceId;
}

class _MutableClock implements Clock {
  _MutableClock(DateTime seed) : _now = seed.millisecondsSinceEpoch;

  int _now;

  void advance(Duration duration) {
    _now += duration.inMilliseconds;
  }

  @override
  int now() => _now;
}

class _FakePlatformDeviceIdProvider implements PlatformDeviceIdProvider {
  const _FakePlatformDeviceIdProvider(this.value);

  final String value;

  @override
  Future<String?> getPlatformDeviceId() async => value;
}

Future<_LifecycleRuntime> _createIsolatedRuntime({
  required Directory tempDirectory,
  required FakeSecureKeyValueStore secureStorage,
  required SharedPreferences sharedPreferences,
  required Clock clock,
  required String initialLocation,
}) async {
  final database = await LocalEntryDatabase.open(
    keyStore: DatabaseKeyStore(secureStorage, random: Random(7)),
    databaseFile: File(
      '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
    ),
  );

  final container = createAppContainer(
    appConfig: _appConfig,
    entryDatabase: database,
    sharedPreferences: sharedPreferences,
    overrides: [
      appLockEnabledProvider.overrideWithValue(false),
      clockProvider.overrideWithValue(clock),
      appRouterProvider.overrideWithValue(
        buildAppRouter(initialLocation: initialLocation),
      ),
      platformDeviceIdProvider.overrideWithValue(
        const _FakePlatformDeviceIdProvider(_platformRawDeviceId),
      ),
    ],
  );

  return _LifecycleRuntime(
    container: container,
    database: database,
    tempDirectory: tempDirectory,
  );
}

Future<_LifecycleRuntime> _createPlatformRuntime({
  Clock? clock,
  Iterable overrides = const [],
}) async {
  final validationClock = clock ?? _MutableClock(DateTime(2026, 6, 20, 14));
  // Verify the old key before bootstrap can create a replacement on an error.
  if (_scenario.startsWith('platform-update')) {
    final prefs = await SharedPreferences.getInstance();
    final expectedDigest = prefs.getString(
      '${_seededStatePrefsPrefix}keyDigest',
    );
    final key = await _platformSecureStorage.read(
      key: DatabaseKeyStore.storageKey,
    );
    expect(
      expectedDigest != null &&
          key != null &&
          sha256.convert(utf8.encode(key)).toString() == expectedDigest,
      isTrue,
      reason: 'The original database key must survive the app update',
    );
  }
  final database = await bootstrapLocalEntryDatabase(clock: validationClock);
  final sharedPreferences = await SharedPreferences.getInstance();

  final container = createAppContainer(
    appConfig: _appConfig,
    entryDatabase: database,
    sharedPreferences: sharedPreferences,
    overrides: [
      appLockEnabledProvider.overrideWithValue(false),
      clockProvider.overrideWithValue(validationClock),
      appRouterProvider.overrideWithValue(
        buildAppRouter(initialLocation: '/entries'),
      ),
      platformDeviceIdProvider.overrideWithValue(
        const _FakePlatformDeviceIdProvider(_platformRawDeviceId),
      ),
      ...overrides,
    ],
  );

  return _LifecycleRuntime(container: container, database: database);
}

Future<_SeededLifecycleState> _seedLifecycleState({
  required LocalEntryDatabase database,
  required EntryRepository repository,
  required PreferencesRepository preferencesRepository,
  required _MutableClock clock,
  required File draftAudioFile,
}) async {
  if (await draftAudioFile.exists()) {
    await draftAudioFile.delete();
  }
  await draftAudioFile.parent.create(recursive: true);
  await draftAudioFile.writeAsString(_draftAudioContents);

  final savedEntryId = await repository.saveEntry(
    _savedRawTranscript,
    _savedLanguage,
  );
  await repository.updateEditedCleanedText(savedEntryId, _savedCleanedText);
  final savedEntry = await repository.getEntryById(savedEntryId);
  expect(savedEntry, isNotNull);

  clock.advance(const Duration(minutes: 1));
  final draftEntryId = await repository.saveAudioDraft(
    draftAudioFile.path,
    _draftLanguage,
  );
  final textDraftEntryId = await repository.saveDraft(
    _textDraftTranscript,
    _draftLanguage,
  );
  final rawDraftEntry = await database.entryDao.getEntryById(draftEntryId);
  expect(rawDraftEntry, isNotNull);
  await preferencesRepository.setHasEverRecorded(true);
  final storedDeviceId = await preferencesRepository.getDeviceId();

  return _SeededLifecycleState(
    savedEntryId: savedEntryId,
    draftEntryId: draftEntryId,
    textDraftEntryId: textDraftEntryId,
    storedDraftAudioReference: rawDraftEntry!.audioPath!,
    savedCreatedAt: savedEntry!.createdAt,
    draftCreatedAt: (await repository.getEntryById(draftEntryId))!.createdAt,
    savedLanguage: savedEntry.language,
    draftLanguage: _draftLanguage,
    savedRawTranscript: _savedRawTranscript,
    savedCleanedText: _savedCleanedText,
    savedWordCount: savedEntry.wordCount,
    draftAudioPath: draftAudioFile.path,
    storedDeviceId: storedDeviceId,
  );
}

Future<void> _persistPlatformExpectedState(_SeededLifecycleState state) async {
  final sharedPreferences = await SharedPreferences.getInstance();
  final key = await _platformSecureStorage.read(
    key: DatabaseKeyStore.storageKey,
  );
  expect(key != null && key.isNotEmpty, isTrue);
  await sharedPreferences.setString(
    '${_seededStatePrefsPrefix}keyDigest',
    sha256.convert(utf8.encode(key!)).toString(),
  );
  await sharedPreferences.setInt(
    '${_seededStatePrefsPrefix}textDraftEntryId',
    state.textDraftEntryId,
  );
  await sharedPreferences.setInt(
    '${_seededStatePrefsPrefix}savedEntryId',
    state.savedEntryId,
  );
  await sharedPreferences.setInt(
    '${_seededStatePrefsPrefix}draftEntryId',
    state.draftEntryId,
  );
  await sharedPreferences.setString(
    '${_seededStatePrefsPrefix}storedDraftAudioReference',
    state.storedDraftAudioReference,
  );
  await sharedPreferences.setInt(
    '${_seededStatePrefsPrefix}savedCreatedAt',
    state.savedCreatedAt,
  );
  await sharedPreferences.setInt(
    '${_seededStatePrefsPrefix}draftCreatedAt',
    state.draftCreatedAt,
  );
  await sharedPreferences.setString(
    '${_seededStatePrefsPrefix}savedLanguage',
    state.savedLanguage,
  );
  await sharedPreferences.setString(
    '${_seededStatePrefsPrefix}draftLanguage',
    state.draftLanguage,
  );
  await sharedPreferences.setString(
    '${_seededStatePrefsPrefix}savedRawTranscript',
    state.savedRawTranscript,
  );
  await sharedPreferences.setString(
    '${_seededStatePrefsPrefix}savedCleanedText',
    state.savedCleanedText,
  );
  await sharedPreferences.setInt(
    '${_seededStatePrefsPrefix}savedWordCount',
    state.savedWordCount,
  );
  await sharedPreferences.setString(
    '${_seededStatePrefsPrefix}storedDeviceId',
    state.storedDeviceId,
  );
}

Future<_SeededLifecycleState> _loadPlatformExpectedState() async {
  final sharedPreferences = await SharedPreferences.getInstance();

  int requireInt(String suffix) {
    final value = sharedPreferences.getInt('$_seededStatePrefsPrefix$suffix');
    if (value == null) {
      throw StateError('Missing persisted US-030 seeded-state int: $suffix');
    }
    return value;
  }

  String requireString(String suffix) {
    final value = sharedPreferences.getString(
      '$_seededStatePrefsPrefix$suffix',
    );
    if (value == null || value.isEmpty) {
      throw StateError('Missing persisted US-030 seeded-state string: $suffix');
    }
    return value;
  }

  return _SeededLifecycleState(
    savedEntryId: requireInt('savedEntryId'),
    draftEntryId: requireInt('draftEntryId'),
    textDraftEntryId: requireInt('textDraftEntryId'),
    storedDraftAudioReference: requireString('storedDraftAudioReference'),
    savedCreatedAt: requireInt('savedCreatedAt'),
    draftCreatedAt: requireInt('draftCreatedAt'),
    savedLanguage: requireString('savedLanguage'),
    draftLanguage: requireString('draftLanguage'),
    savedRawTranscript: requireString('savedRawTranscript'),
    savedCleanedText: requireString('savedCleanedText'),
    savedWordCount: requireInt('savedWordCount'),
    draftAudioPath: (await _platformDraftAudioFile()).path,
    storedDeviceId: requireString('storedDeviceId'),
  );
}

Future<void> _expectLifecycleState({
  required LocalEntryDatabase database,
  required EntryRepository repository,
  required PreferencesRepository preferencesRepository,
  required _SeededLifecycleState expected,
}) async {
  final entries = await repository.watchAllEntries().first;
  final rawDraftEntry = await database.entryDao.getEntryById(
    expected.draftEntryId,
  );
  expect(rawDraftEntry, isNotNull);
  final savedEntry = entries.singleWhere(
    (entry) => entry.id == expected.savedEntryId,
  );
  final draftEntry = entries.singleWhere(
    (entry) => entry.id == expected.draftEntryId,
  );

  expect(entries, hasLength(3));
  final textDraft = entries.singleWhere(
    (entry) => entry.id == expected.textDraftEntryId,
  );
  expect(textDraft.type, EntryType.draft);
  expect(textDraft.rawTranscript, _textDraftTranscript);
  expect(textDraft.language, _draftLanguage);
  expect(textDraft.audioPath, isNull);
  expect(savedEntry.type, EntryType.saved);
  expect(savedEntry.rawTranscript, expected.savedRawTranscript);
  expect(savedEntry.cleanedText, expected.savedCleanedText);
  expect(savedEntry.language, expected.savedLanguage);
  expect(savedEntry.createdAt, expected.savedCreatedAt);
  expect(savedEntry.wordCount, expected.savedWordCount);
  expect(savedEntry.audioPath, isNull);

  expect(draftEntry.type, EntryType.draft);
  expect(draftEntry.rawTranscript, isEmpty);
  expect(draftEntry.cleanedText, isNull);
  expect(draftEntry.language, expected.draftLanguage);
  expect(draftEntry.createdAt, expected.draftCreatedAt);
  expect(draftEntry.audioPath, expected.draftAudioPath);
  expect(await File(draftEntry.audioPath!).readAsString(), _draftAudioContents);
  expect(rawDraftEntry!.audioPath, expected.storedDraftAudioReference);
  expect(rawDraftEntry.audioPath, startsWith(DraftAudioPathCodec.cacheScheme));

  expect(await preferencesRepository.getHasEverRecorded(), isTrue);
  expect(await preferencesRepository.getDeviceId(), expected.storedDeviceId);
}

Future<void> _expectFreshState({
  required EntryRepository repository,
  required PreferencesRepository preferencesRepository,
}) async {
  final entries = await repository.watchAllEntries().first;
  final drafts = await repository.getPendingDrafts();

  expect(entries, isEmpty);
  expect(drafts, isEmpty);
  expect(await preferencesRepository.getHasEverRecorded(), isFalse);
  expect(await preferencesRepository.getDeviceId(), _expectedStoredDeviceId());
}

Future<void> _clearIsolatedState({
  required Directory tempDirectory,
  required FakeSecureKeyValueStore secureStorage,
  required SharedPreferences sharedPreferences,
}) async {
  await LocalEntryDatabase.deleteDatabaseArtifacts(
    File('${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}'),
  );
  await secureStorage.delete(DatabaseKeyStore.storageKey);
  await sharedPreferences.clear();

  final draftFile = await _isolatedDraftAudioFile();
  if (await draftFile.exists()) {
    await draftFile.delete();
  }
}

Future<void> _clearPlatformState() async {
  await LocalEntryDatabase.deleteDatabaseArtifacts(
    await LocalEntryDatabase.defaultDatabaseFile(),
  );

  final secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );
  await secureStorage.delete(key: DatabaseKeyStore.storageKey);

  final sharedPreferences = await SharedPreferences.getInstance();
  await sharedPreferences.clear();

  final draftFile = await _platformDraftAudioFile();
  if (await draftFile.exists()) {
    await draftFile.delete();
  }
}

Future<File> _platformDraftAudioFile() async {
  return _managedDraftAudioFile('us030-platform-draft-audio.m4a');
}

Future<File> _isolatedDraftAudioFile() async {
  return _managedDraftAudioFile('us030-isolated-draft-audio.m4a');
}

Future<File> _managedDraftAudioFile(String name) async {
  final directory = await getTemporaryDirectory();
  return File(path.join(directory.path, name));
}

String _expectedStoredDeviceId() {
  final digest = sha256.convert(
    utf8.encode('$_platformRawDeviceId|$_deviceIdSalt'),
  );
  return digest.toString();
}

class _CleanupCallbackHolder {
  Future<backend.CleanupResult> Function({
    required String transcript,
    required String language,
  })
  callback = ({required String transcript, required String language}) async =>
      const backend.CleanupSuccess(cleanedText: _retriedCleanedText);

  Future<backend.CleanupResult> call({
    required String transcript,
    required String language,
  }) {
    return callback(transcript: transcript, language: language);
  }
}

class _LaunchRetryTranscriptionService implements TranscriptionService {
  final List<String> transcribedAudioPaths = <String>[];
  final List<TranscriptionResult> nextDraftResults = <TranscriptionResult>[];

  @override
  int? get hardCapDeadlineElapsedRealtime => null;

  @override
  bool get isRecording => false;

  @override
  bool get isTranscribing => false;

  @override
  Future<void> cancelLiveTranscription() async {}

  @override
  Future<void> startLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {}

  @override
  Future<TranscriptionResult> stopLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<TranscriptionResult> transcribeAudioDraft(String audioPath) async {
    transcribedAudioPaths.add(audioPath);
    if (nextDraftResults.isEmpty) {
      return const TranscriptionFailure(
        reason: TranscriptionFailureReason.apiError,
      );
    }
    return nextDraftResults.removeAt(0);
  }
}

class _StubRegisterDeviceOnLaunchUseCase extends RegisterDeviceOnLaunchUseCase {
  _StubRegisterDeviceOnLaunchUseCase(this.result)
    : super(
        registerDevice: () async {
          throw UnimplementedError();
        },
        setRecordQuota: (_) {},
        logWarning: (_, {error, stackTrace}) {},
      );

  final LaunchDeviceRegistrationResult result;

  @override
  Future<LaunchDeviceRegistrationResult> call() async => result;
}

const _appConfig = AppConfig(
  backendUrl: 'https://wrait-backend.vercel.app',
  proxySecret: '',
  recordingHardCapMs: 120000,
);
