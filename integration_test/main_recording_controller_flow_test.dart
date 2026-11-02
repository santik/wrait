import 'dart:io';
import 'dart:math';
import 'dart:ui' show Locale;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/audio/audio_recording_providers.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/transcription/transcription_providers.dart';
import 'package:wrait/data/transcription/transcription_service.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/l10n/app_localizations.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/main_screen_status.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../test/test_doubles/fake_monotonic_clock.dart';
import '../test/test_doubles/fake_secure_storage.dart';
import 'support/managed_audio_files.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets(
    'provider graph completes the Best-mode success path through Saved and hasEverRecorded',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      harness.transcriptionService.nextStopResult = const TranscriptionSuccess(
        transcript: 'raw transcript',
        detectedLanguage: 'fr-FR',
      );
      harness.cleanupCallbackHolder.callback =
          ({required transcript, required language}) async {
            expect(transcript, 'raw transcript');
            expect(language, 'fr-FR');
            return backend.CleanupSuccess(
              cleanedText: 'Cleaned transcript.',
              quota: RecordQuotaState(
                limit: 5,
                count: 3,
                remaining: 2,
                resetAt: DateTime.utc(2026, 6, 12),
              ),
            );
          };

      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      harness.monotonicClock.advance(const Duration(seconds: 6));
      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        harness.container.read(mainRecordingControllerProvider).recordingState,
        RecordingSaved(entryId: 1, detectedLanguage: 'fr-FR'),
      );
      expect(
        harness.container.read(sessionRecordQuotaStateProvider)?.remaining,
        2,
      );
      expect(harness.sharedPreferences.getBool('has_ever_recorded'), isTrue);

      final entry = await harness.container
          .read(entryRepositoryProvider)
          .getEntryById(1);
      expect(entry, isNotNull);
      expect(entry!.rawTranscript, 'raw transcript');
      expect(entry.cleanedText, 'Cleaned transcript.');
      expect(entry.type, EntryType.saved);
    },
  );

  testWidgets(
    'provider graph preserves an audio draft and emits mapped Error on live transcription failure',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final audioDraftFile = await harness.writeManagedAudioFile(
        'retry-audio.m4a',
      );
      final quota = RecordQuotaState(
        limit: 5,
        count: 5,
        remaining: 0,
        resetAt: DateTime.utc(2026, 6, 12),
      );

      harness.transcriptionService.nextStopResult = TranscriptionFailure(
        reason: TranscriptionFailureReason.network,
        audioDraftPath: audioDraftFile.path,
        quota: quota,
      );

      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      harness.monotonicClock.advance(const Duration(seconds: 6));
      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        harness.container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(
          RecordingError.noInternet,
          preservedDraft: true,
        ),
      );
      expect(
        resolveMainScreenStatus(
          controllerState: harness.container.read(
            mainRecordingControllerProvider,
          ),
          hasEverRecorded: false,
          l10n: _l10n,
        ).statusText,
        'no connection · saved as draft',
      );

      final drafts = await harness.container
          .read(entryRepositoryProvider)
          .getPendingDrafts();
      expect(drafts, hasLength(1));
      expect(drafts.single.audioPath, audioDraftFile.path);
      expect(drafts.single.type, EntryType.draft);
      expect(harness.container.read(sessionRecordQuotaStateProvider), quota);
    },
  );

  testWidgets(
    'provider graph keeps no-word failures terminal and leaves no pending draft even if an audio path is present',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final audioDraftFile = await harness.writeManagedAudioFile(
        'nothing-caught.m4a',
      );

      harness.transcriptionService.nextStopResult = TranscriptionFailure(
        reason: TranscriptionFailureReason.nothingCaught,
        audioDraftPath: audioDraftFile.path,
      );

      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      harness.monotonicClock.advance(const Duration(seconds: 6));
      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        harness.container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(RecordingError.noMatch),
      );
      expect(
        resolveMainScreenStatus(
          controllerState: harness.container.read(
            mainRecordingControllerProvider,
          ),
          hasEverRecorded: false,
          l10n: _l10n,
        ).statusText,
        'nothing caught · too quiet?',
      );

      final drafts = await harness.container
          .read(entryRepositoryProvider)
          .getPendingDrafts();
      expect(drafts, isEmpty);
    },
  );

  testWidgets(
    'provider graph treats punctuation-only transcription success as terminal no-match without saving a draft',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final quota = RecordQuotaState(
        limit: 5,
        count: 5,
        remaining: 0,
        resetAt: DateTime.utc(2026, 6, 12),
      );

      harness.transcriptionService.nextStopResult = TranscriptionSuccess(
        transcript: ' ... ',
        detectedLanguage: 'en-US',
        quota: quota,
      );

      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      harness.monotonicClock.advance(const Duration(seconds: 6));
      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        harness.container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(RecordingError.noMatch),
      );
      expect(harness.container.read(sessionRecordQuotaStateProvider), quota);

      final drafts = await harness.container
          .read(entryRepositoryProvider)
          .getPendingDrafts();
      expect(drafts, isEmpty);
    },
  );

  testWidgets(
    'provider graph preserves a text draft and emits mapped Error when cleanup fails',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      harness.transcriptionService.nextStopResult = const TranscriptionSuccess(
        transcript: 'raw transcript',
        detectedLanguage: 'en-US',
      );
      harness.cleanupCallbackHolder.callback =
          ({required transcript, required language}) async {
            return const backend.CleanupFailure(
              reason: backend.BackendFailureReason.backendUnavailable,
            );
          };

      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      harness.monotonicClock.advance(const Duration(seconds: 6));
      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        harness.container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(
          RecordingError.backendUnavailable,
          preservedDraft: true,
        ),
      );
      expect(
        resolveMainScreenStatus(
          controllerState: harness.container.read(
            mainRecordingControllerProvider,
          ),
          hasEverRecorded: false,
          l10n: _l10n,
        ).statusText,
        'service unavailable · saved as draft',
      );

      final entry = await harness.container
          .read(entryRepositoryProvider)
          .getEntryById(1);
      expect(entry, isNotNull);
      expect(entry!.type, EntryType.draft);
      expect(entry.rawTranscript, 'raw transcript');
      expect(entry.cleanedText, isNull);
      expect(harness.sharedPreferences.getBool('has_ever_recorded'), isNull);
    },
  );

  testWidgets(
    'provider graph preserves an audio draft and exposes proxy-auth draft copy',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final audioDraftFile = await harness.writeManagedAudioFile(
        'retry-proxy-auth.m4a',
      );

      harness.transcriptionService.nextStopResult = TranscriptionFailure(
        reason: TranscriptionFailureReason.proxyAuthFailed,
        audioDraftPath: audioDraftFile.path,
      );

      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      harness.monotonicClock.advance(const Duration(seconds: 6));
      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        harness.container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(
          RecordingError.proxyAuthFailed,
          preservedDraft: true,
        ),
      );
      expect(
        resolveMainScreenStatus(
          controllerState: harness.container.read(
            mainRecordingControllerProvider,
          ),
          hasEverRecorded: false,
          l10n: _l10n,
        ).statusText,
        'server config error · saved as draft',
      );
    },
  );

  testWidgets(
    'provider graph preserves a text draft and exposes generic api draft copy',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      harness.transcriptionService.nextStopResult = const TranscriptionSuccess(
        transcript: 'raw transcript',
        detectedLanguage: 'en-US',
      );
      harness.cleanupCallbackHolder.callback =
          ({required transcript, required language}) async {
            return const backend.CleanupFailure(
              reason: backend.BackendFailureReason.apiError,
            );
          };

      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      harness.monotonicClock.advance(const Duration(seconds: 6));
      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        harness.container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(
          RecordingError.apiFailed,
          preservedDraft: true,
        ),
      );
      expect(
        resolveMainScreenStatus(
          controllerState: harness.container.read(
            mainRecordingControllerProvider,
          ),
          hasEverRecorded: false,
          l10n: _l10n,
        ).statusText,
        'saved as draft · will retry',
      );
    },
  );

  testWidgets(
    'provider graph keeps the transcription quota when cleanup saves a draft without its own quota',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final fallbackQuota = RecordQuotaState(
        limit: 5,
        count: 4,
        remaining: 1,
        resetAt: DateTime.utc(2026, 6, 12),
      );

      harness.transcriptionService.nextStopResult = TranscriptionSuccess(
        transcript: 'raw transcript',
        detectedLanguage: 'en-US',
        quota: fallbackQuota,
      );
      harness.cleanupCallbackHolder.callback =
          ({required transcript, required language}) async {
            return const backend.CleanupFailure(
              reason: backend.BackendFailureReason.backendUnavailable,
            );
          };

      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      harness.monotonicClock.advance(const Duration(seconds: 6));
      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        harness.container.read(sessionRecordQuotaStateProvider)?.remaining,
        1,
      );
      expect(harness.container.read(sessionRecordQuotaStateProvider)?.count, 4);
    },
  );

  testWidgets(
    'provider graph supports a second recording after Saved while the first entry stays persisted',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      harness.transcriptionService.nextStopResult = const TranscriptionSuccess(
        transcript: 'first raw',
        detectedLanguage: 'en-US',
      );
      harness.cleanupCallbackHolder.callback =
          ({required transcript, required language}) async =>
              backend.CleanupSuccess(cleanedText: 'cleaned $transcript');

      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      harness.monotonicClock.advance(const Duration(seconds: 6));
      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      harness.transcriptionService.nextStopResult = const TranscriptionSuccess(
        transcript: 'second raw',
        detectedLanguage: 'en-US',
      );
      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      harness.monotonicClock.advance(const Duration(seconds: 6));
      await harness.container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        harness.container.read(mainRecordingControllerProvider).recordingState,
        RecordingSaved(entryId: 2, detectedLanguage: 'en-US'),
      );

      final entries = await harness.container
          .read(entryRepositoryProvider)
          .watchAllEntries()
          .first;
      expect(entries, hasLength(2));
      expect(entries.map((entry) => entry.rawTranscript).toList(), [
        'second raw',
        'first raw',
      ]);
    },
  );
}

