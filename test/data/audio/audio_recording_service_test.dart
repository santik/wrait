import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:wrait/data/audio/audio_recording_service.dart';
import 'package:wrait/data/audio/microphone_permission_service.dart';
import 'package:wrait/data/audio/record_audio_recording_service.dart';

import '../../test_doubles/fake_monotonic_clock.dart';

void main() {
  late Directory tempDirectory;
  late FakeMonotonicClock monotonicClock;
  late _FakeRecorderAdapter recorder;
  late _FakeMicrophonePermissionService microphonePermissionService;
  late RecordAudioRecordingService service;

  String pathFor(String fileName) => '${tempDirectory.path}/$fileName';

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('wrait-audio-test');
    monotonicClock = FakeMonotonicClock(5000);
    recorder = _FakeRecorderAdapter();
    microphonePermissionService = _FakeMicrophonePermissionService();
    service = RecordAudioRecordingService(
      recorder: recorder,
      microphonePermissionService: microphonePermissionService,
      monotonicClock: monotonicClock,
      hardCap: const Duration(seconds: 120),
    );
  });

  tearDown(() async {
    await service.dispose();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('rejects blank output paths before touching the recorder', () async {
    await expectLater(
      service.startRecording('   '),
      throwsA(isA<ArgumentError>()),
    );

    expect(recorder.startCalls, isEmpty);
    expect(service.isRecording, isFalse);
  });

  test(
    'serializes concurrent start requests and rejects the second request',
    () async {
      recorder.startCompleter = Completer<void>();
      recorder.startEnteredCompleter = Completer<void>();
      final firstPath = pathFor('first.m4a');
      final secondPath = pathFor('second.m4a');

      final firstStart = service.startRecording(firstPath);
      final secondStart = service.startRecording(secondPath);

      await recorder.startEnteredCompleter!.future;

      expect(recorder.startCalls, hasLength(1));
      expect(recorder.startCalls.single.path, firstPath);
      expect(service.isRecording, isFalse);

      recorder.startCompleter!.complete();
      await firstStart;

      await expectLater(
        secondStart,
        throwsA(isA<RecordingAlreadyInProgressFailure>()),
      );

      expect(service.isRecording, isTrue);
      expect(recorder.startCalls, hasLength(1));
    },
  );

  test('requests mono 16 kHz AAC-in-M4A capture from the recorder', () async {
    final path = pathFor('config-check.m4a');

    await service.startRecording(path);

    final config = recorder.startCalls.single.config;
    expect(config.encoder, AudioEncoder.aacLc);
    expect(config.sampleRate, 16000);
    expect(config.numChannels, 1);
  });

  test('fails cleanly when microphone permission is denied', () async {
    microphonePermissionService.nextState = MicrophoneAccessState.denied;

    await expectLater(
      service.startRecording(pathFor('permission-denied.m4a')),
      throwsA(
        isA<RecordingPermissionDeniedFailure>().having(
          (error) => error.accessState,
          'accessState',
          MicrophoneAccessState.denied,
        ),
      ),
    );

    expect(microphonePermissionService.requestCallCount, 1);
    expect(recorder.startCalls, isEmpty);
    expect(service.isRecording, isFalse);
  });

  test(
    'preserves permanently denied microphone state in the failure',
    () async {
      microphonePermissionService.nextState =
          MicrophoneAccessState.permanentlyDenied;

      await expectLater(
        service.startRecording(pathFor('permission-permanently-denied.m4a')),
        throwsA(
          isA<RecordingPermissionDeniedFailure>().having(
            (error) => error.accessState,
            'accessState',
            MicrophoneAccessState.permanentlyDenied,
          ),
        ),
      );

      expect(recorder.startCalls, isEmpty);
    },
  );

  test('returns the completed output path for a valid recording', () async {
    final path = pathFor('valid-recording.m4a');
    await service.startRecording(path);

    final expectedDeadline =
        monotonicClock.currentTimeMs +
        const Duration(seconds: 120).inMilliseconds;
    expect(service.hardCapDeadlineElapsedRealtime, expectedDeadline);

    monotonicClock.advance(const Duration(seconds: 6));
    final returnedPath = await service.stopRecording();

    expect(returnedPath, path);
    expect(service.isRecording, isFalse);
    expect(service.hardCapDeadlineElapsedRealtime, isNull);
    expect(await File(path).exists(), isTrue);
  });

  test('deletes too-short recordings and throws a typed failure', () async {
    final path = pathFor('too-short.m4a');
    await service.startRecording(path);

    monotonicClock.advance(const Duration(seconds: 4));

    await expectLater(
      service.stopRecording(),
      throwsA(isA<RecordingTooShortFailure>()),
    );

    expect(service.isRecording, isFalse);
    expect(service.hardCapDeadlineElapsedRealtime, isNull);
    expect(await File(path).exists(), isFalse);
  });

  test('fails stopping when no recording session is active', () async {
    await expectLater(
      service.stopRecording(),
      throwsA(isA<NoActiveRecordingFailure>()),
    );
  });

  test('derives the hard-cap deadline from the configured duration', () async {
    final shortCapService = RecordAudioRecordingService(
      recorder: recorder,
      microphonePermissionService: microphonePermissionService,
      monotonicClock: monotonicClock,
      hardCap: const Duration(seconds: 15),
    );
    addTearDown(shortCapService.dispose);

    await shortCapService.startRecording(pathFor('deadline.m4a'));

    expect(shortCapService.hardCapDeadlineElapsedRealtime, 20000);
  });

  test(
    'dispose cancels an active recording and deletes the partial file',
    () async {
      final path = pathFor('dispose-active.m4a');
      recorder.writeFileOnStart = true;

      await service.startRecording(path);
      await service.dispose();

      expect(recorder.cancelCallCount, 1);
      expect(await File(path).exists(), isFalse);
      expect(service.isRecording, isFalse);
    },
  );

  test(
    'cancelRecording clears the active session and deletes partial audio',
    () async {
      final path = pathFor('cancel-active.m4a');
      recorder.writeFileOnStart = true;

      await service.startRecording(path);
      await service.cancelRecording();

      expect(recorder.cancelCallCount, 1);
      expect(service.isRecording, isFalse);
      expect(service.hardCapDeadlineElapsedRealtime, isNull);
      expect(await File(path).exists(), isFalse);
    },
  );

  test('start failure cancels cleanup and keeps service inactive', () async {
    final path = pathFor('start-failure.m4a');
    recorder.startError = StateError('boom');

    await expectLater(service.startRecording(path), throwsA(isA<StateError>()));

    expect(recorder.cancelCallCount, 1);
    expect(service.isRecording, isFalse);
  });

  test('stop fails when recorder produces no usable output file', () async {
    final path = pathFor('missing-output.m4a');
    recorder.returnNullPathOnStop = true;
    recorder.skipWritingOnStop = true;

    await service.startRecording(path);
    monotonicClock.advance(const Duration(seconds: 6));

    await expectLater(
      service.stopRecording(),
      throwsA(isA<RecordingOutputUnavailableFailure>()),
    );

    expect(service.isRecording, isFalse);
  });

  test('fails fast when output parent path is not a directory', () async {
    final blockingFile = File(pathFor('not-a-directory'));
    await blockingFile.writeAsString('block');

    await expectLater(
      service.startRecording('${blockingFile.path}/child.m4a'),
      throwsA(isA<FileSystemException>()),
    );

    expect(recorder.startCalls, isEmpty);
    expect(service.isRecording, isFalse);
  });
}

class _FakeRecorderAdapter implements RecorderAdapter {
  final List<_StartCall> startCalls = <_StartCall>[];
  Completer<void>? startCompleter;
  Completer<void>? startEnteredCompleter;
  String? _lastPath;
  bool writeFileOnStart = false;
  bool skipWritingOnStop = false;
  bool returnNullPathOnStop = false;
  Object? startError;
  int cancelCallCount = 0;

  @override
  Future<void> start({
    required RecordConfig config,
    required String path,
  }) async {
    if (startError != null) {
      throw startError!;
    }

    startCalls.add(_StartCall(config: config, path: path));
    _lastPath = path;
    startEnteredCompleter?.complete();
    if (writeFileOnStart) {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(const <int>[9, 9, 9]);
    }
    if (startCompleter != null) {
      await startCompleter!.future;
    }
  }

  @override
  Future<String?> stop() async {
    final path = _lastPath;
    if (path == null) {
      return null;
    }

    if (!skipWritingOnStop) {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(const <int>[1, 2, 3, 4]);
    }
    _lastPath = null;
    if (returnNullPathOnStop) {
      return null;
    }
    return path;
  }

  @override
  Future<void> cancel() async {
    cancelCallCount += 1;
    _lastPath = null;
  }

  @override
  Future<void> dispose() async {}
}

class _FakeMicrophonePermissionService implements MicrophonePermissionService {
  MicrophoneAccessState nextState = MicrophoneAccessState.granted;
  int getCallCount = 0;
  int requestCallCount = 0;
  int openSettingsCallCount = 0;

  @override
  Future<MicrophoneAccessState> getMicrophoneAccess() async {
    getCallCount += 1;
    return nextState;
  }

  @override
  Future<bool> openMicrophonePermissionSettings() async {
    openSettingsCallCount += 1;
    return true;
  }

  @override
  Future<MicrophoneAccessState> requestMicrophoneAccess() async {
    requestCallCount += 1;
    return nextState;
  }
}

class _StartCall {
  const _StartCall({required this.config, required this.path});

  final RecordConfig config;
  final String path;
}
