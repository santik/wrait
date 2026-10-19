import '../../data/transcription/transcription_service.dart';
import '../../data/api/backend_results.dart' show TagTextResult;
import '../../data/api/record_quota_state.dart';
import '../model/entry.dart';
import '../model/tag.dart';
import '../repository/entry_repository.dart';
import '../repository/tag_repository.dart';
import 'auto_tag_use_case.dart';
import 'cleanup_transcript_use_case.dart';

typedef ValidateDraftAudioPathCallback = Future<String?> Function(String path);
typedef DeleteRetainedAudioCallback = Future<void> Function(String path);
typedef SetRetryQuotaCallback = void Function(RecordQuotaState quota);
typedef RetryTagTextCallback =
    Future<TagTextResult> Function({
      required String text,
      required List<String> tags,
    });
typedef RetryPendingDraftsWarningLogger = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

const launchRetryStaleDraftDays = 7;

class RetryPendingDraftsUseCase {
  RetryPendingDraftsUseCase({
    required this.entryRepository,
    required this.transcriptionService,
    required this.cleanupTranscriptUseCase,
    required this.validateDraftAudioPath,
    required this.deleteRetainedAudio,
    required this.setRecordQuota,
    required this.logWarning,
    required this.autoTagUseCase,
    required this.tagText,
    required this.tagRepository,
    required this.autoTagEnabled,
  });

  final EntryRepository entryRepository;
  final TranscriptionService transcriptionService;
  final CleanupTranscriptUseCase cleanupTranscriptUseCase;
  final ValidateDraftAudioPathCallback validateDraftAudioPath;
  final DeleteRetainedAudioCallback deleteRetainedAudio;
  final SetRetryQuotaCallback setRecordQuota;
  final RetryPendingDraftsWarningLogger logWarning;
  final AutoTagUseCase autoTagUseCase;
  final RetryTagTextCallback tagText;
  final TagRepository tagRepository;
  final bool autoTagEnabled;

  Future<void>? _inFlight;

  Future<void> call() {
    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _run();
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
    return future;
  }

