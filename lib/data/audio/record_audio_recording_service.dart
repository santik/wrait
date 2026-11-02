import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:record/record.dart';

import '../../core/time/monotonic_clock.dart';
import 'audio_recording_service.dart';
import 'microphone_permission_service.dart';

abstract interface class RecorderAdapter {
  Future<void> start({required RecordConfig config, required String path});
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class AudioRecorderAdapter implements RecorderAdapter {
  AudioRecorderAdapter({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<void> start({required RecordConfig config, required String path}) {
    return _recorder.start(config, path: path);
  }

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}

class RecordAudioRecordingService implements AudioRecordingService {
  RecordAudioRecordingService({
    required this.recorder,
    required this.microphonePermissionService,
    required this.monotonicClock,
    required this.hardCap,
  }) {
    if (hardCap <= Duration.zero) {
      throw ArgumentError.value(
        hardCap,
        'hardCap',
        'must be a positive duration',
      );
    }
  }

  final RecorderAdapter recorder;
  final MicrophonePermissionService microphonePermissionService;
  final MonotonicClock monotonicClock;
  final Duration hardCap;

  Completer<void>? _operationCompleter;
  _ActiveRecordingSession? _activeSession;

  static const RecordConfig _recordConfig = RecordConfig(
    encoder: AudioEncoder.aacLc,
    sampleRate: 16000,
    numChannels: 1,
  );

  @override
  bool get isRecording => _activeSession != null;

  @override
  int? get hardCapDeadlineElapsedRealtime =>
      _activeSession?.hardCapDeadlineElapsedRealtime;

  @override
  Future<void> startRecording(String outputPath) {
    return _runExclusive(() async {
      final trimmedPath = outputPath.trim();
      if (trimmedPath.isEmpty) {
        throw ArgumentError.value(
          outputPath,
          'outputPath',
          'must not be blank',
        );
      }
      if (_activeSession != null) {
        throw const RecordingAlreadyInProgressFailure();
      }
      final microphoneAccessState = await microphonePermissionService
          .requestMicrophoneAccess();
      if (microphoneAccessState != MicrophoneAccessState.granted) {
        throw RecordingPermissionDeniedFailure(microphoneAccessState);
      }

      final preparedPath = await _prepareOutputPath(trimmedPath);
      final startedAtElapsedRealtime = monotonicClock.now();
      try {
        await recorder.start(config: _recordConfig, path: preparedPath);
      } catch (error, stackTrace) {
        _logCleanupFailure(
          'Audio recorder failed to start.',
          error,
          stackTrace,
        );
        await _cancelRecorderBestEffort();
        await _deleteFileIfPresent(preparedPath);
        rethrow;
      }

      _activeSession = _ActiveRecordingSession(
        outputPath: preparedPath,
        startedAtElapsedRealtime: startedAtElapsedRealtime,
        hardCapDeadlineElapsedRealtime:
            startedAtElapsedRealtime + hardCap.inMilliseconds,
      );
    });
  }

  @override
  Future<String> stopRecording() {
    return _runExclusive(() async {
      final session = _activeSession;
      if (session == null) {
        throw const NoActiveRecordingFailure();
      }

      final stoppedPath = await _stopRecorderOrCleanup(session);
      final resolvedPath = (stoppedPath ?? session.outputPath).trim();
      final elapsedRecordingDuration =
          monotonicClock.now() - session.startedAtElapsedRealtime;

      _activeSession = null;

      if (elapsedRecordingDuration < minimumRecordingDuration.inMilliseconds) {
        await _deleteFileIfPresent(resolvedPath);
        throw const RecordingTooShortFailure();
      }

      if (resolvedPath.isEmpty) {
        throw const RecordingOutputUnavailableFailure();
      }

      await _ensureOutputFileIsUsable(resolvedPath);
      return resolvedPath;
    });
  }

  @override
  Future<void> cancelRecording() {
    return _runExclusive(() async {
      final session = _activeSession;
      _activeSession = null;
      if (session == null) {
        return;
      }

      await _cancelRecorderBestEffort();
      await _deleteFileIfPresent(session.outputPath);
    });
  }

  Future<void> dispose() async {
    await _runExclusive(() async {
      final session = _activeSession;
      _activeSession = null;

      if (session != null) {
        await _cancelRecorderBestEffort();
        await _deleteFileIfPresent(session.outputPath);
      }

      await recorder.dispose();
    });
  }

  Future<T> _runExclusive<T>(Future<T> Function() action) async {
    while (_operationCompleter != null) {
      await _operationCompleter!.future;
    }

    final completer = Completer<void>();
    _operationCompleter = completer;

    try {
      return await action();
    } finally {
      _operationCompleter = null;
      completer.complete();
    }
  }

  Future<void> _deleteFileIfPresent(String path) async {
    if (path.isEmpty) {
      return;
    }

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      _logCleanupFailure(
        'Failed to delete temporary recording file.',
        error,
        stackTrace,
      );
    }
  }

  Future<String> _prepareOutputPath(String outputPath) async {
    final file = File(outputPath);
    final parent = file.parent;

    if (await parent.exists()) {
      final parentType = await FileSystemEntity.type(parent.path);
      if (parentType != FileSystemEntityType.directory) {
        throw FileSystemException(
          'Output path parent must be a directory.',
          parent.path,
        );
      }
    } else {
      await parent.create(recursive: true);
    }

    final probeFile = File(
      '${parent.path}/.wrait-write-check-${DateTime.now().microsecondsSinceEpoch}',
    );

    try {
      await probeFile.writeAsBytes(const <int>[]);
    } finally {
      if (await probeFile.exists()) {
        await probeFile.delete();
      }
    }

    return outputPath;
  }

  Future<String?> _stopRecorderOrCleanup(
    _ActiveRecordingSession session,
  ) async {
    try {
      return await recorder.stop();
    } catch (error, stackTrace) {
      _activeSession = null;
      _logCleanupFailure(
        'Audio recorder failed to stop cleanly.',
        error,
        stackTrace,
      );
      await _cancelRecorderBestEffort();
      await _deleteFileIfPresent(session.outputPath);
      rethrow;
    }
  }

  Future<void> _ensureOutputFileIsUsable(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const RecordingOutputUnavailableFailure();
    }
    if (await file.length() <= 0) {
      await _deleteFileIfPresent(path);
      throw const RecordingOutputUnavailableFailure();
    }
  }

  Future<void> _cancelRecorderBestEffort() async {
    try {
      await recorder.cancel();
    } catch (error, stackTrace) {
      _logCleanupFailure(
        'Failed to cancel recorder during cleanup.',
        error,
        stackTrace,
      );
    }
  }

  void _logCleanupFailure(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'AudioRecordingService',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

class _ActiveRecordingSession {
  const _ActiveRecordingSession({
    required this.outputPath,
    required this.startedAtElapsedRealtime,
    required this.hardCapDeadlineElapsedRealtime,
  });

  final String outputPath;
  final int startedAtElapsedRealtime;
  final int hardCapDeadlineElapsedRealtime;
}
