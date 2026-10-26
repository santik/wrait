import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/monotonic_clock.dart';
import '../../data/api/backend_providers.dart';
import '../../data/api/backend_results.dart' as backend;
import '../../data/api/record_quota_state.dart';
import '../../data/audio/audio_recording_providers.dart';
import '../../data/audio/audio_recording_service.dart';
import '../../data/audio/microphone_permission_service.dart';
import '../../data/entries/entry_providers.dart';
import '../../data/entries/tag_providers.dart';
import '../../data/preferences/preferences_providers.dart';
import '../../data/reminders/reminder_providers.dart';
import '../../data/transcription/transcription_providers.dart';
import '../../data/transcription/transcription_service.dart';
import '../../domain/repository/entry_repository.dart';
import '../../domain/model/tag.dart';
import '../../domain/repository/preferences_repository.dart';
import '../../domain/usecase/cleanup_transcript_use_case.dart';
import 'recording_state.dart';

typedef RecordingControllerWarningLogger = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

class RecordingFeedbackDelays {
  const RecordingFeedbackDelays({
    this.errorAndDeletedAutoClear = const Duration(seconds: 3),
    this.savedDisplayWindow = const Duration(seconds: 4),
  });

  final Duration errorAndDeletedAutoClear;
  final Duration savedDisplayWindow;
}

final recordingControllerWarningLoggerProvider =
    Provider<RecordingControllerWarningLogger>((ref) {
      return (message, {error, stackTrace}) {
        developer.log(
          message,
          name: 'MainRecordingController',
          error: error,
          stackTrace: stackTrace,
        );
      };
    });

final recordingFeedbackDelaysProvider = Provider<RecordingFeedbackDelays>(
  (ref) => const RecordingFeedbackDelays(),
);

final recordingResumePermissionTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

final mainRecordingControllerProvider =
    NotifierProvider<MainRecordingController, RecordingControllerState>(
      MainRecordingController.new,
    );

class MainRecordingController extends Notifier<RecordingControllerState> {
  TranscriptionService get _transcriptionService =>
      ref.read(transcriptionServiceProvider);
  CleanupTranscriptUseCase get _cleanupTranscriptUseCase =>
      ref.read(cleanupTranscriptUseCaseProvider);
  EntryRepository get _entryRepository => ref.read(entryRepositoryProvider);
  PreferencesRepository get _preferencesRepository =>
      ref.read(preferencesRepositoryProvider);
  MicrophonePermissionService get _microphonePermissionService =>
      ref.read(microphonePermissionServiceProvider);
  MonotonicClock get _monotonicClock => ref.read(monotonicClockProvider);
  RecordingControllerWarningLogger get _logWarning =>
      ref.read(recordingControllerWarningLoggerProvider);
  SessionRecordQuotaStateNotifier get _sessionQuotaNotifier =>
      ref.read(sessionRecordQuotaStateProvider.notifier);
  RecordingFeedbackDelays get _feedbackDelays =>
      ref.read(recordingFeedbackDelaysProvider);
  Duration get _resumePermissionTimeout =>
      ref.read(recordingResumePermissionTimeoutProvider);

  Timer? _autoClearTimer;
  Timer? _hardCapStopTimer;
  int? _listeningStartedAtElapsedRealtime;
  bool _buttonActionInFlight = false;
  Future<void>? _resumePermissionCheckInFlight;

  @override
  RecordingControllerState build() {
    ref.onDispose(() {
      _cancelAutoClearTimer();
      _cancelHardCapStopTimer();
    });
    return const RecordingControllerState();
  }

  Future<void> onMainButtonTapped() async {
    if (_buttonActionInFlight) {
      return;
    }

    final current = state.recordingState;
    switch (current) {
      case RecordingIdle():
        await _startListening();
        return;
      case RecordingListening():
        await _stopListening();
        return;
      case RecordingUploading() || RecordingProcessing():
        return;
      case RecordingSaved():
        await _startListening();
        return;
      case RecordingDeleted():
        await _startListening();
        return;
      case RecordingErrorState():
        if (current.error == RecordingError.microphoneBlocked) {
          await openMicrophoneSettings();
          return;
        }
        await _startListening();
        return;
    }
  }

  void clearSaved() {
    if (state.recordingState is! RecordingSaved) {
      return;
    }
    resetToIdle();
  }

  void resetToIdle() {
    _cancelAutoClearTimer();
    _cancelHardCapStopTimer();
    _listeningStartedAtElapsedRealtime = null;
    state = state.copyWith(recordingState: const RecordingIdle());
  }

  void onEntriesDeleted(int count) {
    if (count <= 0) {
      return;
    }

    _cancelAutoClearTimer();
    _cancelHardCapStopTimer();
    _listeningStartedAtElapsedRealtime = null;
    final deletedState = RecordingDeleted(count);
    state = state.copyWith(recordingState: deletedState);
    _scheduleAutoClear(deletedState);
  }