  Future<void> _run() async {
    try {
      await entryRepository.deleteStaleDrafts(
        daysOld: launchRetryStaleDraftDays,
      );
    } catch (error, stackTrace) {
      logWarning(
        'Failed to delete stale drafts before launch retry.',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    final drafts = await _loadPendingDrafts();
    if (drafts == null) {
      return;
    }

    for (final draft in drafts) {
      try {
        if (_isAudioDraft(draft)) {
          await _retryAudioDraft(draft);
        } else {
          await _retryTextDraft(draft);
        }
      } catch (error, stackTrace) {
        logWarning(
          'Failed to retry draft ${draft.id}.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<List<Entry>?> _loadPendingDrafts() async {
    try {
      return await entryRepository.getPendingDrafts();
    } catch (error, stackTrace) {
      logWarning(
        'Failed to load pending drafts during app launch.',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  bool _isAudioDraft(Entry entry) {
    final audioPath = entry.audioPath;
    return audioPath != null && audioPath.trim().isNotEmpty;
  }

  Future<void> _retryAudioDraft(Entry draft) async {
    final audioPath = draft.audioPath;
    if (audioPath == null) {
      return;
    }

    final validatedPath = await validateDraftAudioPath(audioPath);
    if (validatedPath == null) {
      await _deleteMalformedAudioDraft(draft.id);
      return;
    }

    final TranscriptionResult transcriptionResult;
    try {
      transcriptionResult = await transcriptionService.transcribeAudioDraft(
        validatedPath,
      );
    } on TranscriptionServiceFailure catch (error, stackTrace) {
      logWarning(
        'Launch retry preserved audio draft ${draft.id} after transcription service failure.',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    switch (transcriptionResult) {
      case TranscriptionSuccess():
        if (transcriptionResult.transcript.trim().isEmpty) {
          logWarning(
            'Launch retry preserved audio draft ${draft.id} because transcription returned a blank transcript.',
          );
          return;
        }
        await _handleSuccessfulAudioRetry(
          draftId: draft.id,
          audioPath: validatedPath,
          transcriptionResult: transcriptionResult,
        );
        return;
      case TranscriptionFailure():
        _publishQuota(transcriptionResult.quota);
        logWarning(
          'Launch retry preserved audio draft ${draft.id} after transcription failure: '
          '${transcriptionResult.reason.name}.',
        );
        return;
    }
  }

  Future<void> _handleSuccessfulAudioRetry({
    required int draftId,
    required String audioPath,
    required TranscriptionSuccess transcriptionResult,
  }) async {
    var tags = const <Tag>[];
    Future<TagTextResult>? tagFuture;
    if (autoTagEnabled) {
      tags = await tagRepository.getAllTags();
      tagFuture = _startTagFutureIfEligible(
        transcriptionResult.transcript,
        tags,
      );
    }

    final cleanupResult = await cleanupTranscriptUseCase(
      entryId: draftId,
      rawTranscript: transcriptionResult.transcript,
      language: transcriptionResult.detectedLanguage,
      fallbackQuota: transcriptionResult.quota,
    );

    switch (cleanupResult) {
      case CleanupTranscriptSuccess():
        await _deleteRetainedAudioBestEffort(
          audioPath,
          logContext: 'successful draft finalization',
        );
        if (tagFuture != null) {
          await autoTagUseCase(
            entryId: draftId,
            tagResultFuture: tagFuture,
            userTags: tags,
          );
        }
        return;
      case CleanupTranscriptFailure():
        final refreshedEntry = await _safeGetEntryById(draftId);
        if (refreshedEntry != null && !_isAudioDraft(refreshedEntry)) {
          await _deleteRetainedAudioBestEffort(
            audioPath,
            logContext: 'audio-to-text draft promotion',
          );
          return;
        }

        logWarning(
          'Launch retry preserved audio draft $draftId after cleanup failure: '
          '${cleanupResult.reason.name}.',
        );
        return;
    }
  }

  Future<void> _retryTextDraft(Entry draft) async {
    var tags = const <Tag>[];
    Future<TagTextResult>? tagFuture;
    if (autoTagEnabled) {
      tags = await tagRepository.getAllTags();
      tagFuture = _startTagFutureIfEligible(draft.rawTranscript, tags);
    }

    final cleanupResult = await cleanupTranscriptUseCase(
      entryId: draft.id,
      rawTranscript: draft.rawTranscript,
      language: draft.language,
    );

    if (cleanupResult case CleanupTranscriptFailure(reason: final reason)) {
      logWarning(
        'Launch retry preserved text draft ${draft.id} after cleanup failure: '
        '${reason.name}.',
      );
    }

    if (cleanupResult case CleanupTranscriptSuccess(
      entryId: final entryId?,
    ) when entryId > 0 && tagFuture != null) {
      await autoTagUseCase(
        entryId: entryId,
        tagResultFuture: tagFuture,
        userTags: tags,
      );
    }
  }

  Future<TagTextResult>? _startTagFutureIfEligible(
    String rawTranscript,
    List<Tag> tags,
  ) {
    if (tags.length < 2) return null;
    final trimmed = rawTranscript.trim();
    if (trimmed.isEmpty) return null;
    return tagText(text: trimmed, tags: tags.map((t) => t.name).toList());
  }

  Future<void> _deleteMalformedAudioDraft(int draftId) async {
    try {
      await entryRepository.deleteEntry(draftId);
    } catch (error, stackTrace) {
      logWarning(
        'Failed to delete malformed audio draft $draftId.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Entry?> _safeGetEntryById(int draftId) async {
    try {
      return await entryRepository.getEntryById(draftId);
    } catch (error, stackTrace) {
      logWarning(
        'Failed to reload draft $draftId after cleanup retry.',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _deleteRetainedAudioBestEffort(
    String audioPath, {
    required String logContext,
  }) async {
    try {
      await deleteRetainedAudio(audioPath);
    } catch (error, stackTrace) {
      logWarning(
        'Failed to delete retained draft audio after $logContext.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _publishQuota(RecordQuotaState? quota) {
    if (quota != null) {
      setRecordQuota(quota);
    }
  }
}
