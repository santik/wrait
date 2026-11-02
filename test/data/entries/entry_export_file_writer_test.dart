import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/entries/entry_export_file_writer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelEntryExportFileWriter.channelName);

  late MethodChannelEntryExportFileWriter writer;

  setUp(() {
    writer = const MethodChannelEntryExportFileWriter(channel: channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends the expected method name and arguments', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(
            call.method,
            MethodChannelEntryExportFileWriter.writeCsvExportMethod,
          );
          expect(call.arguments, <String, Object?>{
            'fileName': 'entries.csv',
            'contents': 'id\n1\n',
          });
          return <String, Object?>{
            'fileName': 'entries.csv',
            'pathLabel': 'Downloads/Wrait',
          };
        });

    final result = await writer.writeCsvExport(
      fileName: 'entries.csv',
      contents: 'id\n1\n',
    );

    expect(result.fileName, 'entries.csv');
    expect(result.pathLabel, 'Downloads/Wrait');
  });

  test('throws when the method channel returns an invalid response', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => <String, Object?>{});

    await expectLater(
      writer.writeCsvExport(fileName: 'entries.csv', contents: 'id\n'),
      throwsA(isA<EntryExportFileWriterException>()),
    );
  });

  test(
    'throws when the method channel returns blank response values',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => <String, Object?>{
              'fileName': '   ',
              'pathLabel': '\n',
            },
          );

      await expectLater(
        writer.writeCsvExport(fileName: 'entries.csv', contents: 'id\n'),
        throwsA(isA<EntryExportFileWriterException>()),
      );
    },
  );

  test('wraps platform exceptions with diagnostic context', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(
            code: 'entry-export-failed',
            message: 'Disk full',
          ),
        );

    await expectLater(
      writer.writeCsvExport(fileName: 'entries.csv', contents: 'id\n'),
      throwsA(
        isA<EntryExportFileWriterException>().having(
          (error) => error.message,
          'message',
          contains('Disk full'),
        ),
      ),
    );
  });

  test(
    'rejects empty csv contents before invoking the platform channel',
    () async {
      await expectLater(
        writer.writeCsvExport(fileName: 'entries.csv', contents: ''),
        throwsA(isA<EntryExportFileWriterException>()),
      );
    },
  );
}
