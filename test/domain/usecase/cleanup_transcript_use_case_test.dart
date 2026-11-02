import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/usecase/cleanup_transcript_use_case.dart';

import '../../test_doubles/fake_clock.dart';

void main() {
  late _FakeEntryRepository entryRepository;
  late RecordQuotaState? currentQuota;
  late List<String> logMessages;
  late List<Object?> logErrors;
  late int cleanupCallCount;
  late String? capturedTranscript;
  late String? capturedLanguage;
  late Future<backend.CleanupResult> Function({
    required String transcript,
    required String language,
  })
  cleanupTranscript;
  late CleanupTranscriptUseCase useCase;

  setUp(() {
    entryRepository = _FakeEntryRepository(FakeClock(1));
    currentQuota = null;
    logMessages = <String>[];
    logErrors = <Object?>[];
    cleanupCallCount = 0;
    capturedTranscript = null;
    capturedLanguage = null;
    cleanupTranscript = ({required transcript, required language}) async {
      cleanupCallCount += 1;
      capturedTranscript = transcript;
      capturedLanguage = language;
      return const backend.CleanupSuccess(cleanedText: 'Cleaned transcript.');
    };
    useCase = CleanupTranscriptUseCase(
      cleanupTranscript:
          ({required String transcript, required String language}) {
            return cleanupTranscript(
              transcript: transcript,
              language: language,
            );
          },
      entryRepository: entryRepository,
      setRecordQuota: (quota) => currentQuota = quota,
      logWarning: (message, {error, stackTrace}) {
        logMessages.add(message);
        logErrors.add(error);
      },
    );
  });

  test(
    'fresh cleanup success creates and finalizes one draft while updating quota',
    () async {
      final quota = RecordQuotaState(
        limit: 5,
        count: 3,
        remaining: 2,
        resetAt: DateTime.utc(2026, 6, 12),
      );
      cleanupTranscript = ({required transcript, required language}) async {
        cleanupCallCount += 1;
        capturedTranscript = transcript;
        capturedLanguage = language;
        return backend.CleanupSuccess(
          cleanedText: 'Cleaned transcript.',
          quota: quota,
        );
      };
      const rawTranscript = '  raw transcript with fillers  ';

      final result = await useCase(
        rawTranscript: rawTranscript,
        language: 'FR_fr',
      );

      expect(
        result,
        isA<CleanupTranscriptSuccess>()
            .having((value) => value.entryId, 'entryId', 1)
            .having(
              (value) => value.cleanedText,
              'cleanedText',
              'Cleaned transcript.',
            )
            .having((value) => value.quota?.remaining, 'quotaRemaining', 2),
      );
      expect(cleanupCallCount, 1);
      expect(capturedTranscript, 'raw transcript with fillers');
      expect(capturedLanguage, 'fr-FR');
      expect(currentQuota?.remaining, 2);

      final entry = await entryRepository.getEntryById(1);
      expect(entry, isNotNull);
      expect(entry!.rawTranscript, rawTranscript);
      expect(entry.cleanedText, 'Cleaned transcript.');
      expect(entry.type, EntryType.saved);
      expect(entry.language, 'fr-FR');
      expect(entry.wordCount, 2);
      expect(logMessages, isEmpty);
    },
  );

  test(
    'blank input fails without backend call but still persists a draft',
    () async {
      final result = await useCase(rawTranscript: '   ');

      expect(
        result,
        isA<CleanupTranscriptFailure>()
            .having((value) => value.entryId, 'entryId', 1)
            .having((value) => value.entryId, 'entryId', 1)
            .having(
              (value) => value.reason,
              'reason',
              backend.BackendFailureReason.apiError,
            ),
      );
      expect(cleanupCallCount, 0);
      expect(currentQuota, isNull);
      expect(logMessages.single, contains('raw transcript was blank'));

      final entry = await entryRepository.getEntryById(1);
      expect(entry, isNotNull);
      expect(entry!.type, EntryType.draft);
      expect(entry.rawTranscript, '   ');
      expect(entry.cleanedText, isNull);
      expect(entry.language, cleanupTranscriptFallbackLanguage);
      expect(entry.wordCount, 0);
    },
  );

  test(
    'existing draft reuse updates transcript, clears audio path, and uses stored language when input is missing',
    () async {
      final existingId = await entryRepository.saveAudioDraft(
        '/tmp/audio.m4a',
        'en-US',
      );
      final quota = RecordQuotaState(
        limit: 5,
        count: 5,
        remaining: 0,
        resetAt: DateTime.utc(2026, 6, 12),
      );
      cleanupTranscript = ({required transcript, required language}) async {
        cleanupCallCount += 1;
        capturedTranscript = transcript;
        capturedLanguage = language;
        return backend.CleanupFailure(
          reason: backend.BackendFailureReason.noInternet,
          quota: quota,
        );
      };

      final result = await useCase(
        entryId: existingId,
        rawTranscript: 'updated raw transcript',
      );

      expect(
        result,
        isA<CleanupTranscriptFailure>()
            .having((value) => value.entryId, 'entryId', existingId)
            .having(
              (value) => value.reason,
              'reason',
              backend.BackendFailureReason.noInternet,
            )
            .having((value) => value.quota?.remaining, 'quotaRemaining', 0),
      );
      expect(cleanupCallCount, 1);
      expect(capturedLanguage, 'en-US');
      expect(currentQuota?.remaining, 0);

      final entry = await entryRepository.getEntryById(existingId);
      expect(entry, isNotNull);
      expect(entry!.rawTranscript, 'updated raw transcript');
      expect(entry.cleanedText, isNull);
      expect(entry.type, EntryType.draft);
      expect(entry.audioPath, isNull);
      expect(entry.wordCount, 3);
    },
  );

  test(
    'malformed cleanup failure preserves the draft and still propagates quota',
    () async {
      final quota = RecordQuotaState(
        limit: 5,
        count: 4,
        remaining: 1,
        resetAt: DateTime.utc(2026, 6, 12),
      );
      cleanupTranscript = ({required transcript, required language}) async {
        cleanupCallCount += 1;
        return backend.CleanupFailure(
          reason: backend.BackendFailureReason.apiError,
          quota: quota,
        );
      };

      final result = await useCase(
        rawTranscript: 'raw transcript',
        language: 'en-US',
      );

      expect(
        result,
        isA<CleanupTranscriptFailure>()
            .having((value) => value.entryId, 'entryId', 1)
            .having(
              (value) => value.reason,
              'reason',
              backend.BackendFailureReason.apiError,
            )
            .having((value) => value.quota?.remaining, 'quotaRemaining', 1),
      );
      expect(currentQuota?.remaining, 1);
      expect(logMessages, isEmpty);

      final entry = await entryRepository.getEntryById(1);
      expect(entry, isNotNull);
      expect(entry!.type, EntryType.draft);
      expect(entry.cleanedText, isNull);
      expect(entry.wordCount, 2);
    },
  );

  test(
    'cleanup failure falls back to transcription quota when cleanup returns no quota',
    () async {
      final fallbackQuota = RecordQuotaState(
        limit: 5,
        count: 4,
        remaining: 1,
        resetAt: DateTime.utc(2026, 6, 12),
      );
      cleanupTranscript = ({required transcript, required language}) async {
        cleanupCallCount += 1;
        return const backend.CleanupFailure(
          reason: backend.BackendFailureReason.backendUnavailable,
        );
      };

      final result = await useCase(
        rawTranscript: 'raw transcript',
        language: 'en-US',
        fallbackQuota: fallbackQuota,
      );

      expect(
        result,
        isA<CleanupTranscriptFailure>()
            .having((value) => value.entryId, 'entryId', 1)
            .having(
              (value) => value.reason,
              'reason',
              backend.BackendFailureReason.backendUnavailable,
            )
            .having((value) => value.quota?.remaining, 'quotaRemaining', 1),
      );
      expect(currentQuota?.remaining, 1);
    },
  );

  test(
    'cleanup failure keeps quota unchanged when both cleanup and fallback quotas are null',
    () async {
      currentQuota = RecordQuotaState(
        limit: 5,
        count: 2,
        remaining: 3,
        resetAt: DateTime.utc(2026, 6, 12),
      );
      cleanupTranscript = ({required transcript, required language}) async {
        cleanupCallCount += 1;
        return const backend.CleanupFailure(
          reason: backend.BackendFailureReason.backendUnavailable,
        );
      };

      final result = await useCase(
        rawTranscript: 'raw transcript',
        language: 'en-US',
      );

      expect(
        result,
        isA<CleanupTranscriptFailure>()
            .having((value) => value.entryId, 'entryId', 1)
            .having((value) => value.quota, 'quota', isNull)
            .having(
              (value) => value.reason,
              'reason',
              backend.BackendFailureReason.backendUnavailable,
            ),
      );
      expect(cleanupCallCount, 1);
      expect(currentQuota?.remaining, 3);
      expect(currentQuota?.count, 2);
    },
  );

  test(
    'missing draft entry id returns typed failure instead of throwing',
    () async {
      final result = await useCase(
        entryId: 999,
        rawTranscript: 'raw transcript',
      );

      expect(
        result,
        isA<CleanupTranscriptFailure>()
            .having((value) => value.entryId, 'entryId', 999)
            .having(
              (value) => value.reason,
              'reason',
              backend.BackendFailureReason.apiError,
            ),
      );
      expect(cleanupCallCount, 0);
      expect(logMessages.single, contains('missing entry id'));
    },
  );

  test(
    'finalized entry id returns typed failure instead of throwing',
    () async {
      final entryId = await entryRepository.saveEntry('done already', 'en-US');

      final result = await useCase(
        entryId: entryId,
        rawTranscript: 'raw transcript',
      );

      expect(
        result,
        isA<CleanupTranscriptFailure>()
            .having((value) => value.entryId, 'entryId', entryId)
            .having(
              (value) => value.reason,
              'reason',
              backend.BackendFailureReason.apiError,
            ),
      );
      expect(cleanupCallCount, 0);
      expect(logMessages.single, contains('non-draft entry id'));
    },
  );

  test('saveDraft failure returns typed failure instead of throwing', () async {
    entryRepository.failSaveDraft = true;

    final fallbackQuota = RecordQuotaState(
      limit: 5,
      count: 3,
      remaining: 2,
      resetAt: DateTime.utc(2026, 6, 12),
    );
    final result = await useCase(
      rawTranscript: 'raw transcript',
      fallbackQuota: fallbackQuota,
    );

    expect(
      result,
      isA<CleanupTranscriptFailure>()
          .having((value) => value.entryId, 'entryId', isNull)
          .having(
            (value) => value.reason,
            'reason',
            backend.BackendFailureReason.apiError,
          )
          .having((value) => value.quota?.remaining, 'quotaRemaining', 2),
    );
    expect(cleanupCallCount, 0);
    expect(currentQuota?.remaining, 2);
    expect(logErrors.single, isA<StateError>());
  });

  test(
    'atomic draft update failure returns typed failure and skips backend call',
    () async {
      final entryId = await entryRepository.saveAudioDraft(
        '/tmp/audio.m4a',
        'en-US',
      );
      entryRepository.failUpdateDraftTranscriptAndLanguage = true;

      final result = await useCase(
        entryId: entryId,
        rawTranscript: 'raw transcript',
      );

      expect(
        result,
        isA<CleanupTranscriptFailure>()
            .having((value) => value.entryId, 'entryId', entryId)
            .having(
              (value) => value.reason,
              'reason',
              backend.BackendFailureReason.apiError,
            ),
      );
      expect(cleanupCallCount, 0);
      expect(logErrors.single, isA<StateError>());
    },
  );

  test(
    'finalize failure returns typed failure and keeps backend quota',
    () async {
      final quota = RecordQuotaState(
        limit: 5,
        count: 3,
        remaining: 2,
        resetAt: DateTime.utc(2026, 6, 12),
      );
      entryRepository.failUpdateWithCleanedText = true;
      cleanupTranscript = ({required transcript, required language}) async {
        cleanupCallCount += 1;
        return backend.CleanupSuccess(
          cleanedText: 'Cleaned transcript.',
          quota: quota,
        );
      };

      final result = await useCase(rawTranscript: 'raw transcript');

      expect(
        result,
        isA<CleanupTranscriptFailure>()
            .having((value) => value.entryId, 'entryId', 1)
            .having((value) => value.quota?.remaining, 'quotaRemaining', 2)
            .having(
              (value) => value.reason,
              'reason',
              backend.BackendFailureReason.apiError,
            ),
      );
      expect(currentQuota?.remaining, 2);
      expect(logErrors.single, isA<StateError>());
    },
  );

  test(
    'request transcript is trimmed and truncated while stored raw transcript stays full length',
    () async {
      final oversizedTranscript =
          ' ${'a' * (cleanupTranscriptMaxLength + 25)} ';

      final result = await useCase(
        rawTranscript: oversizedTranscript,
        language: 'zz-ZZ',
      );

      expect(result, isA<CleanupTranscriptSuccess>());
      expect(capturedTranscript, isNotNull);
      expect(capturedTranscript, hasLength(cleanupTranscriptMaxLength));
      expect(
        capturedTranscript,
        ('a' * (cleanupTranscriptMaxLength + 25)).substring(
          0,
          cleanupTranscriptMaxLength,
        ),
      );
      expect(capturedLanguage, cleanupTranscriptFallbackLanguage);

      final entry = await entryRepository.getEntryById(1);
      expect(entry, isNotNull);
      expect(entry!.rawTranscript, oversizedTranscript);
    },
  );
}

