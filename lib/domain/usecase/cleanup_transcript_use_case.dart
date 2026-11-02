import '../../data/api/backend_results.dart' as backend;
import '../../data/api/record_quota_state.dart';
import '../model/entry.dart';
import '../model/supported_language.dart';
import '../repository/entry_repository.dart';

typedef CleanupTranscriptCallback = Future<backend.CleanupResult> Function({
  required String transcript,
  required String language,
});
typedef SetCleanupQuotaCallback = void Function(RecordQuotaState quota);
typedef CleanupWarningLogger = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

/// Spec-approved maximum cleanup request length. Only the request payload is
/// bounded; the persisted raw transcript remains full-length.
const cleanupTranscriptMaxLength = 10000;
const cleanupTranscriptFallbackLanguage = 'en-US';

class CleanupTranscriptUseCase {
  CleanupTranscriptUseCase({
    required this.cleanupTranscript,
    required this.entryRepository,
    required this.setRecordQuota,
    required this.logWarning,
  });

  final CleanupTranscriptCallback cleanupTranscript;
  final EntryRepository entryRepository;
  final SetCleanupQuotaCallback setRecordQuota;
  final CleanupWarningLogger logWarning;

  Future<CleanupTranscriptResult> call({
    required String rawTranscript,
    String? language,
    int? entryId,

    /// Used only when cleanup does not return its own quota.
    /// Cleanup quota takes precedence when both are available.
    RecordQuotaState? fallbackQuota,
  }) async {
    final existingEntryResult = await _loadExistingEntry(entryId);
    if (existingEntryResult case _ResolvedDraftFailure()) {
      _propagateQuota(fallbackQuota);
      return CleanupTranscriptFailure(
        entryId: existingEntryResult.entryId,
        reason: backend.BackendFailureReason.apiError,
        quota: fallbackQuota,
      );
    }
    final existingEntry = (existingEntryResult as _ResolvedDraftSuccess).entry;
    final selectedLanguage = _resolveCleanupLanguage(
      transcriptLanguage: language,
      existingEntry: existingEntry,
    );
    final persistedEntryId = await _ensureDraftPersisted(
      entryId: entryId,
      existingEntry: existingEntry,
      rawTranscript: rawTranscript,
      language: selectedLanguage,
    );
    if (persistedEntryId == null) {
      _propagateQuota(fallbackQuota);
      return CleanupTranscriptFailure(
        entryId: entryId,
        reason: backend.BackendFailureReason.apiError,
        quota: fallbackQuota,
      );
    }

    final boundedTranscript = _prepareTranscriptForCleanup(rawTranscript);
    if (boundedTranscript == null) {
      _propagateQuota(fallbackQuota);
      logWarning(
        'Cleanup transcript skipped backend cleanup because the raw transcript was blank.',
      );
      return CleanupTranscriptFailure(
        entryId: persistedEntryId,
        reason: backend.BackendFailureReason.apiError,
        quota: fallbackQuota,
      );
    }

    final cleanupResult = await _callCleanupBackend(
      transcript: boundedTranscript,
      language: selectedLanguage,
    );

    return switch (cleanupResult) {
      backend.CleanupSuccess() => _handleCleanupSuccess(
        cleanupResult,
        entryId: persistedEntryId,
        fallbackQuota: fallbackQuota,
      ),
      backend.CleanupFailure() => _handleCleanupFailure(
        cleanupResult,
        entryId: persistedEntryId,
        fallbackQuota: fallbackQuota,
      ),
    };
  }

  Future<_ResolvedDraftResult> _loadExistingEntry(int? entryId) async {
    if (entryId == null) {
      return const _ResolvedDraftSuccess(null);
    }

    try {
      final entry = await entryRepository.getEntryById(entryId);
      if (entry == null) {
        logWarning('Cleanup transcript received a missing entry id: $entryId.');
        return _ResolvedDraftFailure(entryId);
      }
      if (entry.type != EntryType.draft) {
        logWarning(
          'Cleanup transcript received a non-draft entry id: $entryId.',
        );
        return _ResolvedDraftFailure(entryId);
      }

      return _ResolvedDraftSuccess(entry);
    } catch (error, stackTrace) {
      logWarning(
        'Cleanup transcript failed to load the existing draft entry.',
        error: error,
        stackTrace: stackTrace,
      );
      return _ResolvedDraftFailure(entryId);
    }
  }

