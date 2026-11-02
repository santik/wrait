import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/backend_results.dart' show RegistrationSuccess;
import 'package:wrait/data/api/device_token_store.dart';
import 'package:wrait/data/audio/audio_recording_providers.dart';
import 'package:wrait/data/audio/audio_recording_service.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/transcription/transcription_providers.dart';
import 'package:wrait/data/transcription/transcription_service.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/domain/repository/transcription_language_preferences_repository.dart';

const _deviceId =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _quotaJson =
    '"quota":{"limit":5,"count":1,"remaining":4,"resetAt":"2026-06-10T00:00:00Z"}';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch registers, stores the token, then transcribes with '
      'the token only', (tester) async {
    final backend = await _StubBackend.start(
      onRegister: (_, _) =>
          _Reply(201, '{"ok":true,"token":"tok-1",$_quotaJson}'),
      onTranscribe: (_, _) => _Reply(
        200,
        '{"transcript":"hello world","detected_language":"en-US",$_quotaJson}',
      ),
    );
    addTearDown(backend.close);
    final harness = await _Harness.create(backend);
    addTearDown(harness.dispose);

    // Launch registration (same callback the launch use case runs).
    final registration = await harness.container
        .read(wraitBackendClientProvider)
        .register();
    expect(registration, isA<RegistrationSuccess>());
    expect(await harness.tokenStore.read(), 'tok-1');

    final result = await harness.recordAndStop();

    expect(result, isA<TranscriptionSuccess>());
    expect((result as TranscriptionSuccess).transcript, 'hello world');
    expect(backend.requests.map((r) => r.path), <String>[
      '/api/register',
      '/api/transcribe',
    ]);
    expect(backend.requests[0].deviceId, _deviceId);
    expect(backend.requests[0].deviceToken, isNull);
    expect(backend.requests[1].deviceToken, 'tok-1');
    expect(backend.requests[1].deviceId, isNull);
  });

  testWidgets('rejected credential is re-registered once and the call is '
      'retried transparently', (tester) async {
    var transcribeCalls = 0;
    final backend = await _StubBackend.start(
      onRegister: (_, _) =>
          _Reply(201, '{"ok":true,"token":"tok-fresh",$_quotaJson}'),
      onTranscribe: (_, request) {
        transcribeCalls += 1;
        if (request.deviceToken != 'tok-fresh') {
          return _Reply(403, '{"error":"Forbidden"}');
        }
        return _Reply(
          200,
          '{"transcript":"recovered","detected_language":"en-US",$_quotaJson}',
        );
      },
    );
    addTearDown(backend.close);
    final harness = await _Harness.create(backend, storedToken: 'tok-stale');
    addTearDown(harness.dispose);

    final result = await harness.recordAndStop();

    expect(result, isA<TranscriptionSuccess>());
    expect((result as TranscriptionSuccess).transcript, 'recovered');
    expect(transcribeCalls, 2);
    expect(backend.requests.map((r) => r.path), <String>[
      '/api/transcribe',
      '/api/register',
      '/api/transcribe',
    ]);
    // The re-register presents the stale token and the device id.
    expect(backend.requests[1].deviceToken, 'tok-stale');
    expect(backend.requests[1].deviceId, _deviceId);
    expect(await harness.tokenStore.read(), 'tok-fresh');
  });

  testWidgets('registration rate limit surfaces as retriable and preserves the '
      'draft audio', (tester) async {
    final backend = await _StubBackend.start(
      onRegister: (_, _) => _Reply(429, '{"error":"Too many requests"}'),
      onTranscribe: (_, _) => _Reply(500, '{"error":"unexpected"}'),
    );
    addTearDown(backend.close);
    // No stored token: the transcribe call must register first.
    final harness = await _Harness.create(backend);
    addTearDown(harness.dispose);

    final result = await harness.recordAndStop();

    expect(
      result,
      isA<TranscriptionFailure>()
          .having(
            (v) => v.reason,
            'reason',
            TranscriptionFailureReason.rateLimited,
          )
          .having((v) => v.audioDraftPath, 'audioDraftPath', harness.livePath),
    );
    expect(await File(harness.livePath).exists(), isTrue);
    expect(backend.requests.map((r) => r.path), <String>['/api/register']);

    // Retriable: once the limiter relaxes, the same flow succeeds.
    backend.onRegister = (_, _) =>
        _Reply(201, '{"ok":true,"token":"tok-2",$_quotaJson}');
    backend.onTranscribe = (_, _) => _Reply(
      200,
      '{"transcript":"later","detected_language":"en-US",$_quotaJson}',
    );
    final retry = await harness.recordAndStop();
    expect(retry, isA<TranscriptionSuccess>());
  });
}