class _FakeEntryRepository implements EntryRepository {
  _FakeEntryRepository(this.clock);

  final FakeClock clock;
  final Map<int, Entry> _entries = <int, Entry>{};
  int _nextId = 1;
  bool failSaveDraft = false;
  bool failUpdateDraftTranscriptAndLanguage = false;
  bool failUpdateWithCleanedText = false;

  @override
  Future<Entry?> getEntryById(int id) async => _entries[id];

  @override
  Future<List<int>> importEntries(List<Entry> entries) async => const [];

  @override
  Future<int> saveDraft(String transcript, String language) async {
    if (failSaveDraft) {
      throw StateError('saveDraft failed');
    }
    final id = _nextId++;
    _entries[id] = Entry(
      id: id,
      rawTranscript: transcript,
      type: EntryType.draft,
      language: language,
      createdAt: clock.now(),
      wordCount: countWords(transcript),
    );
    return id;
  }

  @override
  Future<int> saveEntry(String transcript, String language) async {
    final id = _nextId++;
    _entries[id] = Entry(
      id: id,
      rawTranscript: transcript,
      type: EntryType.saved,
      language: language,
      createdAt: clock.now(),
      wordCount: countWords(transcript),
    );
    return id;
  }

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async {
    final id = _nextId++;
    _entries[id] = Entry(
      id: id,
      rawTranscript: '',
      type: EntryType.draft,
      language: language,
      createdAt: clock.now(),
      wordCount: 0,
      audioPath: audioPath,
    );
    return id;
  }

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {
    final existing = _requireEntry(id);
    _entries[id] = existing.copyWith(
      cleanedText: cleanedText,
      wordCount: cleanedText
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .length,
    );
  }

