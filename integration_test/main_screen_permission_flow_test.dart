import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:record/record.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/audio/audio_recording_providers.dart';
import 'package:wrait/data/audio/microphone_permission_service.dart';
import 'package:wrait/data/audio/record_audio_recording_service.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/transcription/transcription_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/main_screen_status.dart';
import 'package:wrait/presentation/main/recording_state.dart';
import 'package:wrait/l10n/app_localizations.dart';

import '../test/test_doubles/fake_monotonic_clock.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'first recording tap requests permission and retryable denial stays retryable',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      harness.microphonePermissionService.currentState =
          MicrophoneAccessState.denied;
      harness.microphonePermissionService.nextRequestState =
          MicrophoneAccessState.denied;

      await harness.controller.onMainButtonTapped();

      expect(harness.microphonePermissionService.requestCallCount, 1);
      expect(harness.recorder.startCallCount, 0);
      expect(
        harness.state.recordingState,
        const RecordingErrorState(RecordingError.microphoneDenied),
      );
      final status = resolveMainScreenStatus(
        controllerState: harness.state,
        hasEverRecorded: false,
        l10n: _l10n,
      );
      expect(status.buttonLabel, 'wrait');
      expect(status.statusText, 'mic needed · tap again');
      expect(status.action, MainScreenStatusAction.startRecording);
    },
  );

  testWidgets(
    'blocked permission status line and primary button both open settings',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      harness.microphonePermissionService.currentState =
          MicrophoneAccessState.permanentlyDenied;

      await harness.controller.onMainButtonTapped();

      expect(
        harness.state.recordingState,
        const RecordingErrorState(RecordingError.microphoneBlocked),
      );
      final status = resolveMainScreenStatus(
        controllerState: harness.state,
        hasEverRecorded: false,
        l10n: _l10n,
      );
      expect(status.buttonLabel, 'wrait');
      expect(status.statusText, 'mic blocked · tap settings');
      expect(status.action, MainScreenStatusAction.openMicrophoneSettings);

      await harness.controller.openMicrophoneSettings();
      await harness.controller.onMainButtonTapped();

      expect(harness.microphonePermissionService.openSettingsCallCount, 2);
      expect(harness.recorder.startCallCount, 0);
    },
  );

  testWidgets(
    'restricted permission follows the blocked settings recovery path',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      harness.microphonePermissionService.currentState =
          MicrophoneAccessState.restricted;

      await harness.controller.onMainButtonTapped();

      expect(
        harness.state.recordingState,
        const RecordingErrorState(RecordingError.microphoneBlocked),
      );
      final status = resolveMainScreenStatus(
        controllerState: harness.state,
        hasEverRecorded: false,
        l10n: _l10n,
      );
      expect(status.statusText, 'mic blocked · tap settings');
      expect(status.action, MainScreenStatusAction.openMicrophoneSettings);

      await harness.controller.openMicrophoneSettings();

      expect(harness.microphonePermissionService.openSettingsCallCount, 1);
    },
  );

  testWidgets(
    'granting permission from settings and resuming clears blocked status',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      harness.microphonePermissionService.currentState =
          MicrophoneAccessState.permanentlyDenied;

      await harness.controller.onMainButtonTapped();

      expect(
        harness.state.recordingState,
        const RecordingErrorState(RecordingError.microphoneBlocked),
      );

      harness.microphonePermissionService.currentState =
          MicrophoneAccessState.granted;
      await harness.controller.onAppResumed();

      expect(harness.state.recordingState, const RecordingIdle());
      expect(
        resolveMainScreenStatus(
          controllerState: harness.state,
          hasEverRecorded: false,
          l10n: _l10n,
        ).statusText,
        'tap button to write',
      );
    },
  );

  testWidgets(
    'permission revocation during active recording cancels capture without upload or save',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      harness.microphonePermissionService.currentState =
          MicrophoneAccessState.granted;
      harness.microphonePermissionService.nextRequestState =
          MicrophoneAccessState.granted;

      await harness.controller.onMainButtonTapped();

      expect(harness.state.recordingState, isA<RecordingListening>());
      expect(harness.recorder.startCallCount, 1);

      harness.microphonePermissionService.currentState =
          MicrophoneAccessState.denied;
      await harness.controller.onAppResumed();

      expect(harness.recorder.cancelCallCount, 1);
      expect(harness.transcribeCallCount, 0);
      expect(harness.cleanupCallCount, 0);
      expect(
        harness.state.recordingState,
        const RecordingErrorState(RecordingError.microphoneDenied),
      );
    },
  );
}

class _Harness {
  _Harness({
    required this.container,
    required this.tempDirectory,
    required this.microphonePermissionService,
    required this.recorder,
    required this.monotonicClock,
    required this.preferencesRepository,
  });

  final ProviderContainer container;
  final Directory tempDirectory;
  final _FakeMicrophonePermissionService microphonePermissionService;
  final _FakeRecorderAdapter recorder;
  final FakeMonotonicClock monotonicClock;
  final _FakePreferencesRepository preferencesRepository;

