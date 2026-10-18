import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/entries/entry_import_file_reader.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/model/tag.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/tag_repository.dart';
import 'package:wrait/domain/service/entry_export_service.dart';
import 'package:wrait/domain/service/entry_import_service.dart';

void main() {
  test('imports saved and draft rows from a Wrait CSV export', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(
          fileName: 'wrait-import.csv',
          contents: _validCsv(),
        ),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isTrue);
    expect(result.importedCount, 2);
    expect(result.fileName, 'wrait-import.csv');
    expect(repository.importedEntries, hasLength(2));
    expect(repository.importedEntries.first.id, 0);
    expect(
      repository.importedEntries.first.rawTranscript,
      'line one,\n"quoted" two',
    );
    expect(repository.importedEntries.first.cleanedText, 'emoji 😀 and عربي');
    expect(repository.importedEntries.first.type, EntryType.saved);
    expect(repository.importedEntries.first.language, 'en-US');
    expect(repository.importedEntries.last.type, EntryType.draft);
    expect(repository.importedEntries.last.cleanedText, isNull);
  });

  test('imports a header-only Wrait CSV as zero records', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(
          fileName: 'empty.csv',
          contents: EntryExportService.buildCsv(const <Entry>[]),
        ),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isTrue);
    expect(result.importedCount, 0);
    expect(repository.importCallCount, 1);
    expect(repository.importedEntries, isEmpty);
  });

  test('re-importing the same valid CSV stays additive', () async {
    final repository = _FakeEntryRepository();
    final csv = EntryExportService.buildCsv(<Entry>[
      Entry(
        id: 9,
        rawTranscript: 'repeat me',
        cleanedText: null,
        type: EntryType.saved,
        language: 'en-US',
        createdAt: DateTime.utc(2026, 6, 30, 7).millisecondsSinceEpoch,
        wordCount: 2,
      ),
    ]);
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(fileName: 'repeat.csv', contents: csv),
      ),
      entryRepository: repository,
    );

    final firstResult = await service.importEntries();
    final secondResult = await service.importEntries();

    expect(firstResult.didImport, isTrue);
    expect(secondResult.didImport, isTrue);
    expect(repository.importCallCount, 2);
    expect(repository.importedEntries, hasLength(2));
  });

  test('accepts a UTF-8 BOM on the header row', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(
          fileName: 'bom.csv',
          contents:
              '\ufeff${EntryExportService.buildCsv(<Entry>[_entry(id: 1)])}',
        ),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isTrue);
    expect(result.importedCount, 1);
    expect(repository.importCallCount, 1);
  });

  test('accepts CR-only line endings', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(
          fileName: 'cr.csv',
          contents: EntryExportService.buildCsv(<Entry>[
            _entry(id: 1),
          ]).replaceAll('\n', '\r'),
        ),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isTrue);
    expect(result.importedCount, 1);
    expect(repository.importCallCount, 1);
  });

  test('returns cancelled when the picker is dismissed', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: const _StaticImportFileReader(null),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.wasCancelled, isTrue);
    expect(result.didImport, isFalse);
    expect(repository.importCallCount, 0);
  });

  test(
    'fails without repository mutation when the header is invalid',
    () async {
      final repository = _FakeEntryRepository();
      final service = EntryImportService(
        fileReader: const _StaticImportFileReader(
          EntryImportFileReadResult(
            fileName: 'bad.csv',
            contents: 'wrong,header\n1,2\n',
          ),
        ),
        entryRepository: repository,
      );

      final result = await service.importEntries();

      expect(result.didImport, isFalse);
      expect(result.failureCategory, EntryImportFailureCategory.invalidFormat);
      expect(result.error, isA<FormatException>());
      expect(repository.importCallCount, 0);
    },
  );

  test('fails without repository mutation when a row is malformed', () async {
    final repository = _FakeEntryRepository();
    final validCsv = EntryExportService.buildCsv(<Entry>[
      _entry(id: 3, rawTranscript: 'hello world', cleanedText: 'clean'),
    ]);
    final malformedCsv = validCsv.replaceFirst(
      ',2,hello world,clean',
      ',-2,hello world,clean',
    );
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(
          fileName: 'bad-word-count.csv',
          contents: malformedCsv,
        ),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isFalse);
    expect(result.failureCategory, EntryImportFailureCategory.invalidFormat);
    expect(result.error, isA<FormatException>());
    expect(repository.importCallCount, 0);
  });

  test(
    'fails without repository mutation when created_at is invalid',
    () async {
      final repository = _FakeEntryRepository();
      final csv = [
        'type,created_at,language,word_count,raw_transcript,cleaned_text',
        'saved,not-a-number,en-US,2,hello,clean',
      ].join('\n');
      final service = EntryImportService(
        fileReader: _StaticImportFileReader(
          EntryImportFileReadResult(fileName: 'bad-time.csv', contents: csv),
        ),
        entryRepository: repository,
      );

      final result = await service.importEntries();

      expect(result.didImport, isFalse);
      expect(result.failureCategory, EntryImportFailureCategory.invalidFormat);
      expect(result.error, isA<FormatException>());
      expect(
        (result.error as FormatException).message,
        'Entry import CSV created_at must be an integer.',
      );
      expect(repository.importCallCount, 0);
    },
  );

  test('accepts a zero created_at timestamp', () async {
    final repository = _FakeEntryRepository();
    final csv = [
      'type,created_at,language,word_count,raw_transcript,cleaned_text',
      'saved,0,en-US,2,hello,clean',
    ].join('\n');
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(fileName: 'zero-time.csv', contents: csv),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isTrue);
    expect(result.importedCount, 1);
    expect(repository.importCallCount, 1);
    expect(repository.importedEntries.single.createdAt, 0);
  });

  test('accepts the maximum supported created_at timestamp', () async {
    final repository = _FakeEntryRepository();
    final csv = [
      'type,created_at,language,word_count,raw_transcript,cleaned_text',
      'saved,${EntryImportService.maxCreatedAtEpochMs},en-US,2,hello,clean',
    ].join('\n');
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(fileName: 'max-time.csv', contents: csv),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isTrue);
    expect(result.importedCount, 1);
    expect(repository.importCallCount, 1);
    expect(
      repository.importedEntries.single.createdAt,
      EntryImportService.maxCreatedAtEpochMs,
    );
  });

  test(
    'fails without repository mutation when created_at exceeds the supported maximum',
    () async {
      final repository = _FakeEntryRepository();
      final csv = [
        'type,created_at,language,word_count,raw_transcript,cleaned_text',
        'saved,${EntryImportService.maxCreatedAtEpochMs + 1},en-US,2,hello,clean',
      ].join('\n');
      final service = EntryImportService(
        fileReader: _StaticImportFileReader(
          EntryImportFileReadResult(fileName: 'future-time.csv', contents: csv),
        ),
        entryRepository: repository,
      );

      final result = await service.importEntries();

      expect(result.didImport, isFalse);
      expect(result.failureCategory, EntryImportFailureCategory.invalidFormat);
      expect(result.error, isA<FormatException>());
      expect(
        (result.error as FormatException).message,
        'Entry import CSV created_at exceeds the maximum supported timestamp.',
      );
      expect(repository.importCallCount, 0);
    },
  );

  test('fails without repository mutation when created_at is empty', () async {
    final repository = _FakeEntryRepository();
    final csv = [
      'type,created_at,language,word_count,raw_transcript,cleaned_text',
      'saved,,en-US,2,hello,clean',
    ].join('\n');
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(fileName: 'empty-time.csv', contents: csv),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isFalse);
    expect(result.failureCategory, EntryImportFailureCategory.invalidFormat);
    expect(result.error, isA<FormatException>());
    expect(
      (result.error as FormatException).message,
      'Entry import CSV created_at cannot be empty.',
    );
    expect(repository.importCallCount, 0);
  });

  test('rejects the older Wrait CSV header shape', () async {
    final repository = _FakeEntryRepository();
    final csv = [
      'id,type,created_at,created_at_epoch_ms,language,word_count,raw_transcript,cleaned_text',
      '1,saved,1719748800000,1719748800000,en-US,2,hello,clean',
    ].join('\n');
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(fileName: 'old-shape.csv', contents: csv),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isFalse);
    expect(result.failureCategory, EntryImportFailureCategory.invalidFormat);
    expect(result.error, isA<FormatException>());
    expect(repository.importCallCount, 0);
  });

  test('rejects rows with extra columns beyond the header', () async {
    final repository = _FakeEntryRepository();
    final csv = [
      'type,created_at,language,word_count,raw_transcript,cleaned_text',
      'saved,1719748800000,en-US,2,hello,clean,extra-column',
    ].join('\n');
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(fileName: 'extra-column.csv', contents: csv),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isFalse);
    expect(result.failureCategory, EntryImportFailureCategory.invalidFormat);
    expect(result.error, isA<FormatException>());
    expect(repository.importCallCount, 0);
  });

  test('fails when the CSV exceeds the configured file size limit', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(
          fileName: 'large.csv',
          contents: '${EntryExportService.csvHeaders.join(',')}\n1234567890',
        ),
      ),
      entryRepository: repository,
      maxImportBytes: 8,
    );

    final result = await service.importEntries();

    expect(result.didImport, isFalse);
    expect(result.failureCategory, EntryImportFailureCategory.fileTooLarge);
    expect(result.error, isA<EntryImportTooLargeException>());
    expect(repository.importCallCount, 0);
  });

  test(
    'fails when a transcript field exceeds the configured size limit',
    () async {
      final repository = _FakeEntryRepository();
      final largeTranscript = 'é' * 6;
      final service = EntryImportService(
        fileReader: _StaticImportFileReader(
          EntryImportFileReadResult(
            fileName: 'field-limit.csv',
            contents: EntryExportService.buildCsv(<Entry>[
              _entry(id: 1, rawTranscript: largeTranscript),
            ]),
          ),
        ),
        entryRepository: repository,
        maxTextFieldBytes: 8,
      );

      final result = await service.importEntries();

      expect(result.didImport, isFalse);
      expect(result.failureCategory, EntryImportFailureCategory.fileTooLarge);
      expect(result.error, isA<EntryImportTooLargeException>());
      expect(repository.importCallCount, 0);
    },
  );

  test('maps native file-too-large failures to the size category', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: const _ThrowingImportFileReader(
        EntryImportFileReaderException(
          'too large',
          code: MethodChannelEntryImportFileReader.fileTooLargeErrorCode,
        ),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isFalse);
    expect(result.failureCategory, EntryImportFailureCategory.fileTooLarge);
    expect(repository.importCallCount, 0);
  });

  test('maps unreadable file-reader failures to the file category', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: const _ThrowingImportFileReader(
        EntryImportFileReaderException('read failed'),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isFalse);
    expect(result.failureCategory, EntryImportFailureCategory.unreadableFile);
    expect(repository.importCallCount, 0);
  });

  test('imports CSV with tags and assigns them to entries', () async {
    final repository = _FakeEntryRepository();
    final tagRepository = _FakeTagRepository();
    final csv = _csvWithTags();
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(fileName: 'tags.csv', contents: csv),
      ),
      entryRepository: repository,
      tagRepository: tagRepository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isTrue);
    expect(result.importedCount, 2);
    expect(tagRepository.createdTagNames, containsAll(['work', 'travel']));
    expect(tagRepository.assignedTags[1], isNotNull);
    expect(tagRepository.assignedTags[2], isNotNull);
  });

  test('imports CSV without tags column (backward compatibility)', () async {
    final repository = _FakeEntryRepository();
    final tagRepository = _FakeTagRepository();
    final csv = _legacyCsv();
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(fileName: 'legacy.csv', contents: csv),
      ),
      entryRepository: repository,
      tagRepository: tagRepository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isTrue);
    expect(result.importedCount, 1);
    expect(tagRepository.createdTagNames, isEmpty);
    expect(tagRepository.assignedTags, isEmpty);
  });

  test('auto-creates missing tags and reuses existing ones on import',
      () async {
    final repository = _FakeEntryRepository();
    final tagRepository = _FakeTagRepository()
      ..seedTag(const Tag(id: 99, name: 'work'));
    final csv = _csvWithTags();
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(fileName: 'tags.csv', contents: csv),
      ),
      entryRepository: repository,
      tagRepository: tagRepository,
    );

    await service.importEntries();

    // 'work' already existed, only 'travel' should be created.
    expect(tagRepository.createdTagNames, ['travel']);
    // First entry has 'work;travel', second has 'work'.
    expect(tagRepository.assignedTags[1], containsAll([99]));
    expect(tagRepository.assignedTags[2], contains(99));
  });

  test('skips tags exceeding the system limit on import', () async {
    final repository = _FakeEntryRepository();
    final tagRepository = _FakeTagRepository(
      throwOnCreateAfter: TagRepository.maxTags,
    );
    // Pre-fill to the limit.
    for (var i = 0; i < TagRepository.maxTags; i++) {
      tagRepository.seedTag(Tag(id: i + 1, name: 'pre$i'));
    }

    final csv = _csvWithNewTag('overflow');
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(fileName: 'full.csv', contents: csv),
      ),
      entryRepository: repository,
      tagRepository: tagRepository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isTrue);
    expect(tagRepository.createdTagNames, isEmpty);
  });

  test('skips invalid tag names during import without failing', () async {
    final repository = _FakeEntryRepository();
    final tagRepository = _FakeTagRepository(
      rejectTagNamesLongerThan: TagRepository.maxTagNameLength,
    );
    final longName = 'a' * (TagRepository.maxTagNameLength + 1);
    final csv = _csvWithNewTag(longName);
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(fileName: 'invalid.csv', contents: csv),
      ),
      entryRepository: repository,
      tagRepository: tagRepository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isTrue);
    expect(tagRepository.createdTagNames, isEmpty);
  });

  test('handles whitespace in tag names during import', () async {
    final parsed = EntryImportService.parseCsv(
      'type,created_at,language,word_count,raw_transcript,cleaned_text,tags\n'
      'saved,1700000000000,en,2,text,clean, work ; travel \n',
    );
    expect(parsed.first.tagNames, ['work', 'travel']);
  });

  test('maps repository failures to the storage category', () async {
    final repository = _FakeEntryRepository(throwOnImport: true);
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(
          fileName: 'storage.csv',
          contents: EntryExportService.buildCsv(<Entry>[_entry(id: 1)]),
        ),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isFalse);
    expect(result.failureCategory, EntryImportFailureCategory.storageFailure);
    expect(result.error, isA<StateError>());
    expect(repository.importCallCount, 1);
  });
}

