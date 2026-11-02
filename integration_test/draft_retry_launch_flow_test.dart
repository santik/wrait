import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/core/time/system_clock.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/transcription/transcription_providers.dart';
import 'package:wrait/data/transcription/transcription_service.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/domain/usecase/register_device_on_launch_use_case.dart';
import 'package:wrait/main.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../test/test_doubles/fake_secure_storage.dart';
import 'support/managed_audio_files.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets(
    'successful launch retry finalizes pending drafts and existing surfaces reflect the result without foreground success feedback',
    (tester) async {
      final harness = await _createHarness(
        registrationResult: LaunchDeviceRegistrationResult.success,
      );
      addTearDown(harness.dispose);

      final repository = harness.container.read(entryRepositoryProvider);
      final audioFile = await harness.writeManagedAudioFile(
        'pending-audio.m4a',
      );
      final audioDraftId = await repository.saveAudioDraft(
        audioFile.path,
        'en-US',
      );
      harness.entryClock.advance(const Duration(days: 1));
      final textDraftId = await repository.saveDraft('raw text draft', 'en-US');

      harness.transcriptionService.nextDraftResults.add(
        const TranscriptionSuccess(
          transcript: 'audio retry transcript',
          detectedLanguage: 'fr-FR',
        ),
      );
      harness
          .cleanupCallbackHolder
          .callback = ({required transcript, required language}) async {
        if (transcript == 'audio retry transcript') {
          return const backend.CleanupSuccess(
            cleanedText: 'Audio retry cleaned',
          );
        }
        return const backend.CleanupSuccess(cleanedText: 'Text retry cleaned');
      };

      startAppLaunchWork(harness.container);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const WraitApp(),
        ),
      );
      await _pumpUntil(
        tester,
        () => repository.getPendingDrafts().then((drafts) => drafts.isEmpty),
      );

      expect(find.text('tap button to write'), findsOneWidget);
      expect(find.text('saved, tap to read'), findsNothing);
      expect(find.byKey(const ValueKey('statsLineButton')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('statsLineButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('entryRow-$audioDraftId')), findsOneWidget);
      expect(find.byKey(ValueKey('entryRow-$textDraftId')), findsOneWidget);
      expect(find.text('Audio retry cleaned'), findsOneWidget);
      expect(find.text('Text retry cleaned'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('entryCard-$audioDraftId')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
      expect(find.text('Audio retry cleaned'), findsOneWidget);
      expect(await audioFile.exists(), isFalse);
    },
  );

  testWidgets(
    'failed launch retry preserves audio and text drafts for the next launch',
    (tester) async {
      final harness = await _createHarness(
        registrationResult: LaunchDeviceRegistrationResult.success,
      );
      addTearDown(harness.dispose);

      final repository = harness.container.read(entryRepositoryProvider);
      final audioFile = await harness.writeManagedAudioFile('failed-audio.m4a');
      final audioDraftId = await repository.saveAudioDraft(
        audioFile.path,
        'en-US',
      );
      harness.entryClock.advance(const Duration(days: 1));
      final textDraftId = await repository.saveDraft(
        'text draft retry',
        'en-US',
      );

      harness.transcriptionService.nextDraftResults.add(
        const TranscriptionFailure(reason: TranscriptionFailureReason.network),
      );
      harness.cleanupCallbackHolder.callback =
          ({required transcript, required language}) async {
            return const backend.CleanupFailure(
              reason: backend.BackendFailureReason.backendUnavailable,
            );
          };

      startAppLaunchWork(harness.container);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));

      final audioDraft = await repository.getEntryById(audioDraftId);
      final textDraft = await repository.getEntryById(textDraftId);
      expect(audioDraft, isNotNull);
      expect(audioDraft!.type, EntryType.draft);
      expect(audioDraft.audioPath, audioFile.path);
      expect(textDraft, isNotNull);
      expect(textDraft!.type, EntryType.draft);
      expect(textDraft.cleanedText, isNull);
      expect(await audioFile.exists(), isTrue);
    },
  );

  testWidgets('registration failure skips draft retry until a future launch', (
    tester,
  ) async {
    final harness = await _createHarness(
      registrationResult: LaunchDeviceRegistrationResult.failure,
    );
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final audioFile = await harness.writeManagedAudioFile('skipped-audio.m4a');
    final audioDraftId = await repository.saveAudioDraft(
      audioFile.path,
      'en-US',
    );
    await repository.saveDraft('text draft retry', 'en-US');

    harness.transcriptionService.nextDraftResults.add(
      const TranscriptionSuccess(
        transcript: 'should not run',
        detectedLanguage: 'en-US',
      ),
    );

    startAppLaunchWork(harness.container);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));

    final audioDraft = await repository.getEntryById(audioDraftId);
    expect(audioDraft, isNotNull);
    expect(audioDraft!.type, EntryType.draft);
    expect(harness.transcriptionService.transcribedAudioPaths, isEmpty);
    expect(harness.cleanupCallbackHolder.callCount, 0);
  });

  testWidgets('stale and malformed audio drafts are deleted before retry', (
    tester,
  ) async {
    final harness = await _createHarness(
      registrationResult: LaunchDeviceRegistrationResult.success,
    );
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    harness.entryClock.current = DateTime(2026, 6, 1, 9);
    final staleFile = await harness.writeManagedAudioFile('stale-audio.m4a');
    await repository.saveAudioDraft(staleFile.path, 'en-US');
    harness.entryClock.current = DateTime(2026, 6, 19, 9);
    final missingAudioPath = await harness.managedAudioPath(
      'missing-audio.m4a',
    );
    final malformedDraftId = await repository.saveAudioDraft(
      missingAudioPath,
      'en-US',
    );
    final finalEntryId = await repository.saveEntry(
      'kept final entry',
      'en-US',
    );

    startAppLaunchWork(harness.container);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));

    expect(await staleFile.exists(), isFalse);
    expect(await repository.getEntryById(malformedDraftId), isNull);
    expect(await repository.getEntryById(finalEntryId), isNotNull);
  });
}

