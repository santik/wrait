import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/entries/entry_import_file_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelEntryImportFileReader.channelName);

  late MethodChannelEntryImportFileReader reader;

  setUp(() {
    reader = const MethodChannelEntryImportFileReader(channel: channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends the expected method name with no arguments', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(
            call.method,
            MethodChannelEntryImportFileReader.pickCsvImportMethod,
          );
          expect(call.arguments, isNull);
          return <String, Object?>{
            'fileName': 'import.csv',
            'contents': 'id,type\n',
          };
        });

    final result = await reader.pickCsvImport();

    expect(result, isNotNull);
    expect(result!.fileName, 'import.csv');
    expect(result.contents, 'id,type\n');
  });

  test('returns null when the picker is cancelled', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);

    final result = await reader.pickCsvImport();

    expect(result, isNull);
  });

  test('throws when the method channel returns an invalid response', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => <String, Object?>{});

    await expectLater(
      reader.pickCsvImport(),
      throwsA(
        isA<EntryImportFileReaderException>().having(
          (error) => error.code,
          'code',
          MethodChannelEntryImportFileReader.invalidResponseErrorCode,
        ),
      ),
    );
  });

  test(
    'throws when the method channel returns blank response values',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => <String, Object?>{'fileName': '   ', 'contents': ''},
          );

      await expectLater(
        reader.pickCsvImport(),
        throwsA(
          isA<EntryImportFileReaderException>().having(
            (error) => error.code,
            'code',
            MethodChannelEntryImportFileReader.invalidResponseErrorCode,
          ),
        ),
      );
    },
  );

  test('wraps platform exceptions with diagnostic context', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(
            code: 'entry-import-failed',
            message: 'Picker unavailable',
          ),
        );

    await expectLater(
      reader.pickCsvImport(),
      throwsA(
        isA<EntryImportFileReaderException>()
            .having(
              (error) => error.message,
              'message',
              contains('Picker unavailable'),
            )
            .having((error) => error.code, 'code', 'entry-import-failed'),
      ),
    );
  });

  test('preserves file-too-large platform error codes', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(
            code: MethodChannelEntryImportFileReader.fileTooLargeErrorCode,
            message: 'Too large',
          ),
        );

    await expectLater(
      reader.pickCsvImport(),
      throwsA(
        isA<EntryImportFileReaderException>().having(
          (error) => error.code,
          'code',
          MethodChannelEntryImportFileReader.fileTooLargeErrorCode,
        ),
      ),
    );
  });
}