class _StaticImportFileReader implements EntryImportFileReader {
  const _StaticImportFileReader(this.result);

  final EntryImportFileReadResult? result;

  @override
  Future<EntryImportFileReadResult?> pickCsvImport() async => result;
}

class _ThrowingImportFileReader implements EntryImportFileReader {
  const _ThrowingImportFileReader(this.error);

  final Object error;

  @override
  Future<EntryImportFileReadResult?> pickCsvImport() async {
    throw error;
  }
}

class _FakeEntryRepository implements EntryRepository {
  _FakeEntryRepository({this.throwOnImport = false});

  final bool throwOnImport;
  final List<Entry> importedEntries = <Entry>[];
  int importCallCount = 0;

  @override
  Future<List<int>> importEntries(List<Entry> entries) async {
    importCallCount += 1;
    if (throwOnImport) {
      throw StateError('save failed');
    }
    importedEntries.addAll(entries);
    return List.generate(entries.length, (i) => _nextId + i);
  }

  int _nextId = 1;

  @override
  Stream<List<Entry>> watchAllEntries() => const Stream<List<Entry>>.empty();

  @override
  Stream<Entry?> watchEntryById(int id) => const Stream<Entry?>.empty();

  @override
  Future<Entry?> getEntryById(int id) async => null;

