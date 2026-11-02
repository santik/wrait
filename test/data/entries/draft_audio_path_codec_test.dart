import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:wrait/data/entries/draft_audio_path_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory cacheDirectory;
  late String activeCacheDirectoryPath;

  setUp(() async {
    cacheDirectory = await Directory.systemTemp.createTemp(
      'wrait-draft-audio-codec',
    );
    activeCacheDirectoryPath = cacheDirectory.path;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          expect(call.method, 'getTemporaryDirectory');
          return activeCacheDirectoryPath;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);

    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
    }
  });

  test('stores app-temp audio as an app-cache relative reference', () async {
    final recordingsDirectory = Directory(
      path.join(cacheDirectory.path, 'recordings'),
    );
    await recordingsDirectory.create(recursive: true);
    final audioFile = File(path.join(recordingsDirectory.path, 'draft.m4a'));
    await audioFile.writeAsString('audio');

    final storedPath = await DraftAudioPathCodec.store(audioFile.path);

    expect(
      storedPath,
      '${DraftAudioPathCodec.cacheScheme}recordings${path.separator}draft.m4a',
    );
  });

  test('rejects audio paths outside the app temporary directory', () async {
    final outsideDirectory = await Directory.systemTemp.createTemp(
      'wrait-draft-audio-outside',
    );
    addTearDown(() async {
      if (await outsideDirectory.exists()) {
        await outsideDirectory.delete(recursive: true);
      }
    });
    final audioFile = File(path.join(outsideDirectory.path, 'draft.m4a'));
    await audioFile.writeAsString('audio');

    await expectLater(
      DraftAudioPathCodec.store(audioFile.path),
      throwsA(isA<ArgumentError>()),
    );
  });

  test(
    'resolves stored references against the current app temp directory',
    () async {
      final updatedCacheDirectory = await Directory.systemTemp.createTemp(
        'wrait-draft-audio-updated-cache',
      );
      addTearDown(() async {
        if (await updatedCacheDirectory.exists()) {
          await updatedCacheDirectory.delete(recursive: true);
        }
      });

      activeCacheDirectoryPath = updatedCacheDirectory.path;

      final resolvedPath = await DraftAudioPathCodec.resolve(
        '${DraftAudioPathCodec.cacheScheme}drafts${path.separator}draft.m4a',
      );

      expect(
        resolvedPath,
        path.join(updatedCacheDirectory.path, 'drafts', 'draft.m4a'),
      );
    },
  );

  test('rejects blank stored references', () async {
    await expectLater(
      DraftAudioPathCodec.resolve('   '),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects traversal stored references', () async {
    await expectLater(
      DraftAudioPathCodec.resolve(
        '${DraftAudioPathCodec.cacheScheme}../draft.m4a',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects absolute stored payloads', () async {
    await expectLater(
      DraftAudioPathCodec.resolve(
        '${DraftAudioPathCodec.cacheScheme}${cacheDirectory.path}',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects unsupported absolute stored paths', () async {
    await expectLater(
      DraftAudioPathCodec.resolve(path.join(cacheDirectory.path, 'draft.m4a')),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects mixed-case stored scheme values', () async {
    await expectLater(
      DraftAudioPathCodec.resolve('APP-CACHE://draft.m4a'),
      throwsA(isA<FormatException>()),
    );
  });

  test('normalizes in-cache stored references before resolving', () async {
    final resolvedPath = await DraftAudioPathCodec.resolve(
      '${DraftAudioPathCodec.cacheScheme}drafts${path.separator}nested${path.separator}..${path.separator}draft.m4a',
    );

    expect(resolvedPath, path.join(cacheDirectory.path, 'drafts', 'draft.m4a'));
  });

  test('rejects normalized escape attempts', () async {
    await expectLater(
      DraftAudioPathCodec.resolve(
        '${DraftAudioPathCodec.cacheScheme}drafts${path.separator}..${path.separator}..${path.separator}escape.m4a',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
