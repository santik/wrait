import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/audio/audio_recording_providers.dart';
import 'package:wrait/data/audio/microphone_permission_service.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/tag_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/transcription/transcription_providers.dart';
import 'package:wrait/data/transcription/transcription_service.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/model/tag.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/domain/repository/tag_repository.dart';
import 'package:wrait/domain/usecase/auto_tag_use_case.dart';
import 'package:wrait/domain/usecase/cleanup_transcript_use_case.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../../test_doubles/fake_monotonic_clock.dart';

void main() {
  late _FakeTranscriptionService transcriptionService;
  late _FakeCleanupTranscriptUseCase cleanupUseCase;
  late _FakeEntryRepository entryRepository;
  late _FakePreferencesRepository preferencesRepository;
  late _FakeMicrophonePermissionService microphonePermissionService;
  late _FakeTagRepository tagRepository;
  late _FakeTagTextCallback tagTextCallback;
  late _FakeAutoTagUseCase autoTagUseCase;
  late FakeMonotonicClock monotonicClock;
  late List<String> logMessages;
  late List<Object?> logErrors;
  late Directory tempDirectory;
  late ProviderContainer container;

  ProviderContainer buildContainer({
    RecordingFeedbackDelays feedbackDelays = const RecordingFeedbackDelays(
      errorAndDeletedAutoClear: Duration(milliseconds: 1),
    ),
    Duration resumePermissionTimeout = const Duration(seconds: 2),
    bool isDebugDevice = true,
  }) {
    transcriptionService = _FakeTranscriptionService();
    cleanupUseCase = _FakeCleanupTranscriptUseCase();
    entryRepository = _FakeEntryRepository();
    preferencesRepository = _FakePreferencesRepository();
    microphonePermissionService = _FakeMicrophonePermissionService();
    tagRepository = _FakeTagRepository();
    tagTextCallback = _FakeTagTextCallback();
    autoTagUseCase = _FakeAutoTagUseCase(tagRepository);
    monotonicClock = FakeMonotonicClock(0);
    logMessages = <String>[];
    logErrors = <Object?>[];

    return ProviderContainer(
      overrides: [
        transcriptionServiceProvider.overrideWithValue(transcriptionService),
        cleanupTranscriptUseCaseProvider.overrideWithValue(cleanupUseCase),
        entryRepositoryProvider.overrideWithValue(entryRepository),
        preferencesRepositoryProvider.overrideWithValue(preferencesRepository),
        microphonePermissionServiceProvider.overrideWithValue(
          microphonePermissionService,
        ),
        tagRepositoryProvider.overrideWithValue(tagRepository),
        tagTextCallbackProvider.overrideWithValue(tagTextCallback.call),
        autoTagUseCaseProvider.overrideWithValue(autoTagUseCase),
        monotonicClockProvider.overrideWithValue(monotonicClock),
        recordingFeedbackDelaysProvider.overrideWithValue(feedbackDelays),
        recordingResumePermissionTimeoutProvider.overrideWithValue(
          resumePermissionTimeout,
        ),
        recordingControllerWarningLoggerProvider.overrideWithValue((
          message, {
          error,
          stackTrace,
        }) {
          logMessages.add(message);
          logErrors.add(error);
        }),
        isDebugDeviceProvider.overrideWithValue(isDebugDevice),
      ],
    );
  }

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'wrait-main-recording-controller-test',
    );
    container = buildContainer();
  });

  tearDown(() async {
    container.dispose();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<void> driveSuccessfulSave({required int entryId}) async {
    cleanupUseCase.nextResult = CleanupTranscriptSuccess(
      entryId: entryId,
      cleanedText: 'saved',
    );
    transcriptionService.nextStopResult = const TranscriptionSuccess(
      transcript: 'raw transcript',
      detectedLanguage: 'en-US',
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
  }

  test(
    'idle button tap starts live recording and publishes Listening',
    () async {
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(transcriptionService.startCallCount, 1);
      expect(
        container.read(mainRecordingControllerProvider),
        RecordingControllerState(
          recordingState: RecordingListening(
            hardCapDeadlineElapsedRealtime: 120000,
          ),
        ),
      );
      expect(container.read(mainRecordingControllerProvider).isActive, isTrue);
    },
  );

  test(
    'start failure from retryable microphone denial publishes mic-needed error',
    () async {
      transcriptionService.startError =
          const MicBlockedTranscriptionServiceFailure(
            MicrophoneAccessState.denied,
          );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(RecordingError.microphoneDenied),
      );
    },
  );

  test(
    'start failure from blocked microphone publishes blocked mic error',
    () async {
      container.dispose();
      container = buildContainer(
        feedbackDelays: const RecordingFeedbackDelays(
          errorAndDeletedAutoClear: Duration(minutes: 1),
        ),
      );
      transcriptionService.startError =
          const MicBlockedTranscriptionServiceFailure(
            MicrophoneAccessState.permanentlyDenied,
          );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(RecordingError.microphoneBlocked),
      );
    },
  );

  test(
    'blocked microphone error auto-clears after the configured delay',
    () async {
      container.dispose();
      container = buildContainer(
        feedbackDelays: const RecordingFeedbackDelays(
          errorAndDeletedAutoClear: Duration(milliseconds: 20),
        ),
      );
      transcriptionService.startError =
          const MicBlockedTranscriptionServiceFailure(
            MicrophoneAccessState.permanentlyDenied,
          );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(RecordingError.microphoneBlocked),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingIdle(),
      );
    },
  );

  test('Listening stop before five seconds publishes TooShort, increments shake once, and auto-clears', () async {
    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    transcriptionService.nextStopResult = const TranscriptionFailure(
      reason: TranscriptionFailureReason.tooShort,
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(
      container.read(mainRecordingControllerProvider),
      const RecordingControllerState(
        recordingState: RecordingErrorState(RecordingError.tooShort),
        shakeErrorKey: 1,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingIdle(),
    );
  });

  test('valid stop publishes Uploading then Processing then Saved with entry id and detected language', () async {
    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    cleanupUseCase.nextResult = const CleanupTranscriptSuccess(
      entryId: 42,
      cleanedText: 'Cleaned transcript',
    );
    transcriptionService.nextStopResult = const TranscriptionSuccess(
      transcript: 'raw transcript',
      detectedLanguage: 'fr-FR',
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(transcriptionService.statusHistory, contains(const Uploading()));
    expect(cleanupUseCase.calls.single.rawTranscript, 'raw transcript');
    expect(
      container.read(mainRecordingControllerProvider),
      RecordingControllerState(
        recordingState: RecordingSaved(entryId: 42, detectedLanguage: 'fr-FR'),
      ),
    );
    expect(preferencesRepository.hasEverRecorded, isTrue);
    expect(container.read(mainRecordingControllerProvider).isActive, isFalse);
  });

  test('hard-cap timer stops recording and saves the result', () async {
    transcriptionService.nextHardCapDeadlineElapsedRealtime = 20;
    cleanupUseCase.nextResult = const CleanupTranscriptSuccess(
      entryId: 43,
      cleanedText: 'Cleaned transcript',
    );
    transcriptionService.nextStopResult = const TranscriptionSuccess(
      transcript: 'raw transcript',
      detectedLanguage: 'en-US',
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(transcriptionService.stopCallCount, 1);
    expect(transcriptionService.statusHistory, contains(const Uploading()));
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      RecordingSaved(entryId: 43, detectedLanguage: 'en-US'),
    );
  });

  test('manual stop cancels the pending hard-cap timer', () async {
    transcriptionService.nextHardCapDeadlineElapsedRealtime = 20;
    cleanupUseCase.nextResult = const CleanupTranscriptSuccess(
      entryId: 44,
      cleanedText: 'Cleaned transcript',
    );
    transcriptionService.nextStopResult = const TranscriptionSuccess(
      transcript: 'raw transcript',
      detectedLanguage: 'en-US',
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(transcriptionService.stopCallCount, 1);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      RecordingSaved(entryId: 44, detectedLanguage: 'en-US'),
    );
  });

  test('Uploading and Processing button taps are ignored', () async {
    final stopCompleter = Completer<TranscriptionResult>();
    transcriptionService.stopFutureFactory = () => stopCompleter.future;

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));

    final stopFuture = container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingUploading(),
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    expect(transcriptionService.startCallCount, 1);
    expect(transcriptionService.stopCallCount, 1);

    stopCompleter.complete(
      const TranscriptionFailure(reason: TranscriptionFailureReason.apiError),
    );
    await stopFuture;
  });

  test('Saved tap starts a new independent recording attempt', () async {
    await driveSuccessfulSave(entryId: 10);

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(transcriptionService.startCallCount, 2);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
    );
  });

  test('Deleted tap starts a new independent recording attempt', () async {
    container
        .read(mainRecordingControllerProvider.notifier)
        .onEntriesDeleted(2);

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(transcriptionService.startCallCount, 1);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
    );
  });

  test(
    'retryable Error tap starts a new independent recording attempt',
    () async {
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      monotonicClock.advance(const Duration(seconds: 6));
      transcriptionService.nextStopResult = const TranscriptionFailure(
        reason: TranscriptionFailureReason.apiError,
      );
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(transcriptionService.startCallCount, 2);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
      );
    },
  );

  test(
    'blocked microphone Error tap opens settings without leaving blocked state',
    () async {
      container.dispose();
      container = buildContainer(
        feedbackDelays: const RecordingFeedbackDelays(
          errorAndDeletedAutoClear: Duration(minutes: 1),
        ),
      );
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      monotonicClock.advance(const Duration(seconds: 6));
      transcriptionService.nextStopResult = const TranscriptionFailure(
        reason: TranscriptionFailureReason.micBlocked,
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(RecordingError.microphoneBlocked),
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(RecordingError.microphoneBlocked),
      );
      expect(microphonePermissionService.openSettingsCallCount, 1);
    },
  );

  test('resume after settings grant clears blocked microphone state', () async {
    container.dispose();
    container = buildContainer(
      feedbackDelays: const RecordingFeedbackDelays(
        errorAndDeletedAutoClear: Duration(minutes: 1),
      ),
    );
    transcriptionService.startError =
        const MicBlockedTranscriptionServiceFailure(
          MicrophoneAccessState.permanentlyDenied,
        );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    microphonePermissionService.currentState = MicrophoneAccessState.granted;
    await container
        .read(mainRecordingControllerProvider.notifier)
        .onAppResumed();

    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingIdle(),
    );
  });

  test(
    'resume while permission is still blocked preserves blocked state',
    () async {
      container.dispose();
      container = buildContainer(
        feedbackDelays: const RecordingFeedbackDelays(
          errorAndDeletedAutoClear: Duration(minutes: 1),
        ),
      );
      transcriptionService.startError =
          const MicBlockedTranscriptionServiceFailure(
            MicrophoneAccessState.permanentlyDenied,
          );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onAppResumed();

      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(RecordingError.microphoneBlocked),
      );
    },
  );

  test(
    'resume with revoked permission during listening cancels active recording',
    () async {
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      microphonePermissionService.currentState = MicrophoneAccessState.denied;
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onAppResumed();

      expect(transcriptionService.cancelCallCount, 1);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(RecordingError.microphoneDenied),
      );
    },
  );

  test('concurrent resume checks reuse the same permission lookup', () async {
    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    final permissionCompleter = Completer<MicrophoneAccessState>();
    microphonePermissionService.getFutureFactory = () =>
        permissionCompleter.future;

    final firstResume = container
        .read(mainRecordingControllerProvider.notifier)
        .onAppResumed();
    final secondResume = container
        .read(mainRecordingControllerProvider.notifier)
        .onAppResumed();

    expect(microphonePermissionService.getCallCount, 1);

    permissionCompleter.complete(MicrophoneAccessState.granted);
    await Future.wait([firstResume, secondResume]);

    expect(microphonePermissionService.getCallCount, 1);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
    );
  });

  test(
    'resume permission timeout logs and preserves the current recording',
    () async {
      container.dispose();
      container = buildContainer(
        resumePermissionTimeout: const Duration(milliseconds: 1),
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      microphonePermissionService.getFutureFactory = () =>
          Completer<MicrophoneAccessState>().future;

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onAppResumed();

      expect(transcriptionService.cancelCallCount, 0);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
      );
      expect(
        logMessages,
        contains('Timed out checking microphone permission after app resume.'),
      );
      expect(logErrors.last, isA<TimeoutException>());
    },
  );

  test('transcription failure mapping covers all supported outcomes', () async {
    final cases = <TranscriptionFailureReason, RecordingError>{
      TranscriptionFailureReason.tooShort: RecordingError.tooShort,
      TranscriptionFailureReason.nothingCaught: RecordingError.noMatch,
      TranscriptionFailureReason.micBlocked: RecordingError.microphoneBlocked,
      TranscriptionFailureReason.network: RecordingError.noInternet,
      TranscriptionFailureReason.backendUnavailable:
          RecordingError.backendUnavailable,
      TranscriptionFailureReason.proxyAuthFailed:
          RecordingError.proxyAuthFailed,
      TranscriptionFailureReason.speechNotRecognized:
          RecordingError.speechNotRecognized,
      TranscriptionFailureReason.apiError: RecordingError.apiFailed,
    };

    for (final entry in cases.entries) {
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      monotonicClock.advance(const Duration(seconds: 6));
      transcriptionService.nextStopResult = TranscriptionFailure(
        reason: entry.key,
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingErrorState(entry.value),
      );

      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });

  test('transcription failure with audioDraftPath persists an audio draft using the fallback language', () async {
    final audioDraftFile = File('${tempDirectory.path}/retry-audio.m4a');
    await audioDraftFile.writeAsString('audio');

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    transcriptionService.nextStopResult = TranscriptionFailure(
      reason: TranscriptionFailureReason.network,
      audioDraftPath: audioDraftFile.path,
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(entryRepository.savedAudioDrafts, [
      (audioDraftFile.path, cleanupTranscriptFallbackLanguage),
    ]);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingErrorState(
        RecordingError.noInternet,
        preservedDraft: true,
      ),
    );
    expect(container.read(mainRecordingControllerProvider).shakeErrorKey, 0);
  });

  test('transcription failure with requestedLanguage persists the draft using that language', () async {
    final audioDraftFile = File('${tempDirectory.path}/retry-audio-lang.m4a');
    await audioDraftFile.writeAsString('audio');

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    transcriptionService.nextStopResult = TranscriptionFailure(
      reason: TranscriptionFailureReason.speechNotRecognized,
      audioDraftPath: audioDraftFile.path,
      requestedLanguage: 'de-CH',
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(entryRepository.savedAudioDrafts, [(audioDraftFile.path, 'de-CH')]);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingErrorState(
        RecordingError.speechNotRecognized,
        preservedDraft: true,
      ),
    );
  });

  test('nothingCaught with audioDraftPath keeps no-match feedback and skips draft persistence', () async {
    final audioDraftFile = File('${tempDirectory.path}/retry-audio.m4a');
    await audioDraftFile.writeAsString('audio');

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    transcriptionService.nextStopResult = TranscriptionFailure(
      reason: TranscriptionFailureReason.nothingCaught,
      audioDraftPath: audioDraftFile.path,
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(entryRepository.savedAudioDrafts, isEmpty);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingErrorState(RecordingError.noMatch),
    );
  });

  test('transcription success without usable words keeps no-match feedback, skips cleanup, and publishes quota', () async {
    final quota = RecordQuotaState(
      limit: 5,
      count: 5,
      remaining: 0,
      resetAt: DateTime.utc(2026, 6, 12),
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    transcriptionService.nextStopResult = TranscriptionSuccess(
      transcript: ' ... ',
      detectedLanguage: 'en-US',
      quota: quota,
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(cleanupUseCase.calls, isEmpty);
    expect(entryRepository.savedAudioDrafts, isEmpty);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingErrorState(RecordingError.noMatch),
    );
    expect(container.read(sessionRecordQuotaStateProvider), quota);
  });

  test('transcription failure with audioDraftPath persistence failure keeps fallback error copy without preservedDraft', () async {
    final audioDraftFile = File('${tempDirectory.path}/retry-audio.m4a');
    await audioDraftFile.writeAsString('audio');
    entryRepository.failSaveAudioDraft = true;

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    transcriptionService.nextStopResult = TranscriptionFailure(
      reason: TranscriptionFailureReason.network,
      audioDraftPath: audioDraftFile.path,
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(entryRepository.savedAudioDrafts, isEmpty);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingErrorState(RecordingError.noInternet),
    );
    expect(
      logMessages,
      contains(
        'Failed to persist retryable audio draft after transcription failure.',
      ),
    );
    expect(logErrors.last, isA<StateError>());
  });

  test('transcription failure with missing audioDraftPath keeps the original error and skips draft persistence', () async {
    final missingAudioPath = '${tempDirectory.path}/missing-audio.m4a';

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    transcriptionService.nextStopResult = TranscriptionFailure(
      reason: TranscriptionFailureReason.network,
      audioDraftPath: '  $missingAudioPath  ',
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(entryRepository.savedAudioDrafts, isEmpty);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingErrorState(RecordingError.noInternet),
    );
    expect(
      logMessages,
      contains(
        'Ignoring retryable audio draft path because it is not a readable file.',
      ),
    );
  });

  test('cleanup failure preserves the draft, publishes mapped Error, and does not set hasEverRecorded', () async {
    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    cleanupUseCase.nextResult = const CleanupTranscriptFailure(
      entryId: 41,
      reason: backend.BackendFailureReason.backendUnavailable,
    );
    transcriptionService.nextStopResult = const TranscriptionSuccess(
      transcript: 'raw transcript',
      detectedLanguage: 'en-US',
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(cleanupUseCase.calls.single.rawTranscript, 'raw transcript');
    expect(preferencesRepository.hasEverRecorded, isFalse);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingErrorState(
        RecordingError.backendUnavailable,
        preservedDraft: true,
      ),
    );
    expect(container.read(mainRecordingControllerProvider).shakeErrorKey, 0);
  });

  test('cleanup receives transcription quota as a fallback when cleanup quota is absent', () async {
    final fallbackQuota = RecordQuotaState(
      limit: 5,
      count: 3,
      remaining: 2,
      resetAt: DateTime.utc(2026, 6, 12),
    );
    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    cleanupUseCase.nextResult = const CleanupTranscriptFailure(
      entryId: 41,
      reason: backend.BackendFailureReason.backendUnavailable,
    );
    transcriptionService.nextStopResult = TranscriptionSuccess(
      transcript: 'raw transcript',
      detectedLanguage: 'en-US',
      quota: fallbackQuota,
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(cleanupUseCase.calls.single.fallbackQuota, fallbackQuota);
  });

  test('draft-preserved errors do not increment the shake key', () async {
    final audioDraftFile = File('${tempDirectory.path}/retry-audio.m4a');
    await audioDraftFile.writeAsString('audio');

    Future<void> triggerTranscriptionDraftError(
      TranscriptionFailureReason reason,
    ) async {
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      monotonicClock.advance(const Duration(seconds: 6));
      transcriptionService.nextStopResult = TranscriptionFailure(
        reason: reason,
        audioDraftPath: audioDraftFile.path,
      );
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
    }

    Future<void> triggerCleanupDraftError(
      backend.BackendFailureReason reason,
    ) async {
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      monotonicClock.advance(const Duration(seconds: 6));
      cleanupUseCase.nextResult = CleanupTranscriptFailure(
        entryId: 41,
        reason: reason,
      );
      transcriptionService.nextStopResult = const TranscriptionSuccess(
        transcript: 'raw transcript',
        detectedLanguage: 'en-US',
      );
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
    }

    await triggerTranscriptionDraftError(TranscriptionFailureReason.network);
    expect(container.read(mainRecordingControllerProvider).shakeErrorKey, 0);

    await Future<void>.delayed(const Duration(milliseconds: 5));

    await triggerCleanupDraftError(
      backend.BackendFailureReason.backendUnavailable,
    );
    expect(container.read(mainRecordingControllerProvider).shakeErrorKey, 0);

    await Future<void>.delayed(const Duration(milliseconds: 5));

    await triggerTranscriptionDraftError(
      TranscriptionFailureReason.proxyAuthFailed,
    );
    expect(container.read(mainRecordingControllerProvider).shakeErrorKey, 0);

    await Future<void>.delayed(const Duration(milliseconds: 5));

    await triggerCleanupDraftError(backend.BackendFailureReason.apiError);
    expect(container.read(mainRecordingControllerProvider).shakeErrorKey, 0);
  });

  test('cleanup success still publishes Saved when preference persistence logs a warning', () async {
    preferencesRepository.failSetHasEverRecorded = true;
    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    cleanupUseCase.nextResult = const CleanupTranscriptSuccess(
      entryId: 50,
      cleanedText: 'cleaned',
    );
    transcriptionService.nextStopResult = const TranscriptionSuccess(
      transcript: 'raw transcript',
      detectedLanguage: 'nl-NL',
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      RecordingSaved(entryId: 50, detectedLanguage: 'nl-NL'),
    );
    expect(logMessages.single, contains('hasEverRecorded'));
    expect(logErrors.single, isA<StateError>());
  });

  test('cleanup success with a non-positive entry id publishes ApiFailed and does not set hasEverRecorded', () async {
    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    cleanupUseCase.nextResult = const CleanupTranscriptSuccess(
      entryId: 0,
      cleanedText: 'cleaned',
    );
    transcriptionService.nextStopResult = const TranscriptionSuccess(
      transcript: 'raw transcript',
      detectedLanguage: 'en-US',
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(preferencesRepository.hasEverRecorded, isFalse);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingErrorState(RecordingError.apiFailed),
    );
    expect(
      logMessages,
      contains(
        'Cleanup succeeded without a valid entry id; Saved state was not published.',
      ),
    );
    expect(logErrors.last, isA<ArgumentError>());
  });

  test('Deleted feedback ignores non-positive counts, publishes positive counts, and auto-clears', () async {
    container
        .read(mainRecordingControllerProvider.notifier)
        .onEntriesDeleted(0);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingIdle(),
    );

    container
        .read(mainRecordingControllerProvider.notifier)
        .onEntriesDeleted(3);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingDeleted(3),
    );

    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingIdle(),
    );
  });

  test(
    'Saved feedback does not auto-clear and clears through clearSaved',
    () async {
      await driveSuccessfulSave(entryId: 70);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingSaved(entryId: 70, detectedLanguage: 'en-US'),
      );

      container.read(mainRecordingControllerProvider.notifier).clearSaved();

      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingIdle(),
      );
    },
  );

  test('rapid repeated taps while start is in flight trigger only one start attempt', () async {
    final startCompleter = Completer<void>();
    transcriptionService.startFutureFactory = (onStatus) async {
      await startCompleter.future;
      final status = RecordingStarted(120000);
      transcriptionService.statusHistory.add(status);
      onStatus(status);
    };

    final firstTap = container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    final secondTap = container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(transcriptionService.startCallCount, 1);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingIdle(),
    );

    startCompleter.complete();
    await Future.wait([firstTap, secondTap]);

    expect(transcriptionService.startCallCount, 1);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
    );
  });

  test(
    'starting a new recording cancels a stale Error auto-clear timer',
    () async {
      container.dispose();
      container = buildContainer(
        feedbackDelays: const RecordingFeedbackDelays(
          errorAndDeletedAutoClear: Duration(milliseconds: 20),
        ),
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      transcriptionService.nextStopResult = const TranscriptionFailure(
        reason: TranscriptionFailureReason.tooShort,
      );
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(RecordingError.tooShort),
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
      );
    },
  );

  test('rapid error-to-error transitions keep the newer error until its own auto-clear fires', () async {
    container.dispose();
    container = buildContainer(
      feedbackDelays: const RecordingFeedbackDelays(
        errorAndDeletedAutoClear: Duration(milliseconds: 60),
      ),
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    transcriptionService.nextStopResult = const TranscriptionFailure(
      reason: TranscriptionFailureReason.tooShort,
    );
    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingErrorState(RecordingError.tooShort),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    transcriptionService.nextStopResult = const TranscriptionFailure(
      reason: TranscriptionFailureReason.apiError,
    );
    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingErrorState(RecordingError.apiFailed),
    );

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingErrorState(RecordingError.apiFailed),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingIdle(),
    );
  });

  test(
    'starting a new recording cancels a stale Deleted auto-clear timer',
    () async {
      container.dispose();
      container = buildContainer(
        feedbackDelays: const RecordingFeedbackDelays(
          errorAndDeletedAutoClear: Duration(milliseconds: 20),
        ),
      );

      container
          .read(mainRecordingControllerProvider.notifier)
          .onEntriesDeleted(2);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingDeleted(2),
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
      );
    },
  );

  group('auto-tag detection', () {
    const twoTags = <Tag>[
      Tag(id: 1, name: 'work'),
      Tag(id: 2, name: 'family'),
    ];

    test(
      'cleanup success with auto-tag success invokes auto-tag use case and publishes Saved',
      () async {
        tagRepository.tags = twoTags;
        tagTextCallback.nextResult = const backend.TagTextSuccess(
          tags: [backend.TagProbabilityResult(tag: 'work', probability: 0.9)],
        );

        await driveSuccessfulSave(entryId: 77);

        expect(tagTextCallback.calls, hasLength(1));
        expect(tagTextCallback.calls.single.text, 'raw transcript');
        expect(tagTextCallback.calls.single.tags, ['work', 'family']);
        expect(autoTagUseCase.calls, hasLength(1));
        expect(autoTagUseCase.calls.single.entryId, 77);
        expect(autoTagUseCase.calls.single.userTags, twoTags);
        final tagResult = await autoTagUseCase.calls.single.tagResultFuture;
        expect(tagResult, isA<backend.TagTextSuccess>());
        expect(
          container.read(mainRecordingControllerProvider).recordingState,
          RecordingSaved(entryId: 77, detectedLanguage: 'en-US'),
        );
      },
    );

    test(
      'cleanup success with auto-tag failure still publishes Saved',
      () async {
        tagRepository.tags = twoTags;
        tagTextCallback.nextResult = const backend.TagTextFailure(
          reason: backend.BackendFailureReason.apiError,
        );

        await driveSuccessfulSave(entryId: 78);

        expect(tagTextCallback.calls, hasLength(1));
        expect(autoTagUseCase.calls, hasLength(1));
        final tagResult = await autoTagUseCase.calls.single.tagResultFuture;
        expect(tagResult, isA<backend.TagTextFailure>());
        expect(
          container.read(mainRecordingControllerProvider).recordingState,
          RecordingSaved(entryId: 78, detectedLanguage: 'en-US'),
        );
      },
    );

    test('cleanup failure does not run auto-tag use case', () async {
      tagRepository.tags = twoTags;
      cleanupUseCase.nextResult = const CleanupTranscriptFailure(
        entryId: 5,
        reason: backend.BackendFailureReason.apiError,
      );
      transcriptionService.nextStopResult = const TranscriptionSuccess(
        transcript: 'raw transcript',
        detectedLanguage: 'en-US',
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      monotonicClock.advance(const Duration(seconds: 6));
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(autoTagUseCase.calls, isEmpty);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        isA<RecordingErrorState>(),
      );
    });

    test('fewer than two tags makes no tag API call', () async {
      tagRepository.tags = const [Tag(id: 1, name: 'work')];

      await driveSuccessfulSave(entryId: 79);

      expect(tagTextCallback.calls, isEmpty);
      expect(autoTagUseCase.calls, isEmpty);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingSaved(entryId: 79, detectedLanguage: 'en-US'),
      );
    });

    test(
      'whitespace-only transcript is rejected before cleanup and makes no tag API call',
      () async {
        tagRepository.tags = twoTags;
        transcriptionService.nextStopResult = const TranscriptionSuccess(
          transcript: '   ',
          detectedLanguage: 'en-US',
        );

        await container
            .read(mainRecordingControllerProvider.notifier)
            .onMainButtonTapped();
        monotonicClock.advance(const Duration(seconds: 6));
        await container
            .read(mainRecordingControllerProvider.notifier)
            .onMainButtonTapped();

        expect(cleanupUseCase.calls, isEmpty);
        expect(tagTextCallback.calls, isEmpty);
        expect(autoTagUseCase.calls, isEmpty);
        expect(
          container.read(mainRecordingControllerProvider).recordingState,
          const RecordingErrorState(RecordingError.noMatch),
        );
      },
    );

    test('tag repository failure does not block the save flow', () async {
      tagRepository.getAllTagsError = StateError('db unavailable');

      await driveSuccessfulSave(entryId: 80);

      expect(tagTextCallback.calls, isEmpty);
      expect(autoTagUseCase.calls, isEmpty);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingSaved(entryId: 80, detectedLanguage: 'en-US'),
      );
    });
  });
}

