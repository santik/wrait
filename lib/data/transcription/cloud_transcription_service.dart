import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import '../../domain/model/supported_language.dart';
import '../audio/audio_recording_service.dart';
import '../api/backend_results.dart' as backend;
import 'transcription_service.dart';

typedef TranscribeAudioCallback = Future<backend.TranscriptionResult> Function(
  File audioFile, {
  String? language,
});
typedef TranscriptionLanguageSnapshot = Future<String?> Function();
typedef TranscriptionActivityCallback = void Function(bool isActive);
typedef LiveRecordingPathFactory = Future<String> Function();
typedef TranscriptionWarningLogger = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

class CloudTranscriptionService implements TranscriptionService {
  CloudTranscriptionService({
    required this.audioRecordingService,
    required this.transcribeAudio,
    required this.createLiveRecordingPath,
    TranscriptionLanguageSnapshot? readLanguageSnapshot,
    this.onActivityChanged,
    TranscriptionWarningLogger? logWarning,
  }) : readLanguageSnapshot =
           readLanguageSnapshot ?? _automaticLanguageSnapshot,
       _logWarning = logWarning ?? _defaultLogWarning;

  final AudioRecordingService audioRecordingService;
  final TranscribeAudioCallback transcribeAudio;
  final LiveRecordingPathFactory createLiveRecordingPath;
  final TranscriptionLanguageSnapshot readLanguageSnapshot;
  final TranscriptionActivityCallback? onActivityChanged;
  final TranscriptionWarningLogger _logWarning;

  _CloudTranscriptionState _state = _CloudTranscriptionState.idle;
  String? _liveLanguage;

  @override
  bool get isRecording => audioRecordingService.isRecording;

  @override
  bool get isTranscribing => _state == _CloudTranscriptionState.transcribing;

  @override
  int? get hardCapDeadlineElapsedRealtime =>
      audioRecordingService.hardCapDeadlineElapsedRealtime;

  @override
  Future<void> startLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    _ensureIdle();
    _state = _CloudTranscriptionState.startingLiveRecording;
    _publishActivity(true);

