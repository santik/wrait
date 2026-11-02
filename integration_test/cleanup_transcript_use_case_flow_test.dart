import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/usecase/cleanup_transcript_use_case.dart';

import '../test/test_doubles/fake_secure_storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'provider graph supports fresh cleanup success with entry finalization and quota updates',
    (tester) async {
      final harness = await _createHarness(
        cleanupCallback: ({required transcript, required language}) async {
          expect(transcript, 'raw transcript');
          expect(language, 'fr-FR');
          return backend.CleanupSuccess(
            cleanedText: 'Cleaned transcript.',
            quota: RecordQuotaState(
              limit: 5,
              count: 3,
              remaining: 2,
              resetAt: DateTime.utc(2026, 6, 12),
            ),
          );
        },
      );
      addTearDown(harness.dispose);

      final useCase = harness.container.read(cleanupTranscriptUseCaseProvider);
      final result = await useCase(
        rawTranscript: ' raw transcript ',
        language: 'fr_fr',
      );

      expect(
        result,
        isA<CleanupTranscriptSuccess>()
            .having((value) => value.entryId, 'entryId', 1)
            .having(
              (value) => value.cleanedText,
              'cleanedText',
              'Cleaned transcript.',
            ),
      );

      final entry = await harness.container
          .read(entryRepositoryProvider)
          .getEntryById(result.entryId!);
      expect(entry, isNotNull);
      expect(entry!.rawTranscript, ' raw transcript ');
      expect(entry.cleanedText, 'Cleaned transcript.');
      expect(entry.type, EntryType.saved);
      expect(entry.wordCount, 2);
      expect(entry.language, 'fr-FR');
      expect(
        harness.container.read(sessionRecordQuotaStateProvider)?.remaining,
        2,
      );
    },
  );

  testWidgets(
    'fresh cleanup failure persists a text draft and preserves the last valid quota when no quota is returned',
    (tester) async {
      final harness = await _createHarness(
        initialQuota: RecordQuotaState(
          limit: 5,
          count: 2,
          remaining: 3,
          resetAt: DateTime.utc(2026, 6, 11),
        ),
        cleanupCallback: ({required transcript, required language}) async {
          expect(language, cleanupTranscriptFallbackLanguage);
          return const backend.CleanupFailure(
            reason: backend.BackendFailureReason.backendUnavailable,
          );
        },
      );
      addTearDown(harness.dispose);

      final useCase = harness.container.read(cleanupTranscriptUseCaseProvider);
      final result = await useCase(
        rawTranscript: 'raw transcript',
        language: 'zz-ZZ',
      );

      expect(
        result,
        isA<CleanupTranscriptFailure>().having(
          (value) => value.reason,
          'reason',
          backend.BackendFailureReason.backendUnavailable,
        ),
      );

      final entry = await harness.container
          .read(entryRepositoryProvider)
          .getEntryById(result.entryId!);
      expect(entry, isNotNull);
      expect(entry!.rawTranscript, 'raw transcript');
      expect(entry.cleanedText, isNull);
      expect(entry.type, EntryType.draft);
      expect(entry.language, cleanupTranscriptFallbackLanguage);
      expect(
        harness.container.read(sessionRecordQuotaStateProvider)?.remaining,
        3,
      );
    },
  );

  testWidgets(
    'existing text draft retry reuses the same entry id and stored language when input language is missing',
    (tester) async {
      final harness = await _createHarness(
        cleanupCallback: ({required transcript, required language}) async {
          expect(transcript, 'updated transcript');
          expect(language, 'nl-NL');
          return const backend.CleanupSuccess(
            cleanedText: 'Opgeschoonde tekst',
          );
        },
      );
      addTearDown(harness.dispose);

      final repository = harness.container.read(entryRepositoryProvider);
      final entryId = await repository.saveDraft('old transcript', 'nl-NL');

      final useCase = harness.container.read(cleanupTranscriptUseCaseProvider);
      final result = await useCase(
        entryId: entryId,
        rawTranscript: 'updated transcript',
      );

      expect(
        result,
        isA<CleanupTranscriptSuccess>().having(
          (value) => value.entryId,
          'entryId',
          entryId,
        ),
      );

      final entry = await repository.getEntryById(entryId);
      expect(entry, isNotNull);
      expect(entry!.rawTranscript, 'updated transcript');
      expect(entry.cleanedText, 'Opgeschoonde tekst');
      expect(entry.type, EntryType.saved);
      expect(entry.language, 'nl-NL');
    },
  );

  testWidgets(
    'cleanup truncates only the request transcript while preserving the full stored raw transcript',
    (tester) async {
      final oversizedTranscript =
          ' ${'a' * (cleanupTranscriptMaxLength + 25)} ';
      late String capturedTranscript;
      late String capturedLanguage;
      final harness = await _createHarness(
        cleanupCallback: ({required transcript, required language}) async {
          capturedTranscript = transcript;
          capturedLanguage = language;
          return const backend.CleanupSuccess(cleanedText: 'Trimmed success');
        },
      );
      addTearDown(harness.dispose);

      final useCase = harness.container.read(cleanupTranscriptUseCaseProvider);
      final result = await useCase(rawTranscript: oversizedTranscript);

      expect(result, isA<CleanupTranscriptSuccess>());
      expect(capturedTranscript, hasLength(cleanupTranscriptMaxLength));
      expect(
        capturedTranscript,
        ('a' * (cleanupTranscriptMaxLength + 25)).substring(
          0,
          cleanupTranscriptMaxLength,
        ),
      );
      expect(capturedLanguage, cleanupTranscriptFallbackLanguage);

      final entry = await harness.container
          .read(entryRepositoryProvider)
          .getEntryById(result.entryId!);
      expect(entry, isNotNull);
      expect(entry!.rawTranscript, oversizedTranscript);
    },
  );

  testWidgets(
    'malformed cleanup failure still propagates valid quota and preserves the draft',
    (tester) async {
      final harness = await _createHarness(
        cleanupCallback: ({required transcript, required language}) async {
          return backend.CleanupFailure(
            reason: backend.BackendFailureReason.apiError,
            quota: RecordQuotaState(
              limit: 5,
              count: 4,
              remaining: 1,
              resetAt: DateTime.utc(2026, 6, 12),
            ),
          );
        },
      );
      addTearDown(harness.dispose);

      final useCase = harness.container.read(cleanupTranscriptUseCaseProvider);
      final result = await useCase(
        rawTranscript: 'raw transcript',
        language: 'en-US',
      );

      expect(
        result,
        isA<CleanupTranscriptFailure>()
            .having((value) => value.entryId, 'entryId', 1)
            .having((value) => value.quota?.remaining, 'quotaRemaining', 1)
            .having(
              (value) => value.reason,
              'reason',
              backend.BackendFailureReason.apiError,
            ),
      );

      final entry = await harness.container
          .read(entryRepositoryProvider)
          .getEntryById(result.entryId!);
      expect(entry, isNotNull);
      expect(entry!.type, EntryType.draft);
      expect(entry.cleanedText, isNull);
      expect(
        harness.container.read(sessionRecordQuotaStateProvider)?.remaining,
        1,
      );
    },
  );
}

class _Harness {
  _Harness({
    required this.container,
    required this.database,
    required this.tempDirectory,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory tempDirectory;

  Future<void> dispose() async {
    container.dispose();
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<_Harness> _createHarness({
  required CleanupTranscriptCallback cleanupCallback,
  RecordQuotaState? initialQuota,
}) async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'wrait-cleanup-int',
  );
  final database = await LocalEntryDatabase.open(
    keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(7)),
    databaseFile: File(
      '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
    ),
  );
  final container = ProviderContainer(
    overrides: [
      localEntryDatabaseProvider.overrideWithValue(database),
      cleanupTranscriptCallbackProvider.overrideWithValue(cleanupCallback),
    ],
  );

  if (initialQuota != null) {
    container
        .read(sessionRecordQuotaStateProvider.notifier)
        .setQuota(initialQuota);
  }

  return _Harness(
    container: container,
    database: database,
    tempDirectory: tempDirectory,
  );
}
