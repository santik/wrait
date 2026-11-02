import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wrait/data/api/auth_interceptor.dart';
import 'package:wrait/data/api/backend_client.dart';
import 'package:wrait/data/api/device_token_store.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/api/backend_results.dart';
import 'package:wrait/data/api/generated/backend_api_generated.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('backend flows succeed against a local stub backend', (
    tester,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    final requests = <_ObservedRequest>[];
    final serverFuture = _serveBackend(server, requests);

    final audioFile = await _createTempAudioFile();
    BaseOptions buildOptions() => BaseOptions(
      baseUrl: 'http://${server.address.host}:${server.port}',
      headers: <String, dynamic>{'X-Proxy-Secret': 'proxy-secret'},
    );
    final tokenStore = DeviceTokenStore(_MemorySecureStore());
    final mainDio = Dio(buildOptions());
    final registrarClient = DioGeneratedBackendApiClient(Dio(buildOptions()));
    late final WraitBackendClient client;
    mainDio.interceptors.add(
      AuthInterceptor(
        dio: mainDio,
        deviceTokenStore: tokenStore,
        reRegister: () => client.register(),
      ),
    );
    client = WraitBackendClient(
      generatedClient: DioGeneratedBackendApiClient(mainDio),
      registrarClient: registrarClient,
      preferencesRepository: _FakePreferencesRepository(),
      deviceTokenStore: tokenStore,
    );

    final registration = await client.register();
    final transcription = await client.transcribeAudio(
      audioFile,
      language: 'nl-BE',
    );
    final cleanup = await client.cleanupTranscript(
      transcript: 'hello there diary friend',
      language: 'en-US',
    );
    final tagResult = await client.tagText(
      text: 'I had a productive day at the office',
      tags: ['work', 'health', 'travel'],
    );

    expect(registration, isA<RegistrationSuccess>());
    expect(
      transcription,
      isA<TranscriptionSuccess>()
          .having((value) => value.transcript, 'transcript', 'raw transcript')
          .having(
            (value) => value.detectedLanguage,
            'detectedLanguage',
            'en-US',
          ),
    );
    expect(
      cleanup,
      isA<CleanupSuccess>().having(
        (value) => value.cleanedText,
        'cleanedText',
        'Cleaned transcript.',
      ),
    );

    expect(
      tagResult,
      isA<TagTextSuccess>()
          .having((v) => v.tags, 'tags', hasLength(2))
          .having((v) => v.tags[0].tag, 'tag[0].tag', 'work')
          .having((v) => v.tags[0].probability, 'tag[0].probability', 0.85)
          .having((v) => v.tags[1].tag, 'tag[1].tag', 'health')
          .having((v) => v.tags[1].probability, 'tag[1].probability', 0.3),
    );

    expect(requests, hasLength(4));
    expect(requests[0].path, '/api/register');
    expect(requests[1].path, '/api/transcribe');
    expect(requests[1].queryParameters, <String, String>{'language': 'nl-BE'});
    expect(requests[2].path, '/api/cleanup');
    expect(requests[3].path, '/api/tag');

    for (final request in requests) {
      expect(request.proxySecret, 'proxy-secret');
    }
    // Register identifies by device id; quota-protected calls by token only.
    expect(requests[0].deviceId, _FakePreferencesRepository.deviceId);
    for (final request in requests.skip(1)) {
      expect(request.deviceId, isNull);
      expect(request.deviceToken, 'issued-token');
    }

    expect(requests[1].contentType, contains('multipart/form-data'));
    expect(requests[1].body, contains('name="audio"'));
    expect(requests[1].body, contains('filename="clip.m4a"'));
    expect(requests[1].body, contains('audio-body'));
    expect(requests[1].body, isNot(contains('name="language"')));

    expect(requests[2].jsonBody?['transcript'], 'hello there diary friend');
    expect(requests[2].jsonBody?['language'], 'en-US');

    expect(
      requests[3].jsonBody?['text'],
      'I had a productive day at the office',
    );
    expect(requests[3].jsonBody?['tags'], ['work', 'health', 'travel']);

    await server.close(force: true);
    await serverFuture;
  });
}

Future<void> _serveBackend(
  HttpServer server,
  List<_ObservedRequest> requests,
) async {
  await for (final request in server) {
    final bodyBytes = await request.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    final bodyText = latin1.decode(bodyBytes);
    final observed = _ObservedRequest(
      path: request.uri.path,
      queryParameters: request.uri.queryParameters,
      deviceId: request.headers.value('X-Device-Id'),
      deviceToken: request.headers.value('X-Device-Token'),
      proxySecret: request.headers.value('X-Proxy-Secret'),
      contentType: request.headers.contentType?.mimeType,
      body: bodyText,
      jsonBody:
          request.headers.contentType?.mimeType == ContentType.json.mimeType
          ? jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>
          : null,
    );
    requests.add(observed);

    request.response.headers.contentType = ContentType.json;
    switch (request.uri.path) {
      case '/api/register':
        request.response
          ..statusCode = 201
          ..write(
            '{"ok":true,"token":"issued-token","quota":{"limit":5,"count":1,"remaining":4,"resetAt":"2026-06-10T00:00:00Z"}}',
          );
        break;
      case '/api/transcribe':
        request.response
          ..statusCode = 200
          ..write(
            '{"transcript":"raw transcript","detected_language":"en-US","quota":{"limit":5,"count":2,"remaining":3,"resetAt":"2026-06-10T00:00:00Z"}}',
          );
        break;
      case '/api/cleanup':
        request.response
          ..statusCode = 200
          ..write(
            '{"cleanedText":"Cleaned transcript.","wasTruncated":false,"quota":{"limit":5,"count":3,"remaining":2,"resetAt":"2026-06-10T00:00:00Z"}}',
          );
        break;
      case '/api/tag':
        request.response
          ..statusCode = 200
          ..write(
            '{"tags":[{"tag":"work","probability":0.85},{"tag":"health","probability":0.3}]}',
          );
        break;
      default:
        request.response
          ..statusCode = 404
          ..write('{"error":"not found"}');
        break;
    }
    await request.response.close();
  }
}

class _ObservedRequest {
  const _ObservedRequest({
    required this.path,
    required this.queryParameters,
    required this.deviceId,
    required this.deviceToken,
    required this.proxySecret,
    required this.contentType,
    required this.body,
    required this.jsonBody,
  });

  final String path;
  final Map<String, String> queryParameters;
  final String? deviceId;
  final String? deviceToken;
  final String? proxySecret;
  final String? contentType;
  final String body;
  final Map<String, dynamic>? jsonBody;
}

class _FakePreferencesRepository implements PreferencesRepository {
  static const deviceId =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  @override
  Future<String> getDeviceId() async => deviceId;

  @override
  Future<bool> getHasEverRecorded() async => false;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}

Future<File> _createTempAudioFile() async {
  final directory = await Directory.systemTemp.createTemp('wrait-backend-int');
  final file = File('${directory.path}/clip.m4a');
  await file.writeAsString('audio-body');
  return file;
}

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