class _CleanupCallbackHolder {
  Future<backend.CleanupResult> Function({
    required String transcript,
    required String language,
  })
  callback = ({required String transcript, required String language}) async =>
      const backend.CleanupSuccess(cleanedText: 'Cleaned transcript.');
}

class _Harness {
  _Harness({
    required this.container,
    required this.database,
    required this.tempDirectory,
    required this.monotonicClock,
    required this.transcriptionService,
    required this.sharedPreferences,
    required this.cleanupCallbackHolder,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory tempDirectory;
  final FakeMonotonicClock monotonicClock;
  final _FakeTranscriptionService transcriptionService;
  final SharedPreferences sharedPreferences;
  final _CleanupCallbackHolder cleanupCallbackHolder;
  final List<File> _managedAudioFiles = <File>[];

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

Future<_Harness> _createHarness() async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'wrait-main-recording-controller-int',
  );
  final database = await LocalEntryDatabase.open(
    keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(7)),
    databaseFile: File(
      '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
    ),
  );
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final sharedPreferences = await SharedPreferences.getInstance();
  final monotonicClock = FakeMonotonicClock(0);
  final transcriptionService = _FakeTranscriptionService();
  final cleanupCallbackHolder = _CleanupCallbackHolder();

  final container = ProviderContainer(
    overrides: [
      localEntryDatabaseProvider.overrideWithValue(database),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      monotonicClockProvider.overrideWithValue(monotonicClock),
      transcriptionServiceProvider.overrideWithValue(transcriptionService),
      cleanupTranscriptCallbackProvider.overrideWithValue(({
        required transcript,
        required language,
      }) {
        return cleanupCallbackHolder.callback(
          transcript: transcript,
          language: language,
        );
      }),
      recordingFeedbackDelaysProvider.overrideWithValue(
        const RecordingFeedbackDelays(
          errorAndDeletedAutoClear: Duration(minutes: 1),
        ),
      ),
    ],
  );

