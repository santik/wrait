import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/transcription/transcription_service.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/model/tag.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/tag_repository.dart';
import 'package:wrait/domain/usecase/auto_tag_use_case.dart';
import 'package:wrait/domain/usecase/cleanup_transcript_use_case.dart';
import 'package:wrait/domain/usecase/retry_pending_drafts_use_case.dart';

void main() {
  late Directory tempDirectory;
  late _FakeEntryRepository entryRepository;
  late _FakeTranscriptionService transcriptionService;
  late List<String> logMessages;
  late List<Object?> logErrors;
  late RecordQuotaState? currentQuota;
  late int currentTimeMs;
  late Future<backend.CleanupResult> Function({
    required String transcript,
    required String language,
  })
  cleanupCallback;
  late CleanupTranscriptUseCase cleanupUseCase;
  late _FakeTagRepository tagRepository;
  late List<List<String>> tagTextCalls;
  late RetryTagTextCallback tagTextCallback;
  late RetryPendingDraftsUseCase useCase;

  Future<String?> validateAudioPath(String path) async {
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty) {
      return null;
    }

    final file = File(trimmedPath);
    try {
      if (!await file.exists()) {
        return null;
      }

      final handle = await file.open(mode: FileMode.read);
      try {
        // Open the file to prove it is readable before retry uploads.
      } finally {
        await handle.close();
      }

      if (await file.length() <= 0) {
        return null;
      }
    } on FileSystemException {
      return null;
    }

    return trimmedPath;
  }

  Future<void> deleteRetainedAudio(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'wrait-retry-pending-drafts-test',
    );
    currentTimeMs = DateTime.utc(2026, 6, 19).millisecondsSinceEpoch;
    entryRepository = _FakeEntryRepository(() => currentTimeMs);
    transcriptionService = _FakeTranscriptionService();
    logMessages = <String>[];
    logErrors = <Object?>[];
    currentQuota = null;
    cleanupCallback = ({required transcript, required language}) async {
      return const backend.CleanupSuccess(cleanedText: 'Cleaned transcript.');
    };
    cleanupUseCase = CleanupTranscriptUseCase(
      cleanupTranscript:
          ({required String transcript, required String language}) {
            return cleanupCallback(transcript: transcript, language: language);
          },
      entryRepository: entryRepository,
      setRecordQuota: (_) {},
      logWarning: (message, {error, stackTrace}) {
        logMessages.add(message);
        logErrors.add(error);
      },
    );
    tagRepository = _FakeTagRepository();
    tagTextCalls = <List<String>>[];
    tagTextCallback = ({required text, required tags}) async {
      return const backend.TagTextFailure(
        reason: backend.BackendFailureReason.apiError,
      );
    };
    useCase = RetryPendingDraftsUseCase(
      entryRepository: entryRepository,
      transcriptionService: transcriptionService,
      cleanupTranscriptUseCase: cleanupUseCase,
      validateDraftAudioPath: validateAudioPath,
      deleteRetainedAudio: deleteRetainedAudio,
      setRecordQuota: (quota) => currentQuota = quota,
      logWarning: (message, {error, stackTrace}) {
        logMessages.add(message);
        logErrors.add(error);
      },
      autoTagUseCase: AutoTagUseCase(
        tagRepository: tagRepository,
        logWarning: (message, {error, stackTrace}) {},
      ),
      tagText: ({required text, required tags}) {
        tagTextCalls.add(tags);
        return tagTextCallback(text: text, tags: tags);
      },
      tagRepository: tagRepository,
      autoTagEnabled: true,
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'audio draft success finalizes the same entry, updates language, and deletes retained audio',
    () async {
      final audioFile = await _writeAudioFile(
        tempDirectory,
        'audio-success.m4a',
      );
      final draftId = entryRepository.seedEntry(
        Entry(
          id: 0,
          rawTranscript: '',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs,
          wordCount: 0,
          audioPath: audioFile.path,
        ),
      );
      transcriptionService.nextDraftResult = const TranscriptionSuccess(
        transcript: 'bonjour monde',
        detectedLanguage: 'fr-FR',
      );
      cleanupCallback = ({required transcript, required language}) async {
        expect(transcript, 'bonjour monde');
        expect(language, 'fr-FR');
        return const backend.CleanupSuccess(
          cleanedText: 'Bonjour monde nettoye',
        );
      };

      await useCase();

      final entry = await entryRepository.getEntryById(draftId);
      expect(entry, isNotNull);
      expect(entry!.type, EntryType.saved);
      expect(entry.rawTranscript, 'bonjour monde');
      expect(entry.cleanedText, 'Bonjour monde nettoye');
      expect(entry.language, 'fr-FR');
      expect(entry.audioPath, isNull);
      expect(await audioFile.exists(), isFalse);
      expect(transcriptionService.transcribedAudioPaths, [audioFile.path]);
    },
  );

  test(
    'audio transcription failure preserves the audio draft, retained file, and returned quota',
    () async {
      final audioFile = await _writeAudioFile(
        tempDirectory,
        'audio-failure.m4a',
      );
      final draftId = entryRepository.seedEntry(
        Entry(
          rawTranscript: '',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs,
          wordCount: 0,
          audioPath: audioFile.path,
        ),
      );
      final quota = RecordQuotaState(
        limit: 5,
        count: 5,
        remaining: 0,
        resetAt: DateTime.utc(2026, 6, 12),
      );
      transcriptionService.nextDraftResult = TranscriptionFailure(
        reason: TranscriptionFailureReason.network,
        quota: quota,
      );

      await useCase();

      final entry = await entryRepository.getEntryById(draftId);
      expect(entry, isNotNull);
      expect(entry!.type, EntryType.draft);
      expect(entry.audioPath, audioFile.path);
      expect(await audioFile.exists(), isTrue);
      expect(currentQuota, quota);
      expect(logMessages.last, contains('preserved audio draft'));
    },
  );

  test(
    'transcription service failure preserves the audio draft and retained file',
    () async {
      final audioFile = await _writeAudioFile(
        tempDirectory,
        'audio-service-failure.m4a',
      );
      final draftId = entryRepository.seedEntry(
        Entry(
          rawTranscript: '',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs,
          wordCount: 0,
          audioPath: audioFile.path,
        ),
      );
      transcriptionService.nextDraftResultFactory = () async =>
          throw const TranscriptionAlreadyInProgressFailure();

      await useCase();

      final entry = await entryRepository.getEntryById(draftId);
      expect(entry, isNotNull);
      expect(entry!.type, EntryType.draft);
      expect(entry.audioPath, audioFile.path);
      expect(await audioFile.exists(), isTrue);
      expect(
        logMessages.last,
        contains(
          'preserved audio draft $draftId after transcription service failure',
        ),
      );
      expect(logErrors.last, isA<TranscriptionAlreadyInProgressFailure>());
    },
  );

  test(
    'blank transcription success preserves the audio draft and skips cleanup',
    () async {
      final audioFile = await _writeAudioFile(
        tempDirectory,
        'audio-blank-transcript.m4a',
      );
      final draftId = entryRepository.seedEntry(
        Entry(
          rawTranscript: '',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs,
          wordCount: 0,
          audioPath: audioFile.path,
        ),
      );
      transcriptionService.nextDraftResult = const TranscriptionSuccess(
        transcript: '   ',
        detectedLanguage: 'en-US',
      );

      await useCase();

      final entry = await entryRepository.getEntryById(draftId);
      expect(entry, isNotNull);
      expect(entry!.type, EntryType.draft);
      expect(entry.rawTranscript, '');
      expect(entry.audioPath, audioFile.path);
      expect(await audioFile.exists(), isTrue);
      expect(
        logMessages.last,
        contains('because transcription returned a blank transcript'),
      );
    },
  );

  test(
    'audio transcription success plus cleanup failure promotes to a text draft and deletes retained audio',
    () async {
      final audioFile = await _writeAudioFile(
        tempDirectory,
        'audio-promote.m4a',
      );
      final draftId = entryRepository.seedEntry(
        Entry(
          rawTranscript: '',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs,
          wordCount: 0,
          audioPath: audioFile.path,
        ),
      );
      transcriptionService.nextDraftResult = const TranscriptionSuccess(
        transcript: 'retry transcript',
        detectedLanguage: 'nl-NL',
      );
      cleanupCallback = ({required transcript, required language}) async {
        return const backend.CleanupFailure(
          reason: backend.BackendFailureReason.backendUnavailable,
        );
      };

      await useCase();

      final entry = await entryRepository.getEntryById(draftId);
      expect(entry, isNotNull);
      expect(entry!.type, EntryType.draft);
      expect(entry.rawTranscript, 'retry transcript');
      expect(entry.language, 'nl-NL');
      expect(entry.audioPath, isNull);
      expect(await audioFile.exists(), isFalse);
    },
  );

  test('missing or unreadable audio draft is deleted', () async {
    final draftId = entryRepository.seedEntry(
      Entry(
        rawTranscript: '',
        type: EntryType.draft,
        language: 'en-US',
        createdAt: currentTimeMs,
        wordCount: 0,
        audioPath: '${tempDirectory.path}/missing-file.m4a',
      ),
    );

    await useCase();

    expect(await entryRepository.getEntryById(draftId), isNull);
  });

  test(
    'stale cleanup runs before retry and one draft failure does not block later drafts',
    () async {
      final staleAudio = await _writeAudioFile(
        tempDirectory,
        'stale-audio.m4a',
      );
      final failedAudio = await _writeAudioFile(
        tempDirectory,
        'failed-audio.m4a',
      );
      entryRepository.seedEntry(
        Entry(
          rawTranscript: '',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs - const Duration(days: 8).inMilliseconds,
          wordCount: 0,
          audioPath: staleAudio.path,
        ),
      );
      entryRepository.seedEntry(
        Entry(
          rawTranscript: 'older text draft',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs - 2000,
          wordCount: 3,
        ),
      );
      entryRepository.seedEntry(
        Entry(
          rawTranscript: '',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs - 1000,
          wordCount: 0,
          audioPath: failedAudio.path,
        ),
      );
      transcriptionService.nextDraftResults.add(
        const TranscriptionFailure(reason: TranscriptionFailureReason.timeout),
      );
      cleanupCallback = ({required transcript, required language}) async {
        return const backend.CleanupSuccess(cleanedText: 'Cleaned text draft');
      };

      await useCase();

      expect(entryRepository.deleteStaleCalls, 1);
      expect(await staleAudio.exists(), isFalse);
      expect(transcriptionService.transcribedAudioPaths, [failedAudio.path]);
      expect(
        entryRepository.entries.values.where(
          (entry) => entry.type == EntryType.draft,
        ),
        hasLength(1),
      );
      expect(
        entryRepository.entries.values.any(
          (entry) =>
              entry.rawTranscript == 'older text draft' &&
              entry.type == EntryType.saved,
        ),
        isTrue,
      );
    },
  );

  test(
    'quota and proxy failures preserve drafts and single-flight prevents overlap',
    () async {
      final audioFile = await _writeAudioFile(tempDirectory, 'quota-audio.m4a');
      final audioDraftId = entryRepository.seedEntry(
        Entry(
          rawTranscript: '',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs,
          wordCount: 0,
          audioPath: audioFile.path,
        ),
      );
      final textDraftId = entryRepository.seedEntry(
        Entry(
          rawTranscript: 'raw transcript',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs - 1,
          wordCount: 2,
        ),
      );
      final audioCompleter = Completer<TranscriptionResult>();
      transcriptionService.nextDraftResultFactory = () => audioCompleter.future;
      cleanupCallback = ({required transcript, required language}) async {
        return const backend.CleanupFailure(
          reason: backend.BackendFailureReason.proxyAuthFailed,
        );
      };

      final firstCall = useCase();
      final secondCall = useCase();
      audioCompleter.complete(
        const TranscriptionFailure(reason: TranscriptionFailureReason.apiError),
      );
      await Future.wait<void>(<Future<void>>[firstCall, secondCall]);

      final audioEntry = await entryRepository.getEntryById(audioDraftId);
      final textEntry = await entryRepository.getEntryById(textDraftId);
      expect(audioEntry, isNotNull);
      expect(audioEntry!.type, EntryType.draft);
      expect(audioEntry.audioPath, audioFile.path);
      expect(textEntry, isNotNull);
      expect(textEntry!.type, EntryType.draft);
      expect(transcriptionService.transcribedAudioPaths, [audioFile.path]);
    },
  );

  group('auto-tag during retry', () {
    const workTag = Tag(id: 1, name: 'work');
    const healthTag = Tag(id: 2, name: 'health');

    test('text draft retry: cleanup succeeds -> auto-tag runs', () async {
      tagRepository.allTags = [workTag, healthTag];
      final draftId = entryRepository.seedEntry(
        Entry(
          rawTranscript: 'meeting with my team',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs,
          wordCount: 4,
        ),
      );
      tagTextCallback = ({required text, required tags}) async {
        expect(text, 'meeting with my team');
        return const backend.TagTextSuccess(
          tags: [
            backend.TagProbabilityResult(tag: 'work', probability: 0.9),
            backend.TagProbabilityResult(tag: 'health', probability: 0.1),
          ],
        );
      };

      await useCase();

      expect(tagTextCalls, [
        ['work', 'health'],
      ]);
      expect(tagRepository.setTagsCalls, hasLength(1));
      expect(tagRepository.setTagsCalls.single.entryId, draftId);
      expect(tagRepository.setTagsCalls.single.tagIds, [workTag.id]);
    });

    test('audio draft retry: cleanup succeeds -> auto-tag runs', () async {
      tagRepository.allTags = [workTag, healthTag];
      final audioFile = await _writeAudioFile(
        tempDirectory,
        'audio-auto-tag.m4a',
      );
      final draftId = entryRepository.seedEntry(
        Entry(
          rawTranscript: '',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs,
          wordCount: 0,
          audioPath: audioFile.path,
        ),
      );
      transcriptionService.nextDraftResult = const TranscriptionSuccess(
        transcript: 'went for a long run',
        detectedLanguage: 'en-US',
      );
      tagTextCallback = ({required text, required tags}) async {
        expect(text, 'went for a long run');
        return const backend.TagTextSuccess(
          tags: [
            backend.TagProbabilityResult(tag: 'health', probability: 0.8),
          ],
        );
      };

      await useCase();

      expect(tagTextCalls, [
        ['work', 'health'],
      ]);
      expect(tagRepository.setTagsCalls, hasLength(1));
      expect(tagRepository.setTagsCalls.single.entryId, draftId);
      expect(tagRepository.setTagsCalls.single.tagIds, [healthTag.id]);
    });

    test('retry cleanup fails -> no auto-tag assignment', () async {
      tagRepository.allTags = [workTag, healthTag];
      entryRepository.seedEntry(
        Entry(
          rawTranscript: 'meeting with my team',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs,
          wordCount: 4,
        ),
      );
      cleanupCallback = ({required transcript, required language}) async {
        return const backend.CleanupFailure(
          reason: backend.BackendFailureReason.backendUnavailable,
        );
      };
      tagTextCallback = ({required text, required tags}) async {
        return const backend.TagTextSuccess(
          tags: [backend.TagProbabilityResult(tag: 'work', probability: 0.9)],
        );
      };

      await useCase();

      expect(tagRepository.setTagsCalls, isEmpty);
    });

    test('autoTagEnabled false -> tag call is not made even with tags', () async {
      tagRepository.allTags = [workTag, healthTag];
      entryRepository.seedEntry(
        Entry(
          rawTranscript: 'meeting with my team',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs,
          wordCount: 4,
        ),
      );
      cleanupCallback = ({required transcript, required language}) async {
        return const backend.CleanupSuccess(cleanedText: 'Cleaned');
      };
      final disabledUseCase = RetryPendingDraftsUseCase(
        entryRepository: entryRepository,
        transcriptionService: transcriptionService,
        cleanupTranscriptUseCase: cleanupUseCase,
        validateDraftAudioPath: validateAudioPath,
        deleteRetainedAudio: deleteRetainedAudio,
        setRecordQuota: (quota) => currentQuota = quota,
        logWarning: (message, {error, stackTrace}) {
          logMessages.add(message);
          logErrors.add(error);
        },
        autoTagUseCase: AutoTagUseCase(
          tagRepository: tagRepository,
          logWarning: (message, {error, stackTrace}) {},
        ),
        tagText: ({required text, required tags}) {
          tagTextCalls.add(tags);
          return tagTextCallback(text: text, tags: tags);
        },
        tagRepository: tagRepository,
        autoTagEnabled: false,
      );

      await disabledUseCase();

      expect(tagTextCalls, isEmpty);
      expect(tagRepository.setTagsCalls, isEmpty);
    });

    test('fewer than 2 tags during retry -> tag call is not made', () async {
      tagRepository.allTags = [workTag];
      entryRepository.seedEntry(
        Entry(
          rawTranscript: 'meeting with my team',
          type: EntryType.draft,
          language: 'en-US',
          createdAt: currentTimeMs,
          wordCount: 4,
        ),
      );

      await useCase();

      expect(tagTextCalls, isEmpty);
      expect(tagRepository.setTagsCalls, isEmpty);
    });
  });
}

