import '../../data/entries/entry_export_file_writer.dart';
import '../model/entry.dart';

class EntryExportResult {
  const EntryExportResult.success({
    required this.fileName,
    required this.pathLabel,
  }) : didExport = true,
       error = null,
       stackTrace = null;

  const EntryExportResult.failure({this.error, this.stackTrace})
    : didExport = false,
      fileName = null,
      pathLabel = null;

  final bool didExport;
  final String? fileName;
  final String? pathLabel;
  final Object? error;
  final StackTrace? stackTrace;
}

class EntryExportService {
  EntryExportService({required this._fileWriter, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  // Keep the header order aligned with the approved CSV contract so exported
  // files stay predictable for spreadsheet import and validation.
  static const List<String> csvHeaders = <String>[
    'type',
    'created_at',
    'language',
    'word_count',
    'raw_transcript',
    'cleaned_text',
    'tags',
  ];

  final EntryExportFileWriter _fileWriter;
  final DateTime Function() _now;
  int? _lastFileNameSecondUtc;
  int _lastFileNameCollisionCount = 0;

  Future<EntryExportResult> exportEntries(List<Entry> entries) async {
    final timestamp = _now();
    final timestampUtc = timestamp.isUtc ? timestamp : timestamp.toUtc();
    final fileName = _buildNextFileName(timestampUtc);
    final contents = buildCsv(entries);

    try {
      final writeResult = await _fileWriter.writeCsvExport(
        fileName: fileName,
        contents: contents,
      );
      return EntryExportResult.success(
        fileName: writeResult.fileName,
        pathLabel: writeResult.pathLabel,
      );
    } catch (error, stackTrace) {
      return EntryExportResult.failure(error: error, stackTrace: stackTrace);
    }
  }

  static String buildFileName(
    DateTime timestampUtc, {
    int collisionSequence = 0,
  }) {
    final year = timestampUtc.year.toString().padLeft(4, '0');
    final month = timestampUtc.month.toString().padLeft(2, '0');
    final day = timestampUtc.day.toString().padLeft(2, '0');
    final hour = timestampUtc.hour.toString().padLeft(2, '0');
    final minute = timestampUtc.minute.toString().padLeft(2, '0');
    final second = timestampUtc.second.toString().padLeft(2, '0');
    final suffix = collisionSequence == 0 ? '' : '-$collisionSequence';
    return 'wrait-entries-$year$month$day-$hour$minute$second$suffix.csv';
  }

  static String buildCsv(List<Entry> entries) {
    final buffer = StringBuffer()..writeln(csvHeaders.join(','));

    // Export the user-visible entry record and metadata while intentionally
    // omitting retained draft audio paths and other app-private storage details.
    for (final entry in entries) {
      buffer.writeln(
        <String>[
          _escapeCsv(entry.type.name),
          entry.createdAt.toString(),
          _escapeCsv(entry.language),
          entry.wordCount.toString(),
          _escapeCsv(entry.rawTranscript),
          _escapeCsv(entry.cleanedText ?? ''),
          _escapeCsv(entry.tags.map((tag) => tag.name).join(';')),
        ].join(','),
      );
    }

    return buffer.toString();
  }

  static String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _buildNextFileName(DateTime timestampUtc) {
    final currentSecondUtc = timestampUtc.millisecondsSinceEpoch ~/ 1000;
    if (_lastFileNameSecondUtc == currentSecondUtc) {
      _lastFileNameCollisionCount += 1;
    } else {
      _lastFileNameSecondUtc = currentSecondUtc;
      _lastFileNameCollisionCount = 0;
    }

    return buildFileName(
      timestampUtc,
      collisionSequence: _lastFileNameCollisionCount,
    );
  }
}