  String _resolveCleanupLanguage({
    required String? transcriptLanguage,
    required Entry? existingEntry,
  }) {
    return resolveSupportedLanguageCode(transcriptLanguage) ??
        resolveSupportedLanguageCode(existingEntry?.language) ??
        cleanupTranscriptFallbackLanguage;
  }

  Future<int?> _ensureDraftPersisted({
    required int? entryId,
    required Entry? existingEntry,
    required String rawTranscript,
    required String language,
  }) async {
    final wordCount = countWords(rawTranscript);
    try {
      if (entryId == null) {
        return await entryRepository.saveDraft(rawTranscript, language);
      }

      await entryRepository.updateDraftTranscriptAndLanguage(
        entryId,
        rawTranscript,
        wordCount,
        language,
      );
      return entryId;
    } catch (error, stackTrace) {
      logWarning(
        'Cleanup transcript failed to persist the draft state.',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  String? _prepareTranscriptForCleanup(String rawTranscript) {
    final normalized = rawTranscript.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.length <= cleanupTranscriptMaxLength) {
      return normalized;
    }

    return normalized.substring(0, cleanupTranscriptMaxLength);
  }

  Future<backend.CleanupResult> _callCleanupBackend({
    required String transcript,
    required String language,
  }) async {
    try {
      return await cleanupTranscript(
        transcript: transcript,
        language: language,
      );
    } catch (error, stackTrace) {
      logWarning(
        'Cleanup transcript crashed while calling backend cleanup.',
        error: error,
        stackTrace: stackTrace,
      );
      return const backend.CleanupFailure(
        reason: backend.BackendFailureReason.apiError,
      );
    }
  }

  Future<CleanupTranscriptResult> _handleCleanupSuccess(
    backend.CleanupSuccess result, {
    required int entryId,
    RecordQuotaState? fallbackQuota,
  }) async {
    final resolvedQuota = result.quota ?? fallbackQuota;
    _propagateQuota(resolvedQuota);
    try {
      await entryRepository.updateWithCleanedText(
        entryId,
        result.cleanedText,
        countWords(result.cleanedText),
      );

      return CleanupTranscriptSuccess(
        entryId: entryId,
        cleanedText: result.cleanedText,
        quota: resolvedQuota,
      );
    } catch (error, stackTrace) {
      logWarning(
        'Cleanup transcript failed to finalize the cleaned entry.',
        error: error,
        stackTrace: stackTrace,
      );
      return CleanupTranscriptFailure(
        entryId: entryId,
        reason: backend.BackendFailureReason.apiError,
        quota: resolvedQuota,
      );
    }
  }

  CleanupTranscriptResult _handleCleanupFailure(
    backend.CleanupFailure result, {
    required int entryId,
    RecordQuotaState? fallbackQuota,
  }) {
    final resolvedQuota = result.quota ?? fallbackQuota;
    _propagateQuota(resolvedQuota);
    return CleanupTranscriptFailure(
      entryId: entryId,
      reason: result.reason,
      quota: resolvedQuota,
    );
  }

  void _propagateQuota(RecordQuotaState? quota) {
    if (quota != null) {
      setRecordQuota(quota);
    }
  }
}

sealed class CleanupTranscriptResult {
  const CleanupTranscriptResult({required this.entryId, this.quota});

  final int? entryId;
  final RecordQuotaState? quota;
}

final class CleanupTranscriptSuccess extends CleanupTranscriptResult {
  const CleanupTranscriptSuccess({
    required super.entryId,
    required this.cleanedText,
    super.quota,
  });

  final String cleanedText;
}

final class CleanupTranscriptFailure extends CleanupTranscriptResult {
  const CleanupTranscriptFailure({
    required super.entryId,
    required this.reason,
    super.quota,
  });

  final backend.BackendFailureReason reason;
}

int countWords(String text) {
  return text
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .length;
}

sealed class _ResolvedDraftResult {
  const _ResolvedDraftResult();
}

final class _ResolvedDraftSuccess extends _ResolvedDraftResult {
  const _ResolvedDraftSuccess(this.entry);

  final Entry? entry;
}

final class _ResolvedDraftFailure extends _ResolvedDraftResult {
  const _ResolvedDraftFailure(this.entryId);

  final int? entryId;
}