class _SetTagsCall {
  const _SetTagsCall(this.entryId, this.tagIds);

  final int entryId;
  final List<int> tagIds;
}

class _FakeTagRepository implements TagRepository {
  List<Tag> allTags = <Tag>[];
  List<Tag> entryTags = <Tag>[];
  final List<_SetTagsCall> setTagsCalls = <_SetTagsCall>[];

  @override
  Future<List<Tag>> getAllTags() async => allTags;

  @override
  Stream<List<Tag>> watchTagsForEntry(int entryId) =>
      Stream<List<Tag>>.value(entryTags);

  @override
  Future<List<Tag>> getTagsForEntry(int entryId) async => entryTags;

  @override
  Future<void> setTagsForEntry(int entryId, List<int> tagIds) async {
    setTagsCalls.add(_SetTagsCall(entryId, List<int>.of(tagIds)));
  }

  @override
  Stream<List<Tag>> watchAllTags() => throw UnimplementedError();

  @override
  Future<Map<int, int>> getTagCounts() => throw UnimplementedError();

  @override
  Future<Tag> createTag(String name) => throw UnimplementedError();

  @override
  Future<Tag?> findTagByName(String name) => throw UnimplementedError();

  @override
  Future<void> deleteTag(int id) => throw UnimplementedError();
}