  int transcribeCallCount = 0;
  int cleanupCallCount = 0;

  MainRecordingController get controller =>
      container.read(mainRecordingControllerProvider.notifier);

  RecordingControllerState get state =>
      container.read(mainRecordingControllerProvider);

  Future<void> dispose() async {
    container.dispose();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<_Harness> _createHarness() async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'wrait-main-screen-permission-int',
  );
  final microphonePermissionService = _FakeMicrophonePermissionService();
  final recorder = _FakeRecorderAdapter();
  final monotonicClock = FakeMonotonicClock(0);
  final preferencesRepository = _FakePreferencesRepository();

  late final _Harness harness;
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          backendUrl: 'https://wrait-backend.vercel.app',
          proxySecret: '',
          recordingHardCapMs: 120000,
        ),
      ),
      preferencesRepositoryProvider.overrideWithValue(preferencesRepository),
      entryRepositoryProvider.overrideWithValue(_FakeEntryRepository()),
      monotonicClockProvider.overrideWithValue(monotonicClock),
      microphonePermissionServiceProvider.overrideWithValue(
        microphonePermissionService,
      ),
      recorderAdapterProvider.overrideWithValue(recorder),
      recordingFeedbackDelaysProvider.overrideWithValue(
        const RecordingFeedbackDelays(
          errorAndDeletedAutoClear: Duration(minutes: 1),
        ),
      ),
      liveRecordingPathFactoryProvider.overrideWithValue(() async {
        return path.join(tempDirectory.path, 'live-recording.m4a');
      }),
      transcribeAudioCallbackProvider.overrideWithValue((
        audioFile, {
        language,
      }) async {
        harness.transcribeCallCount += 1;
        return const backend.TranscriptionSuccess(
          transcript: 'raw transcript',
          detectedLanguage: 'en-US',
        );
      }),
      cleanupTranscriptCallbackProvider.overrideWithValue(({
        required transcript,
        required language,
      }) async {
        harness.cleanupCallCount += 1;
        return const backend.CleanupSuccess(cleanedText: 'Cleaned transcript.');
      }),
    ],
  );

  harness = _Harness(
    container: container,
    tempDirectory: tempDirectory,
    microphonePermissionService: microphonePermissionService,
    recorder: recorder,
    monotonicClock: monotonicClock,
    preferencesRepository: preferencesRepository,
  );
  return harness;
}

class _FakeMicrophonePermissionService implements MicrophonePermissionService {
  MicrophoneAccessState currentState = MicrophoneAccessState.denied;
  MicrophoneAccessState? nextRequestState;
  int getCallCount = 0;
  int requestCallCount = 0;
  int openSettingsCallCount = 0;

  @override
  Future<MicrophoneAccessState> getMicrophoneAccess() async {
    getCallCount += 1;
    return currentState;
  }

  @override
  Future<bool> openMicrophonePermissionSettings() async {
    openSettingsCallCount += 1;
    return true;
  }

  @override
  Future<MicrophoneAccessState> requestMicrophoneAccess() async {
    requestCallCount += 1;
    final requestState = nextRequestState ?? currentState;
    currentState = requestState;
    return requestState;
  }
}

class _FakeRecorderAdapter implements RecorderAdapter {
  int startCallCount = 0;
  int cancelCallCount = 0;
  String? _activePath;

  @override
  Future<void> cancel() async {
    cancelCallCount += 1;
    _activePath = null;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> start({
    required RecordConfig config,
    required String path,
  }) async {
    startCallCount += 1;
    _activePath = path;
  }

  @override
  Future<String?> stop() async {
    final path = _activePath;
    if (path == null) {
      return null;
    }

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const <int>[1, 2, 3, 4]);
    _activePath = null;
    return path;
  }
}

class _FakeEntryRepository implements EntryRepository {
  @override
  Future<void> deleteEntry(int id) async {}

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}

  @override
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<Entry?> getEntryById(int id) async => null;

  @override
  Future<List<int>> importEntries(List<Entry> entries) async => const [];

  @override
  Future<List<Entry>> getPendingDrafts() async => const <Entry>[];

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async => 1;

  @override
  Future<int> saveDraft(String transcript, String language) async => 1;

  @override
  Future<int> saveEntry(String transcript, String language) async => 1;

  @override
  Future<void> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  ) async {}

  @override
  Future<void> updateDraftTranscriptAndLanguage(
    int id,
    String rawTranscript,
    int wordCount,
    String language,
  ) async {}

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {}

  @override
  Future<void> updateEntryLanguage(int id, String language) async {}

  @override
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Stream<List<Entry>> watchAllEntries() => const Stream<List<Entry>>.empty();

  @override
  Stream<Entry?> watchEntryById(int id) => const Stream<Entry?>.empty();
}

class _FakePreferencesRepository implements PreferencesRepository {
  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => false;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}