    try {
      _liveLanguage = await _readLanguage();
      final outputPath = await createLiveRecordingPath();
      await audioRecordingService.startRecording(outputPath);

      final deadline = audioRecordingService.hardCapDeadlineElapsedRealtime;
      if (deadline == null) {
        throw StateError(
          'Recording started without exposing a hard-cap deadline.',
        );
      }

      _state = _CloudTranscriptionState.liveRecording;
      onStatus(RecordingStarted(deadline));
    } on RecordingPermissionDeniedFailure catch (error) {
      _finishOperation();
      throw MicBlockedTranscriptionServiceFailure(error.accessState);
    } catch (_) {
      _finishOperation();
      rethrow;
    }
  }

  @override
  Future<TranscriptionResult> stopLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    if (_state != _CloudTranscriptionState.liveRecording ||
        !audioRecordingService.isRecording) {
      if (_state == _CloudTranscriptionState.liveRecording) {
        // The recorder stopped externally; release the session so activity
        // is not left flagged and a new recording can start.
        _finishOperation();
      }
      throw const NoActiveLiveTranscriptionFailure();
    }

    _state = _CloudTranscriptionState.stoppingLiveRecording;

    late final String audioPath;
    try {
      audioPath = await audioRecordingService.stopRecording();
    } on RecordingTooShortFailure {
      _finishOperation();
      return const TranscriptionFailure(
        reason: TranscriptionFailureReason.tooShort,
      );
    } catch (_) {
      _finishOperation();
      rethrow;
    }

    _state = _CloudTranscriptionState.transcribing;
    try {
      onStatus(const Uploading());
      return await _transcribeCapturedAudio(
        audioPath: audioPath,
        language: _liveLanguage,
        preserveAudioOnFailure: true,
        deleteAudioOnSuccess: true,
      );
    } finally {
      _finishOperation();
    }
  }

  @override
  Future<void> cancelLiveTranscription() async {
    if (_state != _CloudTranscriptionState.liveRecording ||
        !audioRecordingService.isRecording) {
      if (_state == _CloudTranscriptionState.liveRecording) {
        _finishOperation();
      }
      return;
    }

    _state = _CloudTranscriptionState.stoppingLiveRecording;
    try {
      await audioRecordingService.cancelRecording();
      _finishOperation();
    } catch (error, stackTrace) {
      _logWarning(
        'Cloud transcription failed to cancel live recording.',
        error: error,
        stackTrace: stackTrace,
      );
      _state = audioRecordingService.isRecording
          ? _CloudTranscriptionState.liveRecording
          : _CloudTranscriptionState.idle;
      if (_state == _CloudTranscriptionState.idle) {
        _liveLanguage = null;
        _publishActivity(false);
      }
      rethrow;
    }
  }

  @override
  Future<TranscriptionResult> transcribeAudioDraft(String audioPath) async {
    _ensureIdle();
    _state = _CloudTranscriptionState.transcribing;
    _publishActivity(true);
    try {
      final language = await _readLanguage();
      final validatedAudioPath = await _validateDraftAudioPath(audioPath);
      if (validatedAudioPath == null) {
        return const TranscriptionFailure(
          reason: TranscriptionFailureReason.apiError,
        );
      }
      return await _transcribeCapturedAudio(
        audioPath: validatedAudioPath,
        language: language,
        preserveAudioOnFailure: false,
        deleteAudioOnSuccess: false,
      );
    } finally {
      _finishOperation();
    }
  }

  Future<String?> _readLanguage() async {
    try {
      return await readLanguageSnapshot();
    } catch (error, stackTrace) {
      _logWarning(
        'Cloud transcription could not read the saved language preference.',
        error: error,
        stackTrace: stackTrace,
      );
      throw const TranscriptionLanguageUnavailableFailure();
    }
  }

  void _ensureIdle() {
    if (_state != _CloudTranscriptionState.idle ||
        audioRecordingService.isRecording) {
      throw const TranscriptionAlreadyInProgressFailure();
    }
  }

  Future<String?> _validateDraftAudioPath(String audioPath) async {
    final trimmedPath = audioPath.trim();
    if (trimmedPath.isEmpty) {
      _logWarning(
        'Cloud transcription draft upload skipped because the audio path was blank.',
      );
      return null;
    }

    final file = File(trimmedPath);
    try {
      if (!await file.exists()) {
        _logWarning(
          'Cloud transcription draft upload skipped because the audio file was missing: $trimmedPath',
        );
        return null;
      }

      final handle = await file.open(mode: FileMode.read);
      try {
        // Open the file to prove it is readable before upload.
      } finally {
        await handle.close();
      }

      if (await file.length() <= 0) {
        _logWarning(
          'Cloud transcription draft upload skipped because the audio file was empty: $trimmedPath',
        );
        return null;
      }
    } on FileSystemException catch (error, stackTrace) {
      _logWarning(
        'Cloud transcription draft upload skipped because the audio file was unreadable: $trimmedPath',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }

    return trimmedPath;
  }

  Future<TranscriptionResult> _transcribeCapturedAudio({
    required String audioPath,
    required String? language,
    required bool preserveAudioOnFailure,
    required bool deleteAudioOnSuccess,
  }) async {
    try {
      final backendResult = await transcribeAudio(
        File(audioPath),
        language: language,
      );
      return await switch (backendResult) {
        backend.TranscriptionSuccess() => _handleSuccessResult(
          backendResult,
          audioPath: audioPath,
          deleteAudioOnSuccess: deleteAudioOnSuccess,
        ),
        backend.TranscriptionFailure() => _handleFailureResult(
          backendResult,
          audioPath: audioPath,
          language: language,
          preserveAudioOnFailure: preserveAudioOnFailure,
        ),
      };
    } catch (error, stackTrace) {
      _logWarning(
        'Cloud transcription crashed while uploading audio.',
        error: error,
        stackTrace: stackTrace,
      );
      return TranscriptionFailure(
        reason: TranscriptionFailureReason.apiError,
        audioDraftPath: preserveAudioOnFailure ? audioPath : null,
      );
    }
  }

  Future<TranscriptionResult> _handleSuccessResult(
    backend.TranscriptionSuccess result, {
    required String audioPath,
    required bool deleteAudioOnSuccess,
  }) async {
    final transcript = result.transcript.trim();
    if (!hasUsableTranscriptContent(transcript)) {
      if (deleteAudioOnSuccess) {
        await _deleteFileIfPresent(audioPath);
      }
      _logWarning(
        'Cloud transcription returned a non-usable transcript in a success payload.',
      );
      return TranscriptionFailure(
        reason: TranscriptionFailureReason.nothingCaught,
        quota: result.quota,
      );
    }

    final normalizedLanguage = resolveSupportedLanguageCode(
      result.detectedLanguage,
    );

    if (deleteAudioOnSuccess) {
      await _deleteFileIfPresent(audioPath);
    }

    return TranscriptionSuccess(
      transcript: transcript,
      detectedLanguage: normalizedLanguage,
      quota: result.quota,
    );
  }

  TranscriptionResult _handleFailureResult(
    backend.TranscriptionFailure result, {
    required String audioPath,
    required String? language,
    required bool preserveAudioOnFailure,
  }) {
    _logWarning('Cloud transcription failed with ${result.reason.name}.');

    return TranscriptionFailure(
      reason: _mapFailureReason(result.reason),
      audioDraftPath: preserveAudioOnFailure ? audioPath : null,
      requestedLanguage: language,
      quota: result.quota,
    );
  }

  TranscriptionFailureReason _mapFailureReason(
    backend.BackendFailureReason reason,
  ) {
    return switch (reason) {
      backend.BackendFailureReason.timeout =>
        TranscriptionFailureReason.timeout,
      backend.BackendFailureReason.noInternet =>
        TranscriptionFailureReason.network,
      backend.BackendFailureReason.backendUnavailable =>
        TranscriptionFailureReason.backendUnavailable,
      backend.BackendFailureReason.proxyAuthFailed ||
      backend.BackendFailureReason.credentialRejected =>
        TranscriptionFailureReason.proxyAuthFailed,
      backend.BackendFailureReason.rateLimited =>
        TranscriptionFailureReason.rateLimited,
      backend.BackendFailureReason.speechNotRecognized =>
        TranscriptionFailureReason.speechNotRecognized,
      backend.BackendFailureReason.requestTooLarge ||
      backend.BackendFailureReason.quotaExceeded ||
      backend.BackendFailureReason.apiError =>
        TranscriptionFailureReason.apiError,
    };
  }

  Future<void> _deleteFileIfPresent(String audioPath) async {
    try {
      final file = File(audioPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      _logWarning(
        'Failed to delete live transcription audio after success.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _finishOperation() {
    _state = _CloudTranscriptionState.idle;
    _liveLanguage = null;
    _publishActivity(false);
  }

  void _publishActivity(bool isActive) {
    onActivityChanged?.call(isActive);
  }

  static void _defaultLogWarning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: 'CloudTranscriptionService',
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Future<String?> _automaticLanguageSnapshot() async => null;
}

enum _CloudTranscriptionState {
  idle,
  startingLiveRecording,
  liveRecording,
  stoppingLiveRecording,
  transcribing,
}