class _CleanupCall {
  const _CleanupCall({
    required this.rawTranscript,
    required this.language,
    required this.entryId,
    required this.fallbackQuota,
  });

  final String rawTranscript;
  final String? language;
  final int? entryId;
  final RecordQuotaState? fallbackQuota;
}

class _FakeTranscriptionService implements TranscriptionService {
  int startCallCount = 0;
  int stopCallCount = 0;
  int cancelCallCount = 0;
  Object? startError;
  TranscriptionResult nextStopResult = const TranscriptionFailure(
    reason: TranscriptionFailureReason.apiError,
  );
  final List<TranscriptionStatus> statusHistory = <TranscriptionStatus>[];
  Future<void> Function(TranscriptionStatusCallback onStatus)?
  startFutureFactory;
  Future<TranscriptionResult> Function()? stopFutureFactory;
  bool _isRecording = false;
  bool _isTranscribing = false;
  int nextHardCapDeadlineElapsedRealtime = 120000;
  int? _hardCapDeadlineElapsedRealtime;

  @override
  int? get hardCapDeadlineElapsedRealtime => _hardCapDeadlineElapsedRealtime;

  @override
  bool get isRecording => _isRecording;

  @override
  bool get isTranscribing => _isTranscribing;

  @override
  Future<void> startLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    startCallCount += 1;
    if (startError case final error?) {
      startError = null;
      throw error;
    }
    _isRecording = true;
    _hardCapDeadlineElapsedRealtime = nextHardCapDeadlineElapsedRealtime;
    final pendingStart = startFutureFactory?.call(onStatus);
    if (pendingStart != null) {
      await pendingStart;
      return;
    }
    final status = RecordingStarted(_hardCapDeadlineElapsedRealtime!);
    statusHistory.add(status);
    onStatus(status);
  }

  @override
  Future<TranscriptionResult> stopLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    stopCallCount += 1;
    _isRecording = false;
    final pendingResult = stopFutureFactory?.call();
    final immediateResult = pendingResult == null ? nextStopResult : null;

    if (immediateResult case TranscriptionFailure(reason: final reason)
        when reason == TranscriptionFailureReason.tooShort) {
      return immediateResult;
    }

    _isTranscribing = true;
    const status = Uploading();
    statusHistory.add(status);
    onStatus(status);
    final result = pendingResult != null
        ? await pendingResult
        : immediateResult!;
    _isTranscribing = false;
    return result;
  }

  @override
  Future<void> cancelLiveTranscription() async {
    cancelCallCount += 1;
    _isRecording = false;
    _isTranscribing = false;
    _hardCapDeadlineElapsedRealtime = null;
  }

  @override
  Future<TranscriptionResult> transcribeAudioDraft(String audioPath) async {
    return nextStopResult;
  }
}