Future<File> _writeAudioFile(Directory tempDirectory, String name) async {
  final file = File('${tempDirectory.path}/$name');
  await file.writeAsString('audio');
  return file;
}

class _FakeTranscriptionService implements TranscriptionService {
  final List<String> transcribedAudioPaths = <String>[];
  final List<TranscriptionResult> nextDraftResults = <TranscriptionResult>[];
  Future<TranscriptionResult> Function()? nextDraftResultFactory;
  TranscriptionResult nextDraftResult = const TranscriptionFailure(
    reason: TranscriptionFailureReason.apiError,
  );

  @override
  int? get hardCapDeadlineElapsedRealtime => null;

  @override
  bool get isRecording => false;

  @override
  bool get isTranscribing => false;

  @override
  Future<void> cancelLiveTranscription() async {}

  @override
  Future<void> startLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {}

  @override
  Future<TranscriptionResult> stopLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<TranscriptionResult> transcribeAudioDraft(String audioPath) async {
    transcribedAudioPaths.add(audioPath);
    final factory = nextDraftResultFactory;
    if (factory != null) {
      nextDraftResultFactory = null;
      return factory();
    }
    if (nextDraftResults.isNotEmpty) {
      return nextDraftResults.removeAt(0);
    }
    return nextDraftResult;
  }
}

