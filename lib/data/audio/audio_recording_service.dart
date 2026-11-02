import 'microphone_permission_service.dart';

const minimumRecordingDuration = Duration(seconds: 5);

abstract interface class AudioRecordingService {
  bool get isRecording;
  int? get hardCapDeadlineElapsedRealtime;

  Future<void> startRecording(String outputPath);
  Future<String> stopRecording();
  Future<void> cancelRecording();
}

sealed class AudioRecordingFailure implements Exception {
  const AudioRecordingFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final class RecordingAlreadyInProgressFailure extends AudioRecordingFailure {
  const RecordingAlreadyInProgressFailure()
    : super('A recording session is already active.');
}

final class NoActiveRecordingFailure extends AudioRecordingFailure {
  const NoActiveRecordingFailure() : super('No recording session is active.');
}

final class RecordingTooShortFailure extends AudioRecordingFailure {
  const RecordingTooShortFailure()
    : super('Recording shorter than 5 seconds is invalid.');
}

final class RecordingOutputUnavailableFailure extends AudioRecordingFailure {
  const RecordingOutputUnavailableFailure()
    : super('Recorder stopped without producing a usable output file.');
}

final class RecordingPermissionDeniedFailure extends AudioRecordingFailure {
  const RecordingPermissionDeniedFailure(this.accessState)
    : super('Microphone permission was denied for recording.');

  final MicrophoneAccessState accessState;
}