class _FakeMicrophonePermissionService implements MicrophonePermissionService {
  MicrophoneAccessState currentState = MicrophoneAccessState.permanentlyDenied;
  int getCallCount = 0;
  int requestCallCount = 0;
  int openSettingsCallCount = 0;
  bool openSettingsResult = true;
  Future<MicrophoneAccessState> Function()? getFutureFactory;

  @override
  Future<MicrophoneAccessState> getMicrophoneAccess() async {
    getCallCount += 1;
    final pendingResult = getFutureFactory?.call();
    if (pendingResult != null) {
      return pendingResult;
    }
    return currentState;
  }

  @override
  Future<bool> openMicrophonePermissionSettings() async {
    openSettingsCallCount += 1;
    return openSettingsResult;
  }

  @override
  Future<MicrophoneAccessState> requestMicrophoneAccess() async {
    requestCallCount += 1;
    return currentState;
  }
}

class _FakeCleanupTranscriptUseCase extends CleanupTranscriptUseCase {
  _FakeCleanupTranscriptUseCase()
    : super(
        cleanupTranscript: ({required transcript, required language}) async =>
            const backend.CleanupFailure(
              reason: backend.BackendFailureReason.apiError,
            ),
        entryRepository: _FakeEntryRepository(),
        setRecordQuota: (_) {},
        logWarning: (_, {error, stackTrace}) {},
      );

