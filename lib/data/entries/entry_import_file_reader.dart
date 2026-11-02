import 'package:flutter/services.dart';

class EntryImportFileReadResult {
  const EntryImportFileReadResult({
    required this.fileName,
    required this.contents,
  });

  final String fileName;
  final String contents;
}

abstract interface class EntryImportFileReader {
  Future<EntryImportFileReadResult?> pickCsvImport();
}

class EntryImportFileReaderException implements Exception {
  const EntryImportFileReaderException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return 'EntryImportFileReaderException: $message';
    }
    return 'EntryImportFileReaderException: $message Cause: $cause';
  }
}

class MethodChannelEntryImportFileReader implements EntryImportFileReader {
  const MethodChannelEntryImportFileReader({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'wrait/entry_import';
  static const String pickCsvImportMethod = 'pickCsvImport';
  static const String fileTooLargeErrorCode = 'entry-import-file-too-large';
  static const String invalidResponseErrorCode =
      'entry-import-invalid-response';

  final MethodChannel _channel;

  @override
  Future<EntryImportFileReadResult?> pickCsvImport() async {
    Map<String, Object?>? response;
    try {
      response = await _channel.invokeMapMethod<String, Object?>(
        pickCsvImportMethod,
      );
    } on PlatformException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        EntryImportFileReaderException(
          'Platform import failed with code=${error.code}, '
          'message=${error.message ?? 'n/a'}, details=${error.details ?? 'n/a'}.',
          code: error.code,
          cause: error,
        ),
        stackTrace,
      );
    }

    if (response == null) {
      return null;
    }

    final rawFileName = response['fileName'];
    final rawContents = response['contents'];
    if (rawFileName is! String || rawContents is! String) {
      throw EntryImportFileReaderException(
        'Entry import reader returned invalid response types: '
        'fileName=${rawFileName.runtimeType}, '
        'contents=${rawContents.runtimeType}.',
        code: invalidResponseErrorCode,
      );
    }

    final normalizedFileName = rawFileName.trim();
    if (normalizedFileName.isEmpty || rawContents.isEmpty) {
      throw const EntryImportFileReaderException(
        'Entry import reader returned blank response values.',
        code: invalidResponseErrorCode,
      );
    }

    return EntryImportFileReadResult(
      fileName: normalizedFileName,
      contents: rawContents,
    );
  }
}