class _FakeEntryRepository implements EntryRepository {
  _FakeEntryRepository(this._nowMs);

  final int Function() _nowMs;
  final Map<int, Entry> entries = <int, Entry>{};
  int _nextId = 1;
  int deleteStaleCalls = 0;

  int seedEntry(Entry entry) {
    final id = _nextId++;
    entries[id] = entry.copyWith(id: id);
    return id;
  }

  @override
  Future<void> deleteEntry(int id) async {
    entries.remove(id);
  }

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {
    deleteStaleCalls += 1;
    final cutoff = _nowMs() - Duration(days: daysOld).inMilliseconds;
    final staleIds = entries.values
        .where(
          (entry) => entry.type == EntryType.draft && entry.createdAt < cutoff,
        )
        .map((entry) => entry.id)
        .toList(growable: false);
    for (final id in staleIds) {
      final audioPath = entries[id]?.audioPath;
      entries.remove(id);
      if (audioPath != null && audioPath.trim().isNotEmpty) {
        final file = File(audioPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  @override
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) async {
    final existing = _requireEntry(id);
    entries[id] = existing.copyWith(
      rawTranscript: rawTranscript,
      cleanedText: cleanedText,
      wordCount: wordCount,
      type: EntryType.saved,
      clearAudioPath: true,
    );
  }

  @override
  Future<Entry?> getEntryById(int id) async => entries[id];

  @override
  Future<List<int>> importEntries(List<Entry> entries) async => const [];

  @override
  Future<List<Entry>> getPendingDrafts() async {
    final pending = entries.values
        .where((entry) => entry.type == EntryType.draft)
        .toList();
    pending.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return pending;
  }

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async {
    return seedEntry(
      Entry(
        rawTranscript: '',
        type: EntryType.draft,
        language: language,
        createdAt: _nowMs(),
        wordCount: 0,
        audioPath: audioPath,
      ),
    );
  }

  @override
  Future<int> saveDraft(String transcript, String language) async {
    return seedEntry(
      Entry(
        rawTranscript: transcript,
        type: EntryType.draft,
        language: language,
        createdAt: _nowMs(),
        wordCount: countWords(transcript),
      ),
    );
  }

  @override
  Future<int> saveEntry(String transcript, String language) async {
    return seedEntry(
      Entry(
        rawTranscript: transcript,
        type: EntryType.saved,
        language: language,
        createdAt: _nowMs(),
        wordCount: countWords(transcript),
      ),
    );
  }

  @override
  Future<void> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  ) async {
    final existing = _requireEntry(id);
    entries[id] = existing.copyWith(
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
    final existing = _requireEntry(id);
    entries[id] = existing.copyWith(
      rawTranscript: rawTranscript,
      wordCount: wordCount,
      language: language,
      clearAudioPath: true,
    );
  }

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {
    final existing = _requireEntry(id);
    entries[id] = existing.copyWith(
      cleanedText: cleanedText,
      wordCount: countWords(cleanedText),
    );
  }

  @override
  Future<void> updateEntryLanguage(int id, String language) async {
    final existing = _requireEntry(id);
    entries[id] = existing.copyWith(language: language);
  }

  @override
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) async {
    final existing = _requireEntry(id);
    entries[id] = existing.copyWith(
      cleanedText: cleanedText,
      wordCount: wordCount,
      type: EntryType.saved,
      clearAudioPath: true,
    );
  }

  Entry _requireEntry(int id) {
    final entry = entries[id];
    if (entry == null) {
      throw StateError('Entry with id $id not found or already deleted');
    }
    return entry;
  }

  @override
  Stream<List<Entry>> watchAllEntries() => throw UnimplementedError();

  @override
  Stream<Entry?> watchEntryById(int id) => throw UnimplementedError();
}