  CleanupTranscriptResult nextResult = const CleanupTranscriptFailure(
    entryId: 1,
    reason: backend.BackendFailureReason.apiError,
  );
  final List<_CleanupCall> calls = <_CleanupCall>[];

  @override
  Future<CleanupTranscriptResult> call({
    required String rawTranscript,
    String? language,
    int? entryId,
    RecordQuotaState? fallbackQuota,
  }) async {
    calls.add(
      _CleanupCall(
        rawTranscript: rawTranscript,
        language: language,
        entryId: entryId,
        fallbackQuota: fallbackQuota,
      ),
    );
    return nextResult;
  }
}

class _FakeEntryRepository implements EntryRepository {
  final List<(String, String)> savedAudioDrafts = <(String, String)>[];
  bool failSaveAudioDraft = false;

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
  Future<int> saveAudioDraft(String audioPath, String language) async {
    if (failSaveAudioDraft) {
      throw StateError('saveAudioDraft failed');
    }
    savedAudioDrafts.add((audioPath, language));
    return 1;
  }

  @override
  Future<int> saveDraft(String transcript, String language) async => 1;

  @override
  Future<int> saveEntry(String transcript, String language) async => 1;

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {}

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
  bool hasEverRecorded = false;
  bool failSetHasEverRecorded = false;

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => hasEverRecorded;

