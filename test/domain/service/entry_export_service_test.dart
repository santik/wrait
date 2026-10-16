import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/entries/entry_export_file_writer.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/service/entry_export_service.dart';

void main() {
  test('exports saved and draft entries in newest-first input order', () async {
    final writer = _CapturingFileWriter();
    final service = EntryExportService(
      fileWriter: writer,
      now: () => DateTime.utc(2026, 6, 30, 10, 11, 12),
    );
    final entries = <Entry>[
      _entry(
        id: 7,
        type: EntryType.draft,
        createdAt: DateTime.utc(2026, 6, 30),
      ),
      _entry(
        id: 3,
        type: EntryType.saved,
        createdAt: DateTime.utc(2026, 6, 29),
      ),
    ];

    final result = await service.exportEntries(entries);

    expect(result.didExport, isTrue);
    expect(result.fileName, 'wrait-entries-20260630-101112.csv');
    expect(writer.lastFileName, 'wrait-entries-20260630-101112.csv');
    expect(
      writer.lastContents,
      startsWith(
        'type,created_at,language,word_count,raw_transcript,cleaned_text,tags\n',
      ),
    );
    final lines = writer.lastContents.trimRight().split('\n');
    expect(lines[1], startsWith('draft,'));
    expect(lines[2], startsWith('saved,'));
    expect(
      lines[1].split(',')[1],
      DateTime.utc(2026, 6, 30).millisecondsSinceEpoch.toString(),
    );
  });

  test('escapes commas, quotes, and newlines in CSV text fields', () {
    final csv = EntryExportService.buildCsv(<Entry>[
      Entry(
        id: 1,
        rawTranscript: 'line one,\n"line two"',
        cleanedText: 'clean, "quoted"',
        type: EntryType.saved,
        language: 'en-US',
        createdAt: DateTime.utc(2026, 6, 30, 8).millisecondsSinceEpoch,
        wordCount: 4,
        audioPath: '/tmp/secret-audio.m4a',
      ),
    ]);

    expect(csv, contains('"line one,\n""line two"""'));
    expect(csv, contains('"clean, ""quoted"""'));
  });

  test(
    'omits audio path data and uses empty cleaned-text values when absent',
    () {
      final csv = EntryExportService.buildCsv(<Entry>[
        Entry(
          id: 2,
          rawTranscript: '',
          cleanedText: null,
          type: EntryType.draft,
          language: 'fr-FR',
          createdAt: DateTime.utc(2026, 6, 30, 8).millisecondsSinceEpoch,
          wordCount: 0,
          audioPath: '/tmp/private-path.m4a',
        ),
      ]);

      expect(csv, isNot(contains('audioPath')));
      expect(csv, isNot(contains('/tmp/private-path.m4a')));
      expect(csv.trimRight().split('\n').last, endsWith(','));
    },
  );

  test('exports a header-only CSV when there are no entries', () async {
    final writer = _CapturingFileWriter();
    final service = EntryExportService(
      fileWriter: writer,
      now: () => DateTime.utc(2026, 6, 30, 12),
    );

    final result = await service.exportEntries(const <Entry>[]);

    expect(result.didExport, isTrue);
    expect(
      writer.lastContents,
      'type,created_at,language,word_count,raw_transcript,cleaned_text,tags\n',
    );
  });

  test('returns a failure result when the file writer throws', () async {
    final service = EntryExportService(
      fileWriter: _ThrowingFileWriter(),
      now: () => DateTime.utc(2026, 6, 30, 12),
    );
    final entries = <Entry>[_entry(id: 1)];

    final result = await service.exportEntries(entries);

    expect(result.didExport, isFalse);
    expect(result.error, isA<StateError>());
    expect(entries.single.audioPath, '/tmp/entry-1.m4a');
  });

  test('preserves Unicode content in CSV exports', () {
    final csv = EntryExportService.buildCsv(<Entry>[
      Entry(
        id: 4,
        rawTranscript: 'emoji 😀 and عربي and 日本語',
        cleanedText: 'עברית and accents éü',
        type: EntryType.saved,
        language: 'multilingual',
        createdAt: DateTime.utc(2026, 6, 30, 8).millisecondsSinceEpoch,
        wordCount: 6,
      ),
    ]);

    expect(csv, contains('emoji 😀 and عربي and 日本語'));
    expect(csv, contains('עברית and accents éü'));
  });

  test(
    'adds a suffix when multiple exports start in the same second',
    () async {
      final writer = _CapturingFileWriter();
      final service = EntryExportService(
        fileWriter: writer,
        now: () => DateTime.utc(2026, 6, 30, 10, 11, 12, 999),
      );

      final firstResult = await service.exportEntries(<Entry>[_entry(id: 1)]);
      final secondResult = await service.exportEntries(<Entry>[_entry(id: 2)]);

      expect(firstResult.fileName, 'wrait-entries-20260630-101112.csv');
      expect(secondResult.fileName, 'wrait-entries-20260630-101112-1.csv');
    },
  );
}

class _CapturingFileWriter implements EntryExportFileWriter {
  String lastFileName = '';
  String lastContents = '';

  @override
  Future<EntryExportFileWriteResult> writeCsvExport({
    required String fileName,
    required String contents,
  }) async {
    lastFileName = fileName;
    lastContents = contents;
    return EntryExportFileWriteResult(
      fileName: fileName,
      pathLabel: 'Downloads/Wrait',
    );
  }
}

class _ThrowingFileWriter implements EntryExportFileWriter {
  @override
  Future<EntryExportFileWriteResult> writeCsvExport({
    required String fileName,
    required String contents,
  }) async {
    throw StateError('write failed');
  }
}

Entry _entry({
  required int id,
  EntryType type = EntryType.saved,
  DateTime? createdAt,
}) {
  return Entry(
    id: id,
    rawTranscript: 'entry $id',
    cleanedText: 'clean entry $id',
    type: type,
    language: 'en-US',
    createdAt:
        (createdAt ?? DateTime.utc(2026, 6, 30, 9)).millisecondsSinceEpoch,
    wordCount: 3,
    audioPath: '/tmp/entry-$id.m4a',
  );
}