  @override
  Future<void> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  ) async {
    final existing = _requireEntry(id);
    _entries[id] = existing.copyWith(
      rawTranscript: rawTranscript,
      wordCount: wordCount,
      clearAudioPath: true,
    );
  }

  @override
  Future<void> updateDraftTranscriptAndLanguage(
    int id,
    String rawTranscript,
    int wordCount,
    String language,
  ) async {
    if (failUpdateDraftTranscriptAndLanguage) {
      throw StateError('updateDraftTranscriptAndLanguage failed');
    }
    final existing = _requireEntry(id);
    _entries[id] = existing.copyWith(
      rawTranscript: rawTranscript,
      wordCount: wordCount,
      language: language,
      clearAudioPath: true,
    );
  }

  @override
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) async {
    if (failUpdateWithCleanedText) {
      throw StateError('updateWithCleanedText failed');
    }
    final existing = _requireEntry(id);
    _entries[id] = existing.copyWith(
      cleanedText: cleanedText,
      wordCount: wordCount,
      type: EntryType.saved,
      clearAudioPath: true,
    );
  }

  @override
  Future<void> updateEntryLanguage(int id, String language) async {
    final existing = _requireEntry(id);
    _entries[id] = existing.copyWith(language: language);
  }

  Entry _requireEntry(int id) {
    final entry = _entries[id];
    if (entry == null) {
      throw StateError('Entry with id $id not found or already deleted');
    }
    return entry;
  }

  @override
  Stream<List<Entry>> watchAllEntries() => throw UnimplementedError();

  @override
  Stream<Entry?> watchEntryById(int id) => throw UnimplementedError();

  @override
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) => throw UnimplementedError();

  @override
  Future<List<Entry>> getPendingDrafts() => throw UnimplementedError();

  @override
  Future<void> deleteEntry(int id) => throw UnimplementedError();

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) =>
      throw UnimplementedError();
}