  @override
  Future<void> setHasEverRecorded(bool value) async {
    if (failSetHasEverRecorded) {
      throw StateError('Failed to persist hasEverRecorded');
    }
    hasEverRecorded = value;
  }
}

class _TagTextCall {
  const _TagTextCall({required this.text, required this.tags});

  final String text;
  final List<String> tags;
}

class _FakeTagTextCallback {
  backend.TagTextResult nextResult = const backend.TagTextSuccess(tags: []);
  final List<_TagTextCall> calls = <_TagTextCall>[];

  Future<backend.TagTextResult> call({
    required String text,
    required List<String> tags,
  }) async {
    calls.add(_TagTextCall(text: text, tags: tags));
    return nextResult;
  }
}

class _AutoTagCall {
  const _AutoTagCall({
    required this.entryId,
    required this.tagResultFuture,
    required this.userTags,
  });

  final int entryId;
  final Future<backend.TagTextResult> tagResultFuture;
  final List<Tag> userTags;
}

class _FakeAutoTagUseCase extends AutoTagUseCase {
  _FakeAutoTagUseCase(TagRepository tagRepository)
    : super(
        tagRepository: tagRepository,
        logWarning: (_, {error, stackTrace}) {},
      );

  final List<_AutoTagCall> calls = <_AutoTagCall>[];

