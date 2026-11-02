import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/audio/microphone_permission_service.dart';
import 'package:wrait/data/audio/audio_recording_service.dart';
import 'package:wrait/data/transcription/cloud_transcription_service.dart';
import 'package:wrait/data/transcription/transcription_service.dart';

void main() {
  late Directory tempDirectory;
  late _FakeAudioRecordingService audioRecordingService;
  late List<String> logMessages;
  late List<Object?> logErrors;
  late String livePath;
  late CloudTranscriptionService service;
  late Future<backend.TranscriptionResult> Function(File audioFile) transcribe;
  late int transcribeCallCount;
  String? uploadedLanguage;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'wrait-cloud-transcription-test',
    );
    audioRecordingService = _FakeAudioRecordingService();
    logMessages = <String>[];
    logErrors = <Object?>[];
    livePath = '${tempDirectory.path}/live.m4a';
    transcribeCallCount = 0;
    transcribe = (_) async => const backend.TranscriptionSuccess(
      transcript: 'raw transcript',
      detectedLanguage: 'en-US',
    );
    service = CloudTranscriptionService(
      audioRecordingService: audioRecordingService,
      transcribeAudio: (audioFile, {language}) {
        transcribeCallCount += 1;
        uploadedLanguage = language;
        return transcribe(audioFile);
      },
      createLiveRecordingPath: () async => livePath,
      logWarning: (message, {error, stackTrace}) {
        logMessages.add(message);
        logErrors.add(error);
      },
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('start emits RecordingStarted with the recording deadline', () async {
    final statuses = <TranscriptionStatus>[];

    await service.startLiveTranscription(onStatus: statuses.add);

    expect(service.isRecording, isTrue);
    expect(statuses, hasLength(1));
    expect(
      statuses.single,
      isA<RecordingStarted>().having(
        (value) => value.hardCapDeadlineElapsedRealtime,
        'hardCapDeadlineElapsedRealtime',
        120000,
      ),
    );
    expect(audioRecordingService.startedPaths.single, livePath);
  });

  test('live transcription keeps the language captured at start', () async {
    var selectedLanguage = 'uk';
    service = CloudTranscriptionService(
      audioRecordingService: audioRecordingService,
      transcribeAudio: (audioFile, {language}) async {
        uploadedLanguage = language;
        return const backend.TranscriptionSuccess(
          transcript: 'raw transcript',
          detectedLanguage: 'uk',
        );
      },
      createLiveRecordingPath: () async => livePath,
      readLanguageSnapshot: () async => selectedLanguage,
    );

    await service.startLiveTranscription(onStatus: (_) {});
    selectedLanguage = 'en';
    await service.stopLiveTranscription(onStatus: (_) {});

    expect(uploadedLanguage, 'uk');
  });

  test('denied microphone access surfaces a typed start failure', () async {
    audioRecordingService.startFailure = const RecordingPermissionDeniedFailure(
      MicrophoneAccessState.denied,
    );

    await expectLater(
      service.startLiveTranscription(onStatus: (_) {}),
      throwsA(
        isA<MicBlockedTranscriptionServiceFailure>().having(
          (error) => error.accessState,
          'accessState',
          MicrophoneAccessState.denied,
        ),
      ),
    );

    expect(service.isRecording, isFalse);
    expect(service.isTranscribing, isFalse);
  });

  test(
    'cancelLiveTranscription cancels recording without uploading audio',
    () async {
      await service.startLiveTranscription(onStatus: (_) {});

      await service.cancelLiveTranscription();

      expect(audioRecordingService.cancelCallCount, 1);
      expect(transcribeCallCount, 0);
      expect(service.isRecording, isFalse);
      expect(service.isTranscribing, isFalse);
      expect(await File(livePath).exists(), isFalse);
    },
  );

  test(
    'cancelLiveTranscription is a no-op when no live recording is active',
    () async {
      await service.cancelLiveTranscription();

      expect(audioRecordingService.cancelCallCount, 0);
      expect(service.isRecording, isFalse);
      expect(service.isTranscribing, isFalse);
    },
  );

  test('cancelLiveTranscription logs cancel failures and keeps the live session recoverable', () async {
    await service.startLiveTranscription(onStatus: (_) {});
    audioRecordingService.cancelFailure = StateError('cancel failed');

    await expectLater(
      service.cancelLiveTranscription(),
      throwsA(isA<StateError>()),
    );

    expect(
      logMessages,
      contains('Cloud transcription failed to cancel live recording.'),
    );
    expect(logErrors.single, isA<StateError>());
    expect(service.isRecording, isTrue);
    expect(service.isTranscribing, isFalse);

    final result = await service.stopLiveTranscription(onStatus: (_) {});

    expect(result, isA<TranscriptionSuccess>());
  });

  test('successful live transcription uploads and deletes the temp file without publishing quota directly', () async {
    final quota = RecordQuotaState(
      limit: 5,
      count: 2,
      remaining: 3,
      resetAt: DateTime.utc(2026, 6, 12),
    );
    transcribe = (audioFile) async {
      expect(audioFile.path, livePath);
      return backend.TranscriptionSuccess(
        transcript: 'raw transcript',
        detectedLanguage: 'FR_fr',
        quota: quota,
      );
    };

    final statuses = <TranscriptionStatus>[];
    await service.startLiveTranscription(onStatus: statuses.add);
    final result = await service.stopLiveTranscription(onStatus: statuses.add);

    expect(statuses, [isA<RecordingStarted>(), isA<Uploading>()]);
    expect(
      result,
      isA<TranscriptionSuccess>()
          .having((value) => value.transcript, 'transcript', 'raw transcript')
          .having(
            (value) => value.detectedLanguage,
            'detectedLanguage',
            'fr-FR',
          )
          .having((value) => value.quota?.remaining, 'quotaRemaining', 3),
    );
    expect(await File(livePath).exists(), isFalse);
    expect(service.isRecording, isFalse);
    expect(service.isTranscribing, isFalse);
  });

  test(
    'live transcription succeeds without detected language when unsupported',
    () async {
      final invalidLanguages = <String>[
        'zz-ZZ',
        ' zh-Hans-CN ',
        'en-001',
        '   ',
      ];

      for (final invalidLanguage in invalidLanguages) {
        transcribe = (_) async => backend.TranscriptionSuccess(
          transcript: 'raw transcript',
          detectedLanguage: invalidLanguage,
        );

        await service.startLiveTranscription(onStatus: (_) {});
        final result = await service.stopLiveTranscription(onStatus: (_) {});

        expect(
          result,
          isA<TranscriptionSuccess>().having(
            (value) => value.detectedLanguage,
            'detectedLanguage',
            isNull,
          ),
        );
        expect(await File(livePath).exists(), isFalse);
      }
    },
  );

  test('stop throws when no live transcription is active', () async {
    await expectLater(
      service.stopLiveTranscription(onStatus: (_) {}),
      throwsA(isA<NoActiveLiveTranscriptionFailure>()),
    );
  });

  test(
    'stop releases the session when the recorder stopped externally',
    () async {
      final activity = <bool>[];
      service = CloudTranscriptionService(
        audioRecordingService: audioRecordingService,
        transcribeAudio: (audioFile, {language}) => transcribe(audioFile),
        createLiveRecordingPath: () async => livePath,
        onActivityChanged: activity.add,
      );
      await service.startLiveTranscription(onStatus: (_) {});
      audioRecordingService.isRecording = false;

      await expectLater(
        service.stopLiveTranscription(onStatus: (_) {}),
        throwsA(isA<NoActiveLiveTranscriptionFailure>()),
      );

      expect(activity, <bool>[true, false]);
      await service.startLiveTranscription(onStatus: (_) {});
      expect(service.isRecording, isTrue);
    },
  );

  test(
    'cancel releases the session when the recorder stopped externally',
    () async {
      final activity = <bool>[];
      service = CloudTranscriptionService(
        audioRecordingService: audioRecordingService,
        transcribeAudio: (audioFile, {language}) => transcribe(audioFile),
        createLiveRecordingPath: () async => livePath,
        onActivityChanged: activity.add,
      );
      await service.startLiveTranscription(onStatus: (_) {});
      audioRecordingService.isRecording = false;

      await service.cancelLiveTranscription();

      expect(audioRecordingService.cancelCallCount, 0);
      expect(activity, <bool>[true, false]);
      await service.startLiveTranscription(onStatus: (_) {});
      expect(service.isRecording, isTrue);
    },
  );

  test('start surfaces a typed failure and releases activity when the saved '
      'language cannot be read', () async {
    final activity = <bool>[];
    service = CloudTranscriptionService(
      audioRecordingService: audioRecordingService,
      transcribeAudio: (audioFile, {language}) => transcribe(audioFile),
      createLiveRecordingPath: () async => livePath,
      readLanguageSnapshot: () async => throw StateError('load failed'),
      onActivityChanged: activity.add,
    );

    await expectLater(
      service.startLiveTranscription(onStatus: (_) {}),
      throwsA(isA<TranscriptionLanguageUnavailableFailure>()),
    );

    expect(audioRecordingService.startedPaths, isEmpty);
    expect(activity, <bool>[true, false]);
    expect(service.isRecording, isFalse);
  });

  test(
    'failed live transcription preserves the audio path for retry',
    () async {
      final quota = RecordQuotaState(
        limit: 5,
        count: 5,
        remaining: 0,
        resetAt: DateTime.utc(2026, 6, 12),
      );
      transcribe = (_) async => backend.TranscriptionFailure(
        reason: backend.BackendFailureReason.noInternet,
        quota: quota,
      );

      await service.startLiveTranscription(onStatus: (_) {});
      final result = await service.stopLiveTranscription(onStatus: (_) {});

      expect(
        result,
        isA<TranscriptionFailure>()
            .having(
              (value) => value.reason,
              'reason',
              TranscriptionFailureReason.network,
            )
            .having((value) => value.audioDraftPath, 'audioDraftPath', livePath)
            .having((value) => value.quota?.remaining, 'quotaRemaining', 0),
      );
      expect(await File(livePath).exists(), isTrue);
      expect(logMessages.single, contains('noInternet'));
    },
  );

  test(
    'draft transcription leaves caller-owned audio untouched on success',
    () async {
      final draftPath = '${tempDirectory.path}/draft.m4a';
      await File(draftPath).writeAsBytes(const <int>[1, 2, 3]);

      transcribe = (audioFile) async {
        expect(audioFile.path, draftPath);
        return const backend.TranscriptionSuccess(
          transcript: 'draft transcript',
          detectedLanguage: 'en-US',
        );
      };

      final result = await service.transcribeAudioDraft(draftPath);

      expect(
        result,
        isA<TranscriptionSuccess>().having(
          (value) => value.detectedLanguage,
          'detectedLanguage',
          'en-US',
        ),
      );
      expect(await File(draftPath).exists(), isTrue);
    },
  );

  test(
    'each draft retry keeps the language captured at its own start',
    () async {
      final draftPath = '${tempDirectory.path}/draft-language.m4a';
      await File(draftPath).writeAsBytes(const <int>[1, 2, 3]);
      var selectedLanguage = 'fr';
      final firstUploadStarted = Completer<void>();
      final firstUploadResult = Completer<backend.TranscriptionResult>();
      final uploadedLanguages = <String?>[];
      var uploadCount = 0;
      service = CloudTranscriptionService(
        audioRecordingService: audioRecordingService,
        transcribeAudio: (audioFile, {language}) {
          uploadedLanguages.add(language);
          uploadCount += 1;
          if (uploadCount == 1) {
            firstUploadStarted.complete();
            return firstUploadResult.future;
          }
          return Future<backend.TranscriptionResult>.value(
            const backend.TranscriptionSuccess(
              transcript: 'second retry',
              detectedLanguage: 'en',
            ),
          );
        },
        createLiveRecordingPath: () async => livePath,
        readLanguageSnapshot: () async => selectedLanguage,
      );

      final firstRetry = service.transcribeAudioDraft(draftPath);
      await firstUploadStarted.future;
      selectedLanguage = 'en';
      firstUploadResult.complete(
        const backend.TranscriptionSuccess(
          transcript: 'first retry',
          detectedLanguage: 'fr',
        ),
      );
      await firstRetry;
      await service.transcribeAudioDraft(draftPath);

      expect(uploadedLanguages, <String?>['fr', 'en']);
    },
  );

  test(
    'unexpected upload exceptions return apiError and preserve live audio',
    () async {
      transcribe = (_) async => throw StateError('boom');

      await service.startLiveTranscription(onStatus: (_) {});
      final result = await service.stopLiveTranscription(onStatus: (_) {});

      expect(
        result,
        isA<TranscriptionFailure>()
            .having(
              (value) => value.reason,
              'reason',
              TranscriptionFailureReason.apiError,
            )
            .having(
              (value) => value.audioDraftPath,
              'audioDraftPath',
              livePath,
            ),
      );
      expect(await File(livePath).exists(), isTrue);
      expect(logErrors.single, isA<StateError>());
    },
  );

  test(
    'too-short live stop returns a typed failure without uploading',
    () async {
      await service.startLiveTranscription(onStatus: (_) {});
      audioRecordingService.stopFailure = const RecordingTooShortFailure();

      final result = await service.stopLiveTranscription(onStatus: (_) {});

      expect(
        result,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          TranscriptionFailureReason.tooShort,
        ),
      );
      expect(transcribeCallCount, 0);
      expect(service.isRecording, isFalse);
      expect(service.isTranscribing, isFalse);
    },
  );

  test('blank live transcript success becomes nothingCaught, deletes live audio, and leaves quota publication to the caller', () async {
    final quota = RecordQuotaState(
      limit: 5,
      count: 5,
      remaining: 0,
      resetAt: DateTime.utc(2026, 6, 12),
    );
    transcribe = (_) async => backend.TranscriptionSuccess(
      transcript: '   ',
      detectedLanguage: 'en-US',
      quota: quota,
    );

    await service.startLiveTranscription(onStatus: (_) {});
    final result = await service.stopLiveTranscription(onStatus: (_) {});

    expect(
      result,
      isA<TranscriptionFailure>()
          .having(
            (value) => value.reason,
            'reason',
            TranscriptionFailureReason.nothingCaught,
          )
          .having((value) => value.audioDraftPath, 'audioDraftPath', isNull)
          .having((value) => value.quota?.remaining, 'quotaRemaining', 0),
    );
    expect(await File(livePath).exists(), isFalse);
  });

  test('punctuation-only live transcript success becomes nothingCaught and deletes live audio', () async {
    transcribe = (_) async => const backend.TranscriptionSuccess(
      transcript: ' ... ',
      detectedLanguage: 'en-US',
    );

    await service.startLiveTranscription(onStatus: (_) {});
    final result = await service.stopLiveTranscription(onStatus: (_) {});

    expect(
      result,
      isA<TranscriptionFailure>().having(
        (value) => value.reason,
        'reason',
        TranscriptionFailureReason.nothingCaught,
      ),
    );
    expect(await File(livePath).exists(), isFalse);
    expect(logMessages.single, contains('non-usable transcript'));
  });

  test('non-Latin script transcript is accepted as usable content', () async {
    transcribe = (_) async => const backend.TranscriptionSuccess(
      transcript: 'તો વરદાન રાખી લે',
      detectedLanguage: 'gu',
    );

    await service.startLiveTranscription(onStatus: (_) {});
    final result = await service.stopLiveTranscription(onStatus: (_) {});

    expect(
      result,
      isA<TranscriptionSuccess>().having(
        (value) => value.transcript,
        'transcript',
        'તો વરદાન રાખી લે',
      ),
    );
  });

  test('rejects new work while another transcription is in progress', () async {
    final startedCompleter = Completer<void>();
    final resultCompleter = Completer<backend.TranscriptionResult>();
    final draftPath = '${tempDirectory.path}/draft.m4a';
    final secondDraftPath = '${tempDirectory.path}/draft-2.m4a';
    await File(draftPath).writeAsBytes(const <int>[1, 2, 3]);
    await File(secondDraftPath).writeAsBytes(const <int>[4, 5, 6]);
    transcribe = (_) {
      if (!startedCompleter.isCompleted) {
        startedCompleter.complete();
      }
      return resultCompleter.future;
    };

    final firstCall = service.transcribeAudioDraft(draftPath);
    await startedCompleter.future;

    await expectLater(
      service.transcribeAudioDraft(secondDraftPath),
      throwsA(isA<TranscriptionAlreadyInProgressFailure>()),
    );

    resultCompleter.complete(
      const backend.TranscriptionSuccess(
        transcript: 'finished',
        detectedLanguage: 'en-US',
      ),
    );
    await expectLater(firstCall, completion(isA<TranscriptionSuccess>()));
  });

  test(
    'rejects a second live start while the first live start is in progress',
    () async {
      final livePathCompleter = Completer<String>();
      service = CloudTranscriptionService(
        audioRecordingService: audioRecordingService,
        transcribeAudio: (audioFile, {language}) {
          transcribeCallCount += 1;
          return transcribe(audioFile);
        },
        createLiveRecordingPath: () => livePathCompleter.future,
        logWarning: (message, {error, stackTrace}) {
          logMessages.add(message);
          logErrors.add(error);
        },
      );

      final firstStart = service.startLiveTranscription(onStatus: (_) {});
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        service.startLiveTranscription(onStatus: (_) {}),
        throwsA(isA<TranscriptionAlreadyInProgressFailure>()),
      );

      livePathCompleter.complete(livePath);
      await firstStart;
      expect(service.isRecording, isTrue);
    },
  );

  test(
    'draft transcription fails fast for a blank path without uploading',
    () async {
      final result = await service.transcribeAudioDraft('   ');

      expect(
        result,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          TranscriptionFailureReason.apiError,
        ),
      );
      expect(transcribeCallCount, 0);
      expect(logMessages.single, contains('audio path was blank'));
    },
  );

  test(
    'draft transcription fails fast for a missing file without uploading',
    () async {
      final result = await service.transcribeAudioDraft(
        '${tempDirectory.path}/missing.m4a',
      );

      expect(
        result,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          TranscriptionFailureReason.apiError,
        ),
      );
      expect(transcribeCallCount, 0);
      expect(logMessages.single, contains('audio file was missing'));
    },
  );

  test(
    'draft transcription fails fast for an empty file without uploading',
    () async {
      final draftPath = '${tempDirectory.path}/empty.m4a';
      await File(draftPath).writeAsBytes(const <int>[]);

      final result = await service.transcribeAudioDraft(draftPath);

      expect(
        result,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          TranscriptionFailureReason.apiError,
        ),
      );
      expect(transcribeCallCount, 0);
      expect(logMessages.single, contains('audio file was empty'));
    },
  );

  test('blank transcript success payload becomes nothingCaught without publishing quota directly', () async {
    final draftPath = '${tempDirectory.path}/draft.m4a';
    await File(draftPath).writeAsBytes(const <int>[1, 2, 3]);
    final quota = RecordQuotaState(
      limit: 5,
      count: 5,
      remaining: 0,
      resetAt: DateTime.utc(2026, 6, 12),
    );
    transcribe = (_) async => backend.TranscriptionSuccess(
      transcript: '   ',
      detectedLanguage: 'en-US',
      quota: quota,
    );

    final result = await service.transcribeAudioDraft(draftPath);

    expect(
      result,
      isA<TranscriptionFailure>()
          .having(
            (value) => value.reason,
            'reason',
            TranscriptionFailureReason.nothingCaught,
          )
          .having((value) => value.quota?.remaining, 'quotaRemaining', 0),
    );
    expect(logMessages.single, contains('non-usable transcript'));
  });

  test('punctuation-only draft transcript success becomes nothingCaught without deleting caller-owned audio', () async {
    final draftPath = '${tempDirectory.path}/draft-punctuation.m4a';
    await File(draftPath).writeAsBytes(const <int>[1, 2, 3]);
    transcribe = (_) async => const backend.TranscriptionSuccess(
      transcript: ' ... ',
      detectedLanguage: 'en-US',
    );

    final result = await service.transcribeAudioDraft(draftPath);

    expect(
      result,
      isA<TranscriptionFailure>().having(
        (value) => value.reason,
        'reason',
        TranscriptionFailureReason.nothingCaught,
      ),
    );
    expect(await File(draftPath).exists(), isTrue);
    expect(logMessages.single, contains('non-usable transcript'));
  });

  test('live transcription failure carries the requested language', () async {
    service = CloudTranscriptionService(
      audioRecordingService: audioRecordingService,
      transcribeAudio: (audioFile, {language}) async {
        return const backend.TranscriptionFailure(
          reason: backend.BackendFailureReason.speechNotRecognized,
        );
      },
      createLiveRecordingPath: () async => livePath,
      readLanguageSnapshot: () async => 'de-CH',
      logWarning: (message, {error, stackTrace}) {
        logMessages.add(message);
      },
    );

    await service.startLiveTranscription(onStatus: (_) {});
    final result = await service.stopLiveTranscription(onStatus: (_) {});

    expect(
      result,
      isA<TranscriptionFailure>()
          .having(
            (value) => value.reason,
            'reason',
            TranscriptionFailureReason.speechNotRecognized,
          )
          .having(
            (value) => value.requestedLanguage,
            'requestedLanguage',
            'de-CH',
          )
          .having((value) => value.audioDraftPath, 'audioDraftPath', livePath),
    );
  });

  test('automatic detection failure carries null requested language', () async {
    transcribe = (_) async => const backend.TranscriptionFailure(
      reason: backend.BackendFailureReason.noInternet,
    );

    await service.startLiveTranscription(onStatus: (_) {});
    final result = await service.stopLiveTranscription(onStatus: (_) {});

    expect(
      result,
      isA<TranscriptionFailure>().having(
        (value) => value.requestedLanguage,
        'requestedLanguage',
        isNull,
      ),
    );
  });

  test(
    'maps backend failure reasons into the narrowed service failure surface',
    () async {
      final cases = <backend.BackendFailureReason, TranscriptionFailureReason>{
        backend.BackendFailureReason.timeout:
            TranscriptionFailureReason.timeout,
        backend.BackendFailureReason.noInternet:
            TranscriptionFailureReason.network,
        backend.BackendFailureReason.backendUnavailable:
            TranscriptionFailureReason.backendUnavailable,
        backend.BackendFailureReason.proxyAuthFailed:
            TranscriptionFailureReason.proxyAuthFailed,
        backend.BackendFailureReason.speechNotRecognized:
            TranscriptionFailureReason.speechNotRecognized,
        backend.BackendFailureReason.requestTooLarge:
            TranscriptionFailureReason.apiError,
        backend.BackendFailureReason.quotaExceeded:
            TranscriptionFailureReason.apiError,
        backend.BackendFailureReason.apiError:
            TranscriptionFailureReason.apiError,
      };

      for (final entry in cases.entries) {
        final draftPath = '${tempDirectory.path}/${entry.key.name}.m4a';
        await File(draftPath).writeAsBytes(const <int>[7, 8, 9]);
        transcribe = (_) async =>
            backend.TranscriptionFailure(reason: entry.key);

        final result = await service.transcribeAudioDraft(draftPath);

        expect(
          result,
          isA<TranscriptionFailure>().having(
            (value) => value.reason,
            '${entry.key.name} -> ${entry.value.name}',
            entry.value,
          ),
        );
        expect(await File(draftPath).exists(), isTrue);
      }
    },
  );
}

