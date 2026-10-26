import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/api/auth_interceptor.dart';
import 'package:wrait/data/api/backend_results.dart';
import 'package:wrait/data/api/device_token_store.dart';

import '../../test_doubles/fake_secure_storage.dart';

ResponseBody _json(int status, [String body = '{}']) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _FnAdapter implements HttpClientAdapter {
  _FnAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeSecureKeyValueStore storage;
  late DeviceTokenStore tokenStore;
  late int reRegisterCount;
  late Future<RegistrationResult> Function() reRegister;

  setUp(() {
    storage = FakeSecureKeyValueStore();
    tokenStore = DeviceTokenStore(storage);
    reRegisterCount = 0;
    // Default: re-registration succeeds and persists a fresh token.
    reRegister = () async {
      reRegisterCount += 1;
      await tokenStore.write('fresh-$reRegisterCount');
      return const RegistrationSuccess();
    };
  });

  Dio buildDio(ResponseBody Function(RequestOptions) handler) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _FnAdapter(handler);
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        deviceTokenStore: tokenStore,
        reRegister: () => reRegister(),
      ),
    );
    return dio;
  }

  Future<Response<dynamic>> call(Dio dio, {String path = '/api/transcribe'}) =>
      dio.request<dynamic>(
        path,
        options: Options(method: 'POST', validateStatus: (_) => true),
      );

  test('attaches the stored token on quota requests', () async {
    await tokenStore.write('stored');
    String? sent;
    final dio = buildDio((options) {
      sent = options.headers['X-Device-Token'] as String?;
      return _json(200);
    });

    final response = await call(dio);

    expect(response.statusCode, 200);
    expect(sent, 'stored');
    expect(reRegisterCount, 0);
  });

  test('registers first when no token is stored', () async {
    String? sent;
    final dio = buildDio((options) {
      sent = options.headers['X-Device-Token'] as String?;
      return _json(200);
    });

    final response = await call(dio);

    expect(response.statusCode, 200);
    expect(reRegisterCount, 1);
    expect(sent, 'fresh-1');
  });

  test('on 403 re-registers once and retries with the fresh token', () async {
    await tokenStore.write('stale');
    final tokens = <String?>[];
    var calls = 0;
    final dio = buildDio((options) {
      calls += 1;
      tokens.add(options.headers['X-Device-Token'] as String?);
      return _json(calls == 1 ? 403 : 200);
    });

    final response = await call(dio);

    expect(response.statusCode, 200);
    expect(reRegisterCount, 1);
    expect(calls, 2);
    expect(tokens, <String?>['stale', 'fresh-1']);
  });

  test('a persistent 403 is retried once, then surfaces 403', () async {
    await tokenStore.write('stale');
    var calls = 0;
    final dio = buildDio((options) {
      calls += 1;
      return _json(403);
    });

    final response = await call(dio);

    expect(response.statusCode, 403);
    expect(reRegisterCount, 1);
    expect(calls, 2);
  });

  test('re-register failure rejects with AuthFailure(reason)', () async {
    reRegister = () async {
      reRegisterCount += 1;
      return const RegistrationFailure(RegistrationFailureReason.rateLimited);
    };
    final dio = buildDio((options) => _json(200)); // no token → register first

    await expectLater(
      call(dio),
      throwsA(
        isA<DioException>().having(
          (error) => error.error,
          'error',
          isA<AuthFailure>().having(
            (failure) => failure.reason,
            'reason',
            BackendFailureReason.rateLimited,
          ),
        ),
      ),
    );
    expect(reRegisterCount, 1);
  });

  test('register requests are passed through untouched', () async {
    String? sent;
    final dio = buildDio((options) {
      sent = options.headers['X-Device-Token'] as String?;
      return _json(201, '{"ok":true}');
    });

    final response = await call(dio, path: '/api/register');

    expect(response.statusCode, 201);
    expect(reRegisterCount, 0);
    expect(sent, isNull);
  });

  test('concurrent 403s trigger a single re-registration', () async {
    await tokenStore.write('stale');
    // Hold re-registration open until both requests are waiting on it, so the
    // single-flight window is deterministic rather than timing-dependent.
    final gate = Completer<void>();
    reRegister = () async {
      reRegisterCount += 1;
      await gate.future;
      await tokenStore.write('fresh');
      return const RegistrationSuccess();
    };
    final dio = buildDio((options) {
      final token = options.headers['X-Device-Token'] as String?;
      return _json(token == 'stale' ? 403 : 200);
    });

    final first = call(dio);
    final second = call(dio);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    gate.complete();
    final responses = await Future.wait([first, second]);

    expect(responses.every((r) => r.statusCode == 200), isTrue);
    expect(reRegisterCount, 1);
  });

  test('on 403 retries a multipart body with a fresh clone', () async {
    await tokenStore.write('stale');
    final bodies = <FormData>[];
    final dio = buildDio((options) {
      final data = options.data;
      if (data is FormData) bodies.add(data);
      final token = options.headers['X-Device-Token'] as String?;
      return _json(token == 'stale' ? 403 : 200);
    });

    final response = await dio.request<dynamic>(
      '/api/transcribe',
      data: FormData.fromMap(<String, dynamic>{
        'audio': MultipartFile.fromBytes(
          <int>[1, 2, 3],
          filename: 'clip.m4a',
        ),
      }),
      options: Options(method: 'POST', validateStatus: (_) => true),
    );

    expect(response.statusCode, 200);
    expect(reRegisterCount, 1);
    // Both sends carried a FormData body, and the retry used a *different*
    // instance: the original was finalized by the first send, so reusing it
    // would throw "already finalized" — the clone is what makes the retry work.
    expect(bodies, hasLength(2));
    expect(identical(bodies[0], bodies[1]), isFalse);
  });
}