  @override
  Future<int> saveDraft(String transcript, String language) async => 1;

  @override
  Future<int> saveEntry(String transcript, String language) async => 1;

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async => 1;

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {}

  @override
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<void> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  ) async {}

  @override
  Future<void> updateDraftTranscriptAndLanguage(
    int id,
    String rawTranscript,
    int wordCount,
    String language,
  ) async {}

  @override
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<void> updateEntryLanguage(int id, String language) async {}

  @override
  Future<List<Entry>> getPendingDrafts() async => const <Entry>[];

  @override
  Future<void> deleteEntry(int id) async {}

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}
}

Entry _entry({
  required int id,
  String rawTranscript = 'imported entry',
  String? cleanedText,
}) {
  return Entry(
    id: id,
    rawTranscript: rawTranscript,
    cleanedText: cleanedText,
    type: EntryType.saved,
    language: 'en-US',
    createdAt: DateTime.utc(2026, 6, 30, 12, 34, 56).millisecondsSinceEpoch,
    wordCount: 2,
  );
}

class _FakeTagRepository implements TagRepository {
  _FakeTagRepository({
    this.throwOnCreateAfter,
    this.rejectTagNamesLongerThan,
  });

  final int? throwOnCreateAfter;
  final int? rejectTagNamesLongerThan;
  final List<Tag> _tags = [];
  int _nextId = 100;
  final List<String> createdTagNames = [];
  final Map<int, List<int>> assignedTags = {};