class _CleanupCallbackHolder {
  int callCount = 0;
  Future<backend.CleanupResult> Function({
    required String transcript,
    required String language,
  })
  callback = ({required String transcript, required String language}) async =>
      const backend.CleanupSuccess(cleanedText: 'Cleaned transcript.');

  Future<backend.CleanupResult> call({
    required String transcript,
    required String language,
  }) async {
    callCount += 1;
    return callback(transcript: transcript, language: language);
  }
}

class _Harness {
  _Harness({
    required this.container,
    required this.database,
    required this.tempDirectory,
    required this.entryClock,
    required this.transcriptionService,
    required this.cleanupCallbackHolder,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory tempDirectory;
  final _MutableClock entryClock;
  final _FakeTranscriptionService transcriptionService;
  final _CleanupCallbackHolder cleanupCallbackHolder;
  final List<File> _managedAudioFiles = <File>[];

  Future<String> managedAudioPath(String name) async {
    return managedDraftAudioPath(name);
  }

  Future<File> writeManagedAudioFile(String name) async {
    return writeManagedDraftAudioFile(
      managedFiles: _managedAudioFiles,
      name: name,
    );
  }

  Future<void> dispose() async {
    container.dispose();
    await database.close();
    await cleanupManagedDraftAudioFiles(_managedAudioFiles);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<_Harness> _createHarness({
  required LaunchDeviceRegistrationResult registrationResult,
}) async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'wrait-draft-retry-launch-int',
  );
  final database = await LocalEntryDatabase.open(
    keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(7)),
    databaseFile: File(
      '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
    ),
  );
  final entryClock = _MutableClock(DateTime(2026, 6, 19, 9));
  final transcriptionService = _FakeTranscriptionService();
  final cleanupCallbackHolder = _CleanupCallbackHolder();

  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          backendUrl: 'https://wrait-backend.vercel.app',
          proxySecret: '',
          recordingHardCapMs: 120000,
        ),
      ),
      appLockEnabledProvider.overrideWithValue(false),
      appRouterProvider.overrideWithValue(buildAppRouter(initialLocation: '/')),
      localEntryDatabaseProvider.overrideWithValue(database),
      clockProvider.overrideWithValue(entryClock),
      preferencesRepositoryProvider.overrideWithValue(
        const _LaunchPreferencesRepository(),
      ),
      mainRecordingControllerProvider.overrideWith(
        _IdleMainRecordingController.new,
      ),
      sessionRecordQuotaStateProvider.overrideWith(_IdleQuotaNotifier.new),
      registerDeviceOnLaunchUseCaseProvider.overrideWithValue(
        _StubRegisterDeviceOnLaunchUseCase(registrationResult),
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

  return _Harness(
    container: container,
    database: database,
    tempDirectory: tempDirectory,
    entryClock: entryClock,
    transcriptionService: transcriptionService,
    cleanupCallbackHolder: cleanupCallbackHolder,
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 2),
  Duration step = const Duration(milliseconds: 10),
}) async {
  final endTime = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(endTime)) {
    if (await condition()) {
      return;
    }
    await tester.pump(step);
  }

  if (!await condition()) {
    fail('Timed out waiting for condition after $timeout.');
  }
}

class _FakeTranscriptionService implements TranscriptionService {
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

class _IdleMainRecordingController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();

  @override
  Future<void> onMainButtonTapped() async {}
}

class _IdleQuotaNotifier extends SessionRecordQuotaStateNotifier {
  @override
  RecordQuotaState? build() => null;
}

class _LaunchPreferencesRepository implements PreferencesRepository {
  const _LaunchPreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => false;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
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

class _MutableClock implements Clock {
  _MutableClock(this.current);

  DateTime current;

  @override
  int now() => current.millisecondsSinceEpoch;

  void advance(Duration duration) {
    current = current.add(duration);
  }
}
