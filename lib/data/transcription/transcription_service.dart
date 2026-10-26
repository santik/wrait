import '../audio/microphone_permission_service.dart';
import '../api/record_quota_state.dart';

typedef TranscriptionStatusCallback = void Function(TranscriptionStatus status);

/// App-facing contract for the sequential best-mode cloud transcription flow.
abstract interface class TranscriptionService {
  /// Whether a live recording session is currently active in the recorder.
  bool get isRecording;

  /// Whether the service is currently uploading audio for transcription.
  bool get isTranscribing;

  /// The active recording deadline for the current live session, if any.
  int? get hardCapDeadlineElapsedRealtime;

  /// Starts a new live recording session and emits [RecordingStarted].
  Future<void> startLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  });

  /// Stops the active live recording, emits [Uploading], and uploads the audio.
  Future<TranscriptionResult> stopLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  });

  /// Cancels the active live recording without uploading audio.
  Future<void> cancelLiveTranscription();

  /// Uploads an already-retained draft audio file without starting recording.
  Future<TranscriptionResult> transcribeAudioDraft(String audioPath);
}

/// Statuses emitted while the live transcription flow progresses.
sealed class TranscriptionStatus {
  const TranscriptionStatus();
}

/// Emitted after a live recording starts successfully.
final class RecordingStarted extends TranscriptionStatus {
  const RecordingStarted(this.hardCapDeadlineElapsedRealtime);

  final int hardCapDeadlineElapsedRealtime;
}

/// Emitted after recording stops and before the backend upload begins.
final class Uploading extends TranscriptionStatus {
  const Uploading();
}

/// Narrowed failure reasons exposed by the cloud transcription flow.
enum TranscriptionFailureReason {
  tooShort,
  nothingCaught,
  micBlocked,
  network,
  timeout,
  backendUnavailable,
  proxyAuthFailed,
  rateLimited,
  speechNotRecognized,
  apiError,
}

/// Result of a cloud transcription attempt.
sealed class TranscriptionResult {
  const TranscriptionResult();
}

/// Successful transcription result with backend-supplied transcript text.
final class TranscriptionSuccess extends TranscriptionResult {
  const TranscriptionSuccess({
    required this.transcript,
    required this.detectedLanguage,
    this.quota,
  });

  final String transcript;
  final String? detectedLanguage;
  final RecordQuotaState? quota;
}

/// Whether a transcript contains at least one usable spoken-content character.
///
/// This intentionally treats whitespace-only and punctuation-only payloads as
/// "nothing caught" so they do not become retryable drafts or cleanup input.
bool hasUsableTranscriptContent(String transcript) {
  return _usableTranscriptCharacterPattern.hasMatch(transcript.trim());
}

final _usableTranscriptCharacterPattern = RegExp(
  r'[\p{L}\p{N}]',
  unicode: true,
);

/// Failed transcription result mapped to the app-facing failure surface.
final class TranscriptionFailure extends TranscriptionResult {
  const TranscriptionFailure({
    required this.reason,
    this.audioDraftPath,
    this.requestedLanguage,
    this.quota,
  });

  final TranscriptionFailureReason reason;
  final String? audioDraftPath;
  final String? requestedLanguage;
  final RecordQuotaState? quota;
}

/// Misuse failures thrown before a transcription attempt can start or continue.
sealed class TranscriptionServiceFailure implements Exception {
  const TranscriptionServiceFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final class TranscriptionAlreadyInProgressFailure
    extends TranscriptionServiceFailure {
  const TranscriptionAlreadyInProgressFailure()
    : super('A cloud transcription operation is already in progress.');
}

final class NoActiveLiveTranscriptionFailure
    extends TranscriptionServiceFailure {
  const NoActiveLiveTranscriptionFailure()
    : super('No live cloud transcription recording is active.');
}

final class TranscriptionLanguageUnavailableFailure
    extends TranscriptionServiceFailure {
  const TranscriptionLanguageUnavailableFailure()
    : super('The saved transcription language could not be loaded.');
}

final class MicBlockedTranscriptionServiceFailure
    extends TranscriptionServiceFailure {
  const MicBlockedTranscriptionServiceFailure(this.accessState)
    : super('The microphone is unavailable for recording.');

  final MicrophoneAccessState accessState;
}