  void seedTag(Tag tag) {
    _tags.add(tag);
  }

  @override
  Future<Tag> createTag(String name) async {
    final trimmed = name.trim();
    if (rejectTagNamesLongerThan != null &&
        trimmed.length > rejectTagNamesLongerThan!) {
      throw ArgumentError('Tag name too long');
    }
    if (throwOnCreateAfter != null && _tags.length >= throwOnCreateAfter!) {
      throw StateError('Tag limit reached');
    }
    final tag = Tag(id: _nextId++, name: trimmed);
    _tags.add(tag);
    createdTagNames.add(trimmed);
    return tag;
  }

  @override
  Future<Tag?> findTagByName(String name) async {
    final trimmed = name.trim().toLowerCase();
    for (final tag in _tags) {
      if (tag.name.toLowerCase() == trimmed) return tag;
    }
    return null;
  }

  @override
  Future<void> deleteTag(int id) async {
    _tags.removeWhere((t) => t.id == id);
  }

  @override
  Future<List<Tag>> getAllTags() async => List.unmodifiable(_tags);

  @override
  Future<Map<int, int>> getTagCounts() async => {};

  @override
  Future<void> setTagsForEntry(int entryId, List<int> tagIds) async {
    assignedTags[entryId] = tagIds;
  }

  @override
  Stream<List<Tag>> watchAllTags() => Stream.value(List.unmodifiable(_tags));