  return _Harness(
    container: container,
    database: database,
    tempDirectory: tempDirectory,
    monotonicClock: monotonicClock,
    transcriptionService: transcriptionService,
    sharedPreferences: sharedPreferences,
    cleanupCallbackHolder: cleanupCallbackHolder,
  );
}

class _FakeTranscriptionService implements TranscriptionService {
  @override
  int? hardCapDeadlineElapsedRealtime = 120000;

  @override
  bool isRecording = false;

  @override
  bool isTranscribing = false;

  TranscriptionResult nextStopResult = const TranscriptionFailure(
    reason: TranscriptionFailureReason.apiError,
  );

  @override
  Future<void> startLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    isRecording = true;
    onStatus(RecordingStarted(hardCapDeadlineElapsedRealtime!));
  }

  @override
  Future<TranscriptionResult> stopLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    isRecording = false;
    if (nextStopResult case TranscriptionFailure(
      reason: final reason,
    ) when reason == TranscriptionFailureReason.tooShort) {
      return nextStopResult;
    }

    isTranscribing = true;
    onStatus(const Uploading());
    isTranscribing = false;
    return nextStopResult;
  }

  @override
  Future<void> cancelLiveTranscription() async {
    isRecording = false;
    isTranscribing = false;
    hardCapDeadlineElapsedRealtime = null;
  }

  @override
  Future<TranscriptionResult> transcribeAudioDraft(String audioPath) async {
    return nextStopResult;
  }
}