  @override
  Future<void> call({
    required int entryId,
    required Future<backend.TagTextResult> tagResultFuture,
    required List<Tag> userTags,
  }) async {
    calls.add(
      _AutoTagCall(
        entryId: entryId,
        tagResultFuture: tagResultFuture,
        userTags: userTags,
      ),
    );
  }
}

class _FakeTagRepository implements TagRepository {
  List<Tag> tags = const <Tag>[];
  Object? getAllTagsError;

  @override
  Future<List<Tag>> getAllTags() async {
    if (getAllTagsError case final error?) {
      throw error;
    }
    return tags;
  }

  @override
  Stream<List<Tag>> watchAllTags() => throw UnimplementedError();

  @override
  Stream<List<Tag>> watchTagsForEntry(int entryId) =>
      throw UnimplementedError();

  @override
  Future<List<Tag>> getTagsForEntry(int entryId) => throw UnimplementedError();

  @override
  Future<Map<int, int>> getTagCounts() => throw UnimplementedError();

  @override
  Future<Tag> createTag(String name) => throw UnimplementedError();

  @override
  Future<Tag?> findTagByName(String name) => throw UnimplementedError();

  @override
  Future<void> deleteTag(int id) => throw UnimplementedError();

  @override
  Future<void> setTagsForEntry(int entryId, List<int> tagIds) =>
      throw UnimplementedError();
}