class _Harness {
  _Harness._(
    this.container,
    this.tokenStore,
    this.tempDirectory,
    this.livePath,
  );

  final ProviderContainer container;
  final DeviceTokenStore tokenStore;
  final Directory tempDirectory;
  final String livePath;

  static Future<_Harness> create(
    _StubBackend backend, {
    String? storedToken,
  }) async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'wrait-quota-abuse-int',
    );
    final livePath = '${tempDirectory.path}/live.m4a';
    final tokenStore = DeviceTokenStore(_MemorySecureStore());
    if (storedToken != null) {
      await tokenStore.write(storedToken);
    }
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            backendUrl: 'http://${backend.host}:${backend.port}',
            proxySecret: 'proxy-secret',
          ),
        ),
        preferencesRepositoryProvider.overrideWithValue(
          _FakePreferencesRepository(),
        ),
        deviceTokenStoreProvider.overrideWithValue(tokenStore),
        audioRecordingServiceProvider.overrideWithValue(_FakeAudioService()),
        liveRecordingPathFactoryProvider.overrideWithValue(
          () async => livePath,
        ),
        transcriptionLanguagePreferencesRepositoryProvider.overrideWithValue(
          const _AutoLanguage(),
        ),
      ],
    );
    return _Harness._(container, tokenStore, tempDirectory, livePath);
  }

  Future<TranscriptionResult> recordAndStop() async {
    final service = container.read(transcriptionServiceProvider);
    await service.startLiveTranscription(onStatus: (_) {});
    return service.stopLiveTranscription(onStatus: (_) {});
  }

  Future<void> dispose() async {
    container.dispose();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

class _Observed {
  const _Observed({
    required this.path,
    required this.deviceId,
    required this.deviceToken,
    required this.proxySecret,
  });

  final String path;
  final String? deviceId;
  final String? deviceToken;
  final String? proxySecret;
}

class _Reply {
  const _Reply(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

typedef _Handler = _Reply Function(List<int> body, _Observed request);

class _StubBackend {
  _StubBackend._(this._server, this.onRegister, this.onTranscribe);

  final HttpServer _server;
  _Handler onRegister;
  _Handler onTranscribe;
  final List<_Observed> requests = <_Observed>[];

  String get host => _server.address.host;
  int get port => _server.port;

  static Future<_StubBackend> start({
    required _Handler onRegister,
    required _Handler onTranscribe,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final backend = _StubBackend._(server, onRegister, onTranscribe);
    unawaited(backend._serve());
    return backend;
  }

  Future<void> _serve() async {
    await for (final request in _server) {
      final bytes = await request.fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      );
      final observed = _Observed(
        path: request.uri.path,
        deviceId: request.headers.value('X-Device-Id'),
        deviceToken: request.headers.value('X-Device-Token'),
        proxySecret: request.headers.value('X-Proxy-Secret'),
      );
      requests.add(observed);
      final reply = switch (request.uri.path) {
        '/api/register' => onRegister(bytes, observed),
        '/api/transcribe' => onTranscribe(bytes, observed),
        _ => const _Reply(404, '{"error":"not found"}'),
      };
      request.response
        ..statusCode = reply.statusCode
        ..headers.contentType = ContentType.json
        ..write(reply.body);
      await request.response.close();
    }
  }

  Future<void> close() => _server.close(force: true);
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

class _FakePreferencesRepository implements PreferencesRepository {
  @override
  Future<String> getDeviceId() async => _deviceId;

  @override
  Future<bool> getHasEverRecorded() async => false;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}

class _AutoLanguage implements TranscriptionLanguagePreferencesRepository {
  const _AutoLanguage();

  @override
  Future<String?> getTranscriptionLanguage() async => null;

  @override
  Future<void> setTranscriptionLanguage(String? value) async {}
}

class _FakeAudioService implements AudioRecordingService {
  @override
  bool isRecording = false;

  @override
  int? hardCapDeadlineElapsedRealtime;

  String? _path;

  @override
  Future<void> startRecording(String outputPath) async {
    _path = outputPath;
    isRecording = true;
    hardCapDeadlineElapsedRealtime = 123456;
  }

  @override
  Future<String> stopRecording() async {
    final path = _path;
    if (path == null) {
      throw const NoActiveRecordingFailure();
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(utf8.encode('audio'));
    _path = null;
    isRecording = false;
    hardCapDeadlineElapsedRealtime = null;
    return path;
  }

  @override
  Future<void> cancelRecording() async {
    _path = null;
    isRecording = false;
    hardCapDeadlineElapsedRealtime = null;
  }
}
