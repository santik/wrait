import 'package:flutter/services.dart';

class EntryExportFileWriteResult {
  const EntryExportFileWriteResult({
    required this.fileName,
    required this.pathLabel,
  });

  final String fileName;
  final String pathLabel;
}

abstract interface class EntryExportFileWriter {
  Future<EntryExportFileWriteResult> writeCsvExport({
    required String fileName,
    required String contents,
  });
}

class EntryExportFileWriterException implements Exception {
  const EntryExportFileWriterException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return 'EntryExportFileWriterException: $message';
    }
    return 'EntryExportFileWriterException: $message Cause: $cause';
  }
}

class MethodChannelEntryExportFileWriter implements EntryExportFileWriter {
  const MethodChannelEntryExportFileWriter({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'wrait/entry_export';
  static const String writeCsvExportMethod = 'writeCsvExport';

  final MethodChannel _channel;

  @override
  Future<EntryExportFileWriteResult> writeCsvExport({
    required String fileName,
    required String contents,
  }) async {
    final normalizedRequestFileName = fileName.trim();
    if (normalizedRequestFileName.isEmpty) {
      throw const EntryExportFileWriterException(
        'Entry export writer requires a non-empty file name.',
      );
    }
    if (contents.isEmpty) {
      throw const EntryExportFileWriterException(
        'Entry export writer requires non-empty CSV contents.',
      );
    }

    Map<String, Object?>? response;
    try {
      response = await _channel.invokeMapMethod<String, Object?>(
        writeCsvExportMethod,
        <String, Object?>{
          'fileName': normalizedRequestFileName,
          'contents': contents,
        },
      );
    } on PlatformException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        EntryExportFileWriterException(
          'Platform export failed with code=${error.code}, '
          'message=${error.message ?? 'n/a'}, details=${error.details ?? 'n/a'}.',
          cause: error,
        ),
        stackTrace,
      );
    }

    if (response == null) {
      throw const EntryExportFileWriterException(
        'Entry export writer returned no response.',
      );
    }

    final rawFileName = response['fileName'];
    final rawPathLabel = response['pathLabel'];
    if (rawFileName is! String || rawPathLabel is! String) {
      throw EntryExportFileWriterException(
        'Entry export writer returned invalid response types: '
        'fileName=${rawFileName.runtimeType}, '
        'pathLabel=${rawPathLabel.runtimeType}.',
      );
    }

    final normalizedFileName = rawFileName.trim();
    final normalizedPathLabel = rawPathLabel.trim();
    if (normalizedFileName.isEmpty || normalizedPathLabel.isEmpty) {
      throw const EntryExportFileWriterException(
        'Entry export writer returned blank response values.',
      );
    }

    return EntryExportFileWriteResult(
      fileName: normalizedFileName,
      pathLabel: normalizedPathLabel,
    );
  }
}