  @override
  Stream<List<Tag>> watchTagsForEntry(int entryId) =>
      const Stream<List<Tag>>.empty();

  @override
  Future<List<Tag>> getTagsForEntry(int entryId) async => const <Tag>[];
}

String _csvWithTags() {
  return 'type,created_at,language,word_count,raw_transcript,cleaned_text,tags\n'
      'saved,1700000000000,en,2,hello,Hello.,work;travel\n'
      'saved,1700000100000,en,3,world,World.,work\n';
}

String _legacyCsv() {
  return 'type,created_at,language,word_count,raw_transcript,cleaned_text\n'
      'saved,1700000000000,en,2,hello,Hello.\n';
}

String _csvWithNewTag(String tagName) {
  return 'type,created_at,language,word_count,raw_transcript,cleaned_text,tags\n'
      'saved,1700000000000,en,2,hello,Hello.,$tagName\n';
}

String _validCsv() {
  return EntryExportService.buildCsv(<Entry>[
    Entry(
      id: 41,
      rawTranscript: 'line one,\n"quoted" two',
      cleanedText: 'emoji 😀 and عربي',
      type: EntryType.saved,
      language: 'en-US',
      createdAt: DateTime.utc(2026, 6, 30, 12, 34, 56).millisecondsSinceEpoch,
      wordCount: 5,
    ),
    Entry(
      id: 42,
      rawTranscript: 'draft import',
      cleanedText: null,
      type: EntryType.draft,
      language: 'fr-FR',
      createdAt: DateTime.utc(2026, 6, 29, 8).millisecondsSinceEpoch,
      wordCount: 2,
    ),
  ]);
}