  Future<void> onAppResumed() async {
    final current = state.recordingState;
    if (current is! RecordingListening && current is! RecordingErrorState) {
      return;
    }

    final inFlight = _resumePermissionCheckInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _runResumePermissionCheck();
    _resumePermissionCheckInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_resumePermissionCheckInFlight, future)) {
        _resumePermissionCheckInFlight = null;
      }
    }
  }

  Future<void> _runResumePermissionCheck() async {
    final current = state.recordingState;
    if (current is! RecordingListening && current is! RecordingErrorState) {
      return;
    }

    final accessState = await _readMicrophoneAccessForResume();
    if (accessState == null) {
      return;
    }

    final latest = state.recordingState;
    if (accessState == MicrophoneAccessState.granted) {
      if (latest is RecordingErrorState &&
          latest.error == RecordingError.microphoneBlocked) {
        resetToIdle();
      }
      return;
    }

    if (latest is RecordingListening) {
      await _cancelListeningForPermissionLoss(accessState);
    }
  }

  Future<MicrophoneAccessState?> _readMicrophoneAccessForResume() async {
    try {
      return await _microphonePermissionService.getMicrophoneAccess().timeout(
        _resumePermissionTimeout,
      );
    } on TimeoutException catch (error, stackTrace) {
      _logWarning(
        'Timed out checking microphone permission after app resume.',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } catch (error, stackTrace) {
      _logWarning(
        'Failed to check microphone permission after app resume.',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> openMicrophoneSettings() async {
    if (_buttonActionInFlight) {
      return;
    }

    _buttonActionInFlight = true;
    try {
      final opened = await _microphonePermissionService
          .openMicrophonePermissionSettings();
      if (!opened) {
        _logWarning('Failed to open microphone permission settings.');
      }
    } catch (error, stackTrace) {
      _logWarning(
        'Failed to open microphone permission settings.',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _buttonActionInFlight = false;
    }
  }

  Future<void> _startListening() async {
    _buttonActionInFlight = true;
    _cancelAutoClearTimer();
    _cancelHardCapStopTimer();
    _listeningStartedAtElapsedRealtime = null;

    try {
      await _transcriptionService.startLiveTranscription(
        onStatus: _handleTranscriptionStatus,
      );
      final latest = state.recordingState;
      if (latest is RecordingListening) {
        _scheduleHardCapStop(latest);
      }
    } on TranscriptionServiceFailure catch (error, stackTrace) {
      _handleStartFailure(error, stackTrace);
    } catch (error, stackTrace) {
      _emitError(
        RecordingError.apiFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      _buttonActionInFlight = false;
    }
  }

  Future<void> _stopListening() async {
    _buttonActionInFlight = true;
    _cancelHardCapStopTimer();
    final isTooShortTap =
        _listeningStartedAtElapsedRealtime != null &&
        _monotonicClock.now() - _listeningStartedAtElapsedRealtime! <
            minimumRecordingDuration.inMilliseconds;

    try {
      final result = await _transcriptionService.stopLiveTranscription(
        onStatus: _handleTranscriptionStatus,
      );
      if (isTooShortTap && result is TranscriptionSuccess) {
        _logWarning(
          'Stop requested before the minimum duration, but transcription unexpectedly succeeded.',
        );
      }
      await _handleTranscriptionResult(result);
    } on TranscriptionServiceFailure catch (error, stackTrace) {
      _emitError(
        RecordingError.apiFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      _emitError(
        RecordingError.apiFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      _buttonActionInFlight = false;
    }
  }

  void _handleTranscriptionStatus(TranscriptionStatus status) {
    switch (status) {
      case RecordingStarted():
        _listeningStartedAtElapsedRealtime = _monotonicClock.now();
        state = state.copyWith(
          recordingState: RecordingListening(
            hardCapDeadlineElapsedRealtime:
                status.hardCapDeadlineElapsedRealtime,
          ),
        );
        return;
      case Uploading():
        _cancelHardCapStopTimer();
        state = state.copyWith(recordingState: const RecordingUploading());
        return;
    }
  }

  void _handleStartFailure(
    TranscriptionServiceFailure error,
    StackTrace stackTrace,
  ) {
    _emitError(
      switch (error) {
        MicBlockedTranscriptionServiceFailure() => _mapMicrophoneAccessState(
          error.accessState,
        ),
        _ => RecordingError.apiFailed,
      },
      cause: error,
      stackTrace: stackTrace,
    );
  }

  Future<void> _handleTranscriptionResult(TranscriptionResult result) async {
    _listeningStartedAtElapsedRealtime = null;

    switch (result) {
      case TranscriptionSuccess():
        if (!hasUsableTranscriptContent(result.transcript)) {
          _publishQuota(result.quota);
          // Defend against punctuation-only or other non-usable success
          // payloads so they never enter cleanup or draft persistence.
          _emitError(RecordingError.noMatch);
          return;
        }
        state = state.copyWith(recordingState: const RecordingProcessing());
        await _handleCleanup(result);
        return;
      case TranscriptionFailure():
        _publishQuota(result.quota);
        // Ignore any audio draft path on no-match failures so a service
        // mistake cannot turn terminal no-word feedback into a retryable draft.
        final audioDraftPath =
            result.reason == TranscriptionFailureReason.nothingCaught
            ? null
            : result.audioDraftPath;
        final preservedDraft = await _persistAudioDraftIfNeeded(
          audioDraftPath,
          language: result.requestedLanguage,
        );
        _emitError(
          _mapTranscriptionFailure(result.reason),
          preservedDraft: preservedDraft,
        );
        return;
    }
  }

  Future<void> _handleCleanup(TranscriptionSuccess result) async {
    // Start auto-tag detection in parallel with cleanup. It must never block
    // or affect the cleanup/save flow, so any failure here is swallowed.
    var tags = const <Tag>[];
    Future<backend.TagTextResult>? tagFuture;
    final isDebugDevice = ref.read(isDebugDeviceProvider);
    if (isDebugDevice) {
      try {
        tags = await ref.read(tagRepositoryProvider).getAllTags();
        if (tags.length >= 2 && result.transcript.trim().isNotEmpty) {
          tagFuture = ref.read(tagTextCallbackProvider)(
            text: result.transcript,
            tags: tags.map((t) => t.name).toList(),
          );
        }
      } catch (error, stackTrace) {
        tagFuture = null;
        _logWarning(
          'Failed to start auto-tag detection.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final cleanupResult = await _cleanupTranscriptUseCase(
      rawTranscript: result.transcript,
      language: result.detectedLanguage,
      fallbackQuota: result.quota,
    );

    switch (cleanupResult) {
      case CleanupTranscriptSuccess():
        final entryId = cleanupResult.entryId;
        if (entryId == null || entryId <= 0) {
          _logWarning(
            'Cleanup succeeded without a valid entry id; Saved state was not published.',
            error: ArgumentError.value(entryId, 'entryId', 'must be positive'),
          );
          _emitError(RecordingError.apiFailed);
          return;
        }
        await _markHasEverRecorded();
        notifyEntryCreatedFromRef(ref);
        state = state.copyWith(
          recordingState: RecordingSaved(
            entryId: entryId,
            detectedLanguage: result.detectedLanguage,
          ),
        );
        if (tagFuture != null) {
          unawaited(
            ref.read(autoTagUseCaseProvider)(
              entryId: entryId,
              tagResultFuture: tagFuture,
              userTags: tags,
            ),
          );
        }
        return;
      case CleanupTranscriptFailure():
        _emitError(
          _mapCleanupFailure(cleanupResult.reason),
          preservedDraft: cleanupResult.entryId != null,
        );
        return;
    }
  }

  Future<bool> _persistAudioDraftIfNeeded(
    String? audioDraftPath, {
    String? language,
  }) async {
    if (audioDraftPath == null) {
      return false;
    }

    final normalizedAudioDraftPath = audioDraftPath.trim();
    if (normalizedAudioDraftPath.isEmpty) {
      return false;
    }

    try {
      final entityType = await FileSystemEntity.type(normalizedAudioDraftPath);
      if (entityType != FileSystemEntityType.file) {
        _logWarning(
          'Ignoring retryable audio draft path because it is not a readable file.',
          error: ArgumentError.value(
            normalizedAudioDraftPath,
            'audioDraftPath',
            'must point to an existing file',
          ),
        );
        return false;
      }
    } catch (error, stackTrace) {
      _logWarning(
        'Ignoring retryable audio draft path because it could not be validated.',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }

    try {
      await _entryRepository.saveAudioDraft(
        normalizedAudioDraftPath,
        language ?? cleanupTranscriptFallbackLanguage,
      );
      return true;
    } catch (error, stackTrace) {
      _logWarning(
        'Failed to persist retryable audio draft after transcription failure.',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  void _publishQuota(RecordQuotaState? quota) {
    if (quota != null) {
      _sessionQuotaNotifier.setQuota(quota);
    }
  }

  Future<void> _markHasEverRecorded() async {
    try {
      await _preferencesRepository.setHasEverRecorded(true);
    } catch (error, stackTrace) {
      _logWarning(
        'Failed to persist hasEverRecorded after successful save.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  RecordingError _mapTranscriptionFailure(TranscriptionFailureReason reason) {
    return switch (reason) {
      TranscriptionFailureReason.tooShort => RecordingError.tooShort,
      TranscriptionFailureReason.nothingCaught => RecordingError.noMatch,
      TranscriptionFailureReason.micBlocked => RecordingError.microphoneBlocked,
      TranscriptionFailureReason.network ||
      TranscriptionFailureReason.timeout => RecordingError.noInternet,
      TranscriptionFailureReason.backendUnavailable =>
        RecordingError.backendUnavailable,
      TranscriptionFailureReason.proxyAuthFailed =>
        RecordingError.proxyAuthFailed,
      TranscriptionFailureReason.rateLimited => RecordingError.rateLimited,
      TranscriptionFailureReason.speechNotRecognized =>
        RecordingError.speechNotRecognized,
      TranscriptionFailureReason.apiError => RecordingError.apiFailed,
    };
  }

  RecordingError _mapMicrophoneAccessState(MicrophoneAccessState accessState) {
    return switch (accessState) {
      MicrophoneAccessState.granted => RecordingError.apiFailed,
      MicrophoneAccessState.denied => RecordingError.microphoneDenied,
      MicrophoneAccessState.permanentlyDenied ||
      MicrophoneAccessState.restricted => RecordingError.microphoneBlocked,
    };
  }

  Future<void> _cancelListeningForPermissionLoss(
    MicrophoneAccessState accessState,
  ) async {
    try {
      await _transcriptionService.cancelLiveTranscription();
    } catch (error, stackTrace) {
      _emitError(
        RecordingError.apiFailed,
        cause: error,
        stackTrace: stackTrace,
      );
      return;
    }

    _cancelHardCapStopTimer();
    _listeningStartedAtElapsedRealtime = null;
    _emitError(_mapMicrophoneAccessState(accessState));
  }

  RecordingError _mapCleanupFailure(backend.BackendFailureReason reason) {
    return switch (reason) {
      backend.BackendFailureReason.timeout ||
      backend.BackendFailureReason.noInternet => RecordingError.noInternet,
      backend.BackendFailureReason.backendUnavailable =>
        RecordingError.backendUnavailable,
      backend.BackendFailureReason.proxyAuthFailed ||
      backend.BackendFailureReason.credentialRejected =>
        RecordingError.proxyAuthFailed,
      backend.BackendFailureReason.rateLimited => RecordingError.rateLimited,
      backend.BackendFailureReason.requestTooLarge ||
      backend.BackendFailureReason.quotaExceeded ||
      backend.BackendFailureReason.speechNotRecognized ||
      backend.BackendFailureReason.apiError => RecordingError.apiFailed,
    };
  }

  void _emitError(
    RecordingError nextError, {
    Object? cause,
    StackTrace? stackTrace,
    bool preservedDraft = false,
  }) {
    if (cause != null) {
      _logWarning(
        'Recording flow moved to error state: ${nextError.name}.',
        error: cause,
        stackTrace: stackTrace,
      );
    }

    final nextShakeKey = switch (nextError) {
      RecordingError.tooShort ||
      RecordingError.noMatch => state.shakeErrorKey + 1,
      _ => state.shakeErrorKey,
    };
    final errorState = RecordingErrorState(
      nextError,
      preservedDraft: preservedDraft,
    );
    state = state.copyWith(
      recordingState: errorState,
      shakeErrorKey: nextShakeKey,
    );
    _scheduleAutoClear(errorState);
  }

  void _scheduleAutoClear(RecordingState targetState) {
    _cancelAutoClearTimer();
    _autoClearTimer = Timer(_feedbackDelays.errorAndDeletedAutoClear, () {
      if (state.recordingState == targetState) {
        resetToIdle();
      }
    });
  }

  void _scheduleHardCapStop(RecordingListening targetState) {
    _cancelHardCapStopTimer();

    final remainingMs =
        targetState.hardCapDeadlineElapsedRealtime - _monotonicClock.now();
    final delay = Duration(milliseconds: remainingMs <= 0 ? 0 : remainingMs);
    _hardCapStopTimer = Timer(
      delay,
      () => _handleHardCapStopTimer(targetState),
    );
  }

  void _handleHardCapStopTimer(RecordingListening targetState) {
    final current = state.recordingState;
    if (current != targetState) {
      return;
    }

    if (_buttonActionInFlight) {
      _hardCapStopTimer = Timer(
        const Duration(milliseconds: 10),
        () => _handleHardCapStopTimer(targetState),
      );
      return;
    }

    unawaited(_stopListening());
  }

  void _cancelAutoClearTimer() {
    _autoClearTimer?.cancel();
    _autoClearTimer = null;
  }

  void _cancelHardCapStopTimer() {
    _hardCapStopTimer?.cancel();
    _hardCapStopTimer = null;
  }
}
