import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/data/entries/tag_providers.dart';
import 'package:wrait/data/transcription/transcription_service.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/tag_repository.dart';
import 'package:wrait/domain/usecase/retry_pending_drafts_use_case.dart';

import '../test/test_doubles/fake_secure_storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'cleanup succeeds with auto-tag detection assigns matching tags to the finalized entry',
    (tester) async {
      final harness = await _createHarness(
        tagResult: const backend.TagTextSuccess(
          tags: [
            backend.TagProbabilityResult(tag: 'work', probability: 0.85),
            backend.TagProbabilityResult(tag: 'health', probability: 0.6),
            backend.TagProbabilityResult(tag: 'travel', probability: 0.3),
          ],
        ),
      );
      addTearDown(harness.dispose);

      await harness.createTags(['work', 'health', 'travel']);
      final entryId = await harness.entryRepository.saveDraft(
        'went to the office then the gym',
        'en-US',
      );

      await harness.runRetry();

      final entry = await harness.entryRepository.getEntryById(entryId);
      expect(entry, isNotNull);
      expect(entry!.type, EntryType.saved);
      expect(entry.cleanedText, 'Cleaned transcript.');

      expect(harness.tagCalls, hasLength(1));
      expect(harness.tagCalls.single.text, 'went to the office then the gym');
      expect(
        harness.tagCalls.single.tags,
        unorderedEquals(['work', 'health', 'travel']),
      );

      expect(await harness.tagNamesForEntry(entryId), {'work', 'health'});
    },
  );

  testWidgets(
    'auto-tag merges with manually assigned tags without removing them',
    (tester) async {
      final harness = await _createHarness(
        tagResult: const backend.TagTextSuccess(
          tags: [backend.TagProbabilityResult(tag: 'work', probability: 0.8)],
        ),
      );
      addTearDown(harness.dispose);

      final tags = await harness.createTags(['work', 'health', 'travel']);
      final entryId = await harness.entryRepository.saveDraft(
        'booked a flight for the conference',
        'en-US',
      );
      await harness.tagRepository.setTagsForEntry(entryId, [tags['travel']!]);
      expect(await harness.tagNamesForEntry(entryId), {'travel'});

      await harness.runRetry();

      final entry = await harness.entryRepository.getEntryById(entryId);
      expect(entry, isNotNull);
      expect(entry!.type, EntryType.saved);
      expect(await harness.tagNamesForEntry(entryId), {'travel', 'work'});
    },
  );

  testWidgets('auto-tag failure does not affect entry finalization', (
    tester,
  ) async {
    final harness = await _createHarness(
      tagResult: const backend.TagTextFailure(
        reason: backend.BackendFailureReason.apiError,
      ),
    );
    addTearDown(harness.dispose);

    await harness.createTags(['work', 'health']);
    final entryId = await harness.entryRepository.saveDraft(
      'a regular day',
      'en-US',
    );

    await harness.runRetry();

    final entry = await harness.entryRepository.getEntryById(entryId);
    expect(entry, isNotNull);
    expect(entry!.type, EntryType.saved);
    expect(entry.cleanedText, 'Cleaned transcript.');
    expect(harness.tagCalls, hasLength(1));
    expect(await harness.tagNamesForEntry(entryId), isEmpty);
  });

  testWidgets('fewer than 2 tags skips auto-tag call entirely', (tester) async {
    final harness = await _createHarness(
      tagResult: const backend.TagTextSuccess(
        tags: [backend.TagProbabilityResult(tag: 'work', probability: 0.9)],
      ),
    );
    addTearDown(harness.dispose);

    await harness.createTags(['work']);
    final entryId = await harness.entryRepository.saveDraft(
      'busy day at work',
      'en-US',
    );

    await harness.runRetry();

    final entry = await harness.entryRepository.getEntryById(entryId);
    expect(entry, isNotNull);
    expect(entry!.type, EntryType.saved);
    expect(harness.tagCalls, isEmpty);
    expect(await harness.tagNamesForEntry(entryId), isEmpty);
  });
}

class _TagCall {
  _TagCall(this.text, this.tags);

  final String text;
  final List<String> tags;
}

/// Text drafts never touch the transcription service during retry.
class _UnusedTranscriptionService implements TranscriptionService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _Harness {
  _Harness({
    required this.container,
    required this.database,
    required this.tempDirectory,
    required this.tagCalls,
    required this.warnings,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory tempDirectory;
  final List<_TagCall> tagCalls;
  final List<String> warnings;

  EntryRepository get entryRepository =>
      container.read(entryRepositoryProvider);
  TagRepository get tagRepository => container.read(tagRepositoryProvider);

  /// Builds the retry use case with the auto-tag collaborators wired through
  /// the provider graph. [retryPendingDraftsUseCaseProvider] resolves its tag
  /// callback from the real backend client, so the use case is assembled here
  /// with the overridden [tagTextCallbackProvider] instead.
  Future<void> runRetry() => RetryPendingDraftsUseCase(
    entryRepository: container.read(entryRepositoryProvider),
    transcriptionService: _UnusedTranscriptionService(),
    cleanupTranscriptUseCase: container.read(cleanupTranscriptUseCaseProvider),
    validateDraftAudioPath: (path) async => null,
    deleteRetainedAudio: (path) async {},
    setRecordQuota: (_) {},
    logWarning: (message, {error, stackTrace}) => warnings.add(message),
    autoTagUseCase: container.read(autoTagUseCaseProvider),
    tagText: ({required text, required tags}) =>
        container.read(tagTextCallbackProvider)(text: text, tags: tags),
    tagRepository: container.read(tagRepositoryProvider),
  )();

  /// Creates tags and returns a name -> id map.
  Future<Map<String, int>> createTags(List<String> names) async {
    final ids = <String, int>{};
    for (final name in names) {
      final tag = await container.read(tagRepositoryProvider).createTag(name);
      ids[name] = tag.id;
    }
    return ids;
  }

  Future<Set<String>> tagNamesForEntry(int entryId) async {
    final tags = await container
        .read(tagRepositoryProvider)
        .watchTagsForEntry(entryId)
        .first;
    return tags.map((tag) => tag.name).toSet();
  }

  Future<void> dispose() async {
    container.dispose();
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<_Harness> _createHarness({
  required backend.TagTextResult tagResult,
}) async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'wrait-auto-tag-int',
  );
  final database = await LocalEntryDatabase.open(
    keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(7)),
    databaseFile: File(
      '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
    ),
  );
  final tagCalls = <_TagCall>[];
  final container = ProviderContainer(
    overrides: [
      localEntryDatabaseProvider.overrideWithValue(database),
      cleanupTranscriptCallbackProvider.overrideWithValue(({
        required transcript,
        required language,
      }) async {
        return const backend.CleanupSuccess(cleanedText: 'Cleaned transcript.');
      }),
      tagTextCallbackProvider.overrideWithValue(({
        required String text,
        required List<String> tags,
      }) async {
        tagCalls.add(_TagCall(text, List.of(tags)));
        return tagResult;
      }),
    ],
  );

  return _Harness(
    container: container,
    database: database,
    tempDirectory: tempDirectory,
    tagCalls: tagCalls,
    warnings: [],
  );
}