class _FakeAudioRecordingService implements AudioRecordingService {
  static const int fakeRecordingDeadlineElapsedRealtime = 120000;

  @override
  bool isRecording = false;

  @override
  int? hardCapDeadlineElapsedRealtime;

  final List<String> startedPaths = <String>[];
  String? _currentPath;
  AudioRecordingFailure? startFailure;
  AudioRecordingFailure? stopFailure;
  Object? cancelFailure;
  int cancelCallCount = 0;

  @override
  Future<void> startRecording(String outputPath) async {
    if (startFailure case final failure?) {
      startFailure = null;
      throw failure;
    }
    startedPaths.add(outputPath);
    _currentPath = outputPath;
    isRecording = true;
    hardCapDeadlineElapsedRealtime = fakeRecordingDeadlineElapsedRealtime;
  }

  @override
  Future<String> stopRecording() async {
    final path = _currentPath;
    if (path == null) {
      throw const NoActiveRecordingFailure();
    }

    if (stopFailure case final failure?) {
      stopFailure = null;
      _currentPath = null;
      isRecording = false;
      hardCapDeadlineElapsedRealtime = null;
      throw failure;
    }

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const <int>[9, 9, 9]);
    _currentPath = null;
    isRecording = false;
    hardCapDeadlineElapsedRealtime = null;
    return path;
  }

  @override
  Future<void> cancelRecording() async {
    if (cancelFailure case final error?) {
      cancelFailure = null;
      throw error;
    }
    final path = _currentPath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    cancelCallCount += 1;
    _currentPath = null;
    isRecording = false;
    hardCapDeadlineElapsedRealtime = null;
  }
}
