import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/api/auth_interceptor.dart';
import 'package:wrait/data/api/backend_client.dart';
import 'package:wrait/data/api/backend_results.dart';
import 'package:wrait/data/api/device_token_store.dart';
import 'package:wrait/data/api/generated/backend_api_generated.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';

import '../../test_doubles/fake_secure_storage.dart';

void main() {
  group('WraitBackendClient', () {
    late _FakePreferencesRepository preferencesRepository;
    late _FakeGeneratedBackendApiClient generatedClient;
    late List<Duration> delayCalls;
    late FakeSecureKeyValueStore secureStorage;
    late DeviceTokenStore tokenStore;
    late WraitBackendClient backendClient;

    setUp(() {
      preferencesRepository = _FakePreferencesRepository();
      generatedClient = _FakeGeneratedBackendApiClient();
      delayCalls = <Duration>[];
      secureStorage = FakeSecureKeyValueStore(<String, String>{
        DeviceTokenStore.storageKey: 'stored-token',
      });
      tokenStore = DeviceTokenStore(secureStorage);
      backendClient = WraitBackendClient(
        generatedClient: generatedClient,
        registrarClient: generatedClient,
        preferencesRepository: preferencesRepository,
        deviceTokenStore: tokenStore,
        delay: (duration) async => delayCalls.add(duration),
      );
    });

    test(
      'register retries transient server failures and then succeeds',
      () async {
        generatedClient.registerResponses.addAll(<Object>[
          const GeneratedApiFailure<RegisterResponse>(
            statusCode: 500,
            data: <String, dynamic>{'error': 'server exploded'},
          ),
          const GeneratedApiFailure<RegisterResponse>(
            statusCode: 502,
            data: <String, dynamic>{'error': 'upstream exploded'},
          ),
          GeneratedApiSuccess<RegisterResponse>(
            statusCode: 201,
            data: RegisterResponse(
              ok: true,
              quota: RecordQuota(
                limit: 5,
                count: 1,
                remaining: 4,
                resetAt: DateTime.utc(2026, 6, 10),
              ),
            ),
          ),
        ]);

        final result = await backendClient.register();

        expect(result, isA<RegistrationSuccess>());
        expect(generatedClient.registerCallCount, 3);
        expect(delayCalls, <Duration>[
          const Duration(seconds: 1),
          const Duration(seconds: 2),
        ]);
        expect((result as RegistrationSuccess).quota?.remaining, 4);
      },
    );

    test('register stops after max transient attempts', () async {
      generatedClient.registerResponses.addAll(
        List<Object>.filled(
          3,
          const GeneratedApiFailure<RegisterResponse>(
            statusCode: 500,
            data: <String, dynamic>{'error': 'still broken'},
          ),
        ),
      );

      final result = await backendClient.register();

      expect(
        result,
        isA<RegistrationFailure>().having(
          (value) => value.reason,
          'reason',
          RegistrationFailureReason.transient,
        ),
      );
      expect(generatedClient.registerCallCount, 3);
      expect(delayCalls, <Duration>[
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
    });

    test('register does not retry non transient 4xx failures', () async {
      generatedClient.registerResponses.add(
        const GeneratedApiFailure<RegisterResponse>(
          statusCode: 400,
          data: <String, dynamic>{'error': 'bad request'},
        ),
      );

      final result = await backendClient.register();

      expect(
        result,
        isA<RegistrationFailure>().having(
          (value) => value.reason,
          'reason',
          RegistrationFailureReason.apiError,
        ),
      );
      expect(generatedClient.registerCallCount, 1);
      expect(delayCalls, isEmpty);
    });

    test('register maps 401 to proxy auth failure without retrying', () async {
      generatedClient.registerResponses.add(
        const GeneratedApiFailure<RegisterResponse>(
          statusCode: 401,
          data: <String, dynamic>{'error': 'unauthorized'},
        ),
      );

      final result = await backendClient.register();

      expect(
        result,
        isA<RegistrationFailure>().having(
          (value) => value.reason,
          'reason',
          RegistrationFailureReason.proxyAuthFailed,
        ),
      );
      expect(generatedClient.registerCallCount, 1);
    });

    test('transcription maps 401 to proxy auth failure', () async {
      generatedClient.transcribeResponses.add(
        const GeneratedApiFailure<TranscribeResponse>(
          statusCode: 401,
          data: <String, dynamic>{'error': 'unauthorized'},
        ),
      );

      final result = await backendClient.transcribeAudio(
        await _createTempAudioFile('auth'),
      );

      expect(
        result,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.proxyAuthFailed,
        ),
      );
    });

    test('transcription forwards an exact supported language code', () async {
      generatedClient.transcribeResponses.add(
        const GeneratedApiSuccess<TranscribeResponse>(
          statusCode: 200,
          data: TranscribeResponse(
            transcript: 'hello',
            detectedLanguage: 'de-CH',
          ),
        ),
      );

      await backendClient.transcribeAudio(
        await _createTempAudioFile('language'),
        language: 'de-CH',
      );

      expect(generatedClient.lastTranscriptionLanguage, 'de-CH');
    });

    test(
      'transcription rejects unsupported language before the request',
      () async {
        final result = await backendClient.transcribeAudio(
          await _createTempAudioFile('invalid-language'),
          language: 'multi',
        );

        expect(result, isA<TranscriptionFailure>());
        expect(generatedClient.transcribeCallCount, 0);
      },
    );

    test('cleanup maps 401 to proxy auth failure', () async {
      generatedClient.cleanupResponses.add(
        const GeneratedApiFailure<CleanupResponse>(
          statusCode: 401,
          data: <String, dynamic>{'error': 'unauthorized'},
        ),
      );

      final result = await backendClient.cleanupTranscript(
        transcript: 'hello there diary',
        language: 'en-US',
      );

      expect(
        result,
        isA<CleanupFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.proxyAuthFailed,
        ),
      );
    });

    test('transcription and cleanup map 5xx to backend unavailable', () async {
      generatedClient.transcribeResponses.add(
        const GeneratedApiFailure<TranscribeResponse>(
          statusCode: 503,
          data: <String, dynamic>{'error': 'unavailable'},
        ),
      );
      generatedClient.cleanupResponses.add(
        const GeneratedApiFailure<CleanupResponse>(
          statusCode: 500,
          data: <String, dynamic>{'error': 'oops'},
        ),
      );

      final transcription = await backendClient.transcribeAudio(
        await _createTempAudioFile('503'),
      );
      final cleanup = await backendClient.cleanupTranscript(
        transcript: 'hello there diary',
        language: 'en-US',
      );

      expect(
        transcription,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.backendUnavailable,
        ),
      );
      expect(
        cleanup,
        isA<CleanupFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.backendUnavailable,
        ),
      );
    });

    test('transcription maps 413 to request too large', () async {
      generatedClient.transcribeResponses.add(
        const GeneratedApiFailure<TranscribeResponse>(
          statusCode: 413,
          data: <String, dynamic>{'error': 'too large'},
        ),
      );

      final result = await backendClient.transcribeAudio(
        await _createTempAudioFile('413'),
      );

      expect(
        result,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.requestTooLarge,
        ),
      );
    });

    test('cleanup maps 413 to request too large', () async {
      generatedClient.cleanupResponses.add(
        const GeneratedApiFailure<CleanupResponse>(
          statusCode: 413,
          data: <String, dynamic>{'error': 'too large'},
        ),
      );

      final result = await backendClient.cleanupTranscript(
        transcript: 'hello there diary',
        language: 'en-US',
      );

      expect(
        result,
        isA<CleanupFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.requestTooLarge,
        ),
      );
    });

    test(
      'transcription maps 502 and cleanup maps 504 to backend unavailable',
      () async {
        generatedClient.transcribeResponses.add(
          const GeneratedApiFailure<TranscribeResponse>(
            statusCode: 502,
            data: <String, dynamic>{'error': 'upstream exploded'},
          ),
        );
        generatedClient.cleanupResponses.add(
          const GeneratedApiFailure<CleanupResponse>(
            statusCode: 504,
            data: <String, dynamic>{'error': 'upstream timeout'},
          ),
        );

        final transcription = await backendClient.transcribeAudio(
          await _createTempAudioFile('upstream'),
        );
        final cleanup = await backendClient.cleanupTranscript(
          transcript: 'hello there diary',
          language: 'en-US',
        );

        expect(
          transcription,
          isA<TranscriptionFailure>().having(
            (value) => value.reason,
            'reason',
            BackendFailureReason.backendUnavailable,
          ),
        );
        expect(
          cleanup,
          isA<CleanupFailure>().having(
            (value) => value.reason,
            'reason',
            BackendFailureReason.backendUnavailable,
          ),
        );
      },
    );

    test('connection errors map to no internet', () async {
      generatedClient.transcribeResponses.add(
        DioException(
          requestOptions: RequestOptions(path: '/api/transcribe'),
          type: DioExceptionType.connectionError,
          error: const SocketException('offline'),
        ),
      );
      generatedClient.cleanupResponses.add(
        DioException(
          requestOptions: RequestOptions(path: '/api/cleanup'),
          type: DioExceptionType.connectionError,
          error: const SocketException('offline'),
        ),
      );

      final transcription = await backendClient.transcribeAudio(
        await _createTempAudioFile('offline'),
      );
      final cleanup = await backendClient.cleanupTranscript(
        transcript: 'hello there diary',
        language: 'en-US',
      );

      expect(
        transcription,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.noInternet,
        ),
      );
      expect(
        cleanup,
        isA<CleanupFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.noInternet,
        ),
      );
    });

    test('timeout errors map to timeout specific failures', () async {
      generatedClient.transcribeResponses.add(
        DioException(
          requestOptions: RequestOptions(path: '/api/transcribe'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      generatedClient.cleanupResponses.add(
        DioException(
          requestOptions: RequestOptions(path: '/api/cleanup'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final transcription = await backendClient.transcribeAudio(
        await _createTempAudioFile('timeout'),
      );
      final cleanup = await backendClient.cleanupTranscript(
        transcript: 'hello there diary',
        language: 'en-US',
      );

      expect(
        transcription,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.timeout,
        ),
      );
      expect(
        cleanup,
        isA<CleanupFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.timeout,
        ),
      );
    });

    test(
      'transcription maps 422 to speech not recognized without quota',
      () async {
        generatedClient.transcribeResponses.add(
          const GeneratedApiFailure<TranscribeResponse>(
            statusCode: 422,
            data: <String, dynamic>{
              'error': 'Speech could not be recognized',
              'reason': 'speech_not_recognized',
            },
          ),
        );

        final result = await backendClient.transcribeAudio(
          await _createTempAudioFile('422'),
        );

        expect(
          result,
          isA<TranscriptionFailure>().having(
            (value) => value.reason,
            'reason',
            BackendFailureReason.speechNotRecognized,
          ),
        );
        expect((result as TranscriptionFailure).quota, isNull);
      },
    );

    test('429 maps to quota exceeded and surfaces valid quota', () async {
      generatedClient.transcribeResponses.add(
        const GeneratedApiFailure<TranscribeResponse>(
          statusCode: 429,
          data: <String, dynamic>{
            'error': 'Daily record limit exceeded',
            'quota': <String, dynamic>{
              'limit': 5,
              'count': 5,
              'remaining': 0,
              'resetAt': '2026-06-10T00:00:00Z',
            },
          },
        ),
      );

      final result = await backendClient.transcribeAudio(
        await _createTempAudioFile('quota'),
      );

      expect(
        result,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.quotaExceeded,
        ),
      );
      expect((result as TranscriptionFailure).quota?.remaining, 0);
    });

    test('blank transcript is preserved as a success payload for caller classification', () async {
      generatedClient.transcribeResponses.add(
        const GeneratedApiSuccess<TranscribeResponse>(
          statusCode: 200,
          data: TranscribeResponse(
            transcript: '   ',
            detectedLanguage: 'en-US',
          ),
        ),
      );

      final result = await backendClient.transcribeAudio(
        await _createTempAudioFile('blank-transcript'),
      );

      expect(
        result,
        isA<TranscriptionSuccess>()
            .having((value) => value.transcript, 'transcript', '')
            .having(
              (value) => value.detectedLanguage,
              'detectedLanguage',
              'en-US',
            ),
      );
    });

    test('blank detected language is allowed as nullable success', () async {
      generatedClient.transcribeResponses.add(
        const GeneratedApiSuccess<TranscribeResponse>(
          statusCode: 200,
          data: TranscribeResponse(
            transcript: 'usable transcript',
            detectedLanguage: '   ',
          ),
        ),
      );

      final result = await backendClient.transcribeAudio(
        await _createTempAudioFile('blank-language'),
      );

      expect(
        result,
        isA<TranscriptionSuccess>()
            .having(
              (value) => value.transcript,
              'transcript',
              'usable transcript',
            )
            .having(
              (value) => value.detectedLanguage,
              'detectedLanguage',
              isNull,
            ),
      );
    });

    test('blank cleaned text is treated as api error failure', () async {
      final quota = RecordQuota(
        limit: 5,
        count: 4,
        remaining: 1,
        resetAt: DateTime.utc(2026, 6, 10),
      );
      generatedClient.cleanupResponses.add(
        GeneratedApiSuccess<CleanupResponse>(
          statusCode: 200,
          data: CleanupResponse(
            cleanedText: '   ',
            wasTruncated: false,
            quota: quota,
          ),
        ),
      );

      final result = await backendClient.cleanupTranscript(
        transcript: 'hello there diary',
        language: 'en-US',
      );

      expect(
        result,
        isA<CleanupFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.apiError,
        ),
      );
      expect((result as CleanupFailure).quota?.remaining, 1);
    });

    test(
      'register sends device and proxy headers through the generated client',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));

        final requestSeen = Completer<HttpHeaders>();
        unawaited(() async {
          final request = await server.first;
          requestSeen.complete(request.headers);
          request.response
            ..statusCode = 201
            ..headers.contentType = ContentType.json
            ..write('{"ok":true}');
          await request.response.close();
        }());

        final realGenerated = DioGeneratedBackendApiClient(
          Dio(
            BaseOptions(
              baseUrl: 'http://${server.address.host}:${server.port}',
              headers: <String, dynamic>{'X-Proxy-Secret': 'proxy-secret'},
            ),
          ),
        );
        final realClient = WraitBackendClient(
          generatedClient: realGenerated,
          registrarClient: realGenerated,
          preferencesRepository: preferencesRepository,
          deviceTokenStore: tokenStore,
        );

        final result = await realClient.register();

        expect(result, isA<RegistrationSuccess>());
        final headers = await requestSeen.future;
        expect(headers.value('X-Device-Id'), preferencesRepository.deviceId);
        expect(headers.value('X-Proxy-Secret'), 'proxy-secret');
        expect(headers.value('X-Device-Token'), 'stored-token');
      },
    );

    group('device token', () {
      GeneratedApiSuccess<RegisterResponse> registered({String? token}) =>
          GeneratedApiSuccess<RegisterResponse>(
            statusCode: 201,
            data: RegisterResponse(
              ok: true,
              token: token,
              quota: RecordQuota(
                limit: 5,
                count: 1,
                remaining: 4,
                resetAt: DateTime.utc(2026, 6, 10),
              ),
            ),
          );

      const forbidden = GeneratedApiFailure<TranscribeResponse>(
        statusCode: 403,
        data: <String, dynamic>{'error': 'Forbidden'},
      );

      test(
        'Mode A: no stored token registers, stores token and quota',
        () async {
          await tokenStore.clear();
          generatedClient.registerResponses.add(registered(token: 'new-token'));

          final result = await backendClient.register();

          expect(generatedClient.registerTokens, <String?>[null]);
          expect(result, isA<RegistrationSuccess>());
          expect((result as RegistrationSuccess).quota?.remaining, 4);
          expect(await tokenStore.read(), 'new-token');
        },
      );

      test(
        'upgrade from a device-id-only build binds a token to that device id',
        () async {
          // Simulates a user upgrading from a build that stored no token: the
          // first launch presents the existing device id with no token, and the
          // server binds a freshly issued token to it so accrued quota carries
          // over. The device id must be forwarded for that binding to happen.
          await tokenStore.clear();
          generatedClient.registerResponses.add(
            registered(token: 'migrated-token'),
          );

          final result = await backendClient.register();

          expect(generatedClient.registerTokens, <String?>[null]);
          expect(generatedClient.registerDeviceIds, <String>[
            _FakePreferencesRepository().deviceId,
          ]);
          expect(result, isA<RegistrationSuccess>());
          expect((result as RegistrationSuccess).quota?.remaining, 4);
          expect(await tokenStore.read(), 'migrated-token');
        },
      );

      test(
        'Mode B: stored token is sent and kept when none is issued',
        () async {
          generatedClient.registerResponses.add(registered());

          final result = await backendClient.register();

          expect(generatedClient.registerTokens, <String?>['stored-token']);
          expect((result as RegistrationSuccess).quota?.remaining, 4);
          expect(await tokenStore.read(), 'stored-token');
        },
      );

      test('register maps 429 to rateLimited without retrying', () async {
        generatedClient.registerResponses.add(
          const GeneratedApiFailure<RegisterResponse>(
            statusCode: 429,
            data: <String, dynamic>{'error': 'Too many requests'},
          ),
        );

        final result = await backendClient.register();

        expect(
          result,
          isA<RegistrationFailure>().having(
            (value) => value.reason,
            'reason',
            RegistrationFailureReason.rateLimited,
          ),
        );
        expect(generatedClient.registerCallCount, 1);
        expect(delayCalls, isEmpty);
      });

      // Recovery (token attach, re-register on 403, retry) now lives in
      // AuthInterceptor — see auth_interceptor_test.dart. The client just maps
      // the outcome it is handed.

      test(
        'a direct 403 maps to credentialRejected (no recovery in the client)',
        () async {
          generatedClient.transcribeResponses.add(forbidden);

          final result = await backendClient.transcribeAudio(
            await _createTempAudioFile('direct-403'),
          );

          expect(
            result,
            isA<TranscriptionFailure>().having(
              (value) => value.reason,
              'reason',
              BackendFailureReason.credentialRejected,
            ),
          );
          expect(generatedClient.transcribeCallCount, 1);
          expect(generatedClient.registerCallCount, 0);
        },
      );

      test('an interceptor AuthFailure surfaces as its mapped reason', () async {
        // The interceptor rejects unrecoverable auth failures with a
        // DioException carrying AuthFailure(reason); the client decodes it.
        generatedClient.transcribeResponses.add(
          DioException(
            requestOptions: RequestOptions(path: '/api/transcribe'),
            error: const AuthFailure(BackendFailureReason.rateLimited),
          ),
        );

        final result = await backendClient.transcribeAudio(
          await _createTempAudioFile('auth-failure'),
        );

        expect(
          result,
          isA<TranscriptionFailure>().having(
            (value) => value.reason,
            'reason',
            BackendFailureReason.rateLimited,
          ),
        );
      });

      test(
        'quota 429 is not a credential failure and does not re-register',
        () async {
          generatedClient.transcribeResponses.add(
            const GeneratedApiFailure<TranscribeResponse>(
              statusCode: 429,
              data: <String, dynamic>{'error': 'Daily record limit exceeded'},
            ),
          );

          final result = await backendClient.transcribeAudio(
            await _createTempAudioFile('quota-429'),
          );

          expect(
            result,
            isA<TranscriptionFailure>().having(
              (value) => value.reason,
              'reason',
              BackendFailureReason.quotaExceeded,
            ),
          );
          expect(generatedClient.registerCallCount, 0);
          expect(generatedClient.transcribeCallCount, 1);
        },
      );

      test('token value never appears in results', () async {
        generatedClient.transcribeResponses.add(forbidden);

        final result = await backendClient.transcribeAudio(
          await _createTempAudioFile('no-leak'),
        );

        expect(result.toString(), isNot(contains('stored-token')));
      });

      test(
        'secure-storage write failure during registration still succeeds',
        () async {
          final client = WraitBackendClient(
            generatedClient: generatedClient,
            registrarClient: generatedClient,
            preferencesRepository: preferencesRepository,
            deviceTokenStore: DeviceTokenStore(_WriteFailingKeyValueStore()),
            delay: (duration) async => delayCalls.add(duration),
          );
          generatedClient.registerResponses.add(registered(token: 'issued'));

          final result = await client.register();

          // A failed persist must not fail registration.
          expect(result, isA<RegistrationSuccess>());
        },
      );
    });

    group('tagText', () {
      test('200 success maps tag probabilities', () async {
        generatedClient.tagTextResponses.add(
          const GeneratedApiSuccess<TagResponse>(
            statusCode: 200,
            data: TagResponse(
              tags: <TagProbabilityItem>[
                TagProbabilityItem(tag: 'work', probability: 0.9),
                TagProbabilityItem(tag: 'family', probability: 0.25),
              ],
            ),
          ),
        );

        final result = await backendClient.tagText(
          text: 'Had a long day at the office',
          tags: <String>['work', 'family'],
        );

        expect(result, isA<TagTextSuccess>());
        final tags = (result as TagTextSuccess).tags;
        expect(tags, hasLength(2));
        expect(tags[0].tag, 'work');
        expect(tags[0].probability, 0.9);
        expect(tags[1].tag, 'family');
        expect(tags[1].probability, 0.25);
        expect(generatedClient.tagTextCallCount, 1);
        expect(generatedClient.lastTagRequest?.tags, <String>[
          'work',
          'family',
        ]);
      });

      test('empty text after trim returns api error without a call', () async {
        final result = await backendClient.tagText(
          text: '   \n\t ',
          tags: <String>['work'],
        );

        expect(
          result,
          isA<TagTextFailure>().having(
            (value) => value.reason,
            'reason',
            BackendFailureReason.apiError,
          ),
        );
        expect(generatedClient.tagTextCallCount, 0);
      });

      test('text longer than the max length is truncated', () async {
        generatedClient.tagTextResponses.add(
          const GeneratedApiSuccess<TagResponse>(
            statusCode: 200,
            data: TagResponse(tags: <TagProbabilityItem>[]),
          ),
        );

        final result = await backendClient.tagText(
          text: 'a' * (tagTextMaxLength + 500),
          tags: <String>['work'],
        );

        expect(result, isA<TagTextSuccess>());
        expect(generatedClient.lastTagRequest?.text.length, tagTextMaxLength);
        expect(tagTextMaxLength, 10000);
      });

      test('400 maps to api error', () async {
        generatedClient.tagTextResponses.add(
          const GeneratedApiFailure<TagResponse>(
            statusCode: 400,
            data: <String, dynamic>{'error': 'bad request'},
          ),
        );

        final result = await backendClient.tagText(
          text: 'hello diary',
          tags: <String>['work'],
        );

        expect(
          result,
          isA<TagTextFailure>().having(
            (value) => value.reason,
            'reason',
            BackendFailureReason.apiError,
          ),
        );
      });

      test('401 maps to proxy auth failure', () async {
        generatedClient.tagTextResponses.add(
          const GeneratedApiFailure<TagResponse>(
            statusCode: 401,
            data: <String, dynamic>{'error': 'unauthorized'},
          ),
        );

        final result = await backendClient.tagText(
          text: 'hello diary',
          tags: <String>['work'],
        );

        expect(
          result,
          isA<TagTextFailure>().having(
            (value) => value.reason,
            'reason',
            BackendFailureReason.proxyAuthFailed,
          ),
        );
      });

      test('502 maps to backend unavailable', () async {
        generatedClient.tagTextResponses.add(
          const GeneratedApiFailure<TagResponse>(
            statusCode: 502,
            data: <String, dynamic>{'error': 'upstream exploded'},
          ),
        );

        final result = await backendClient.tagText(
          text: 'hello diary',
          tags: <String>['work'],
        );

        expect(
          result,
          isA<TagTextFailure>().having(
            (value) => value.reason,
            'reason',
            BackendFailureReason.backendUnavailable,
          ),
        );
      });

      test('504 maps to backend unavailable', () async {
        generatedClient.tagTextResponses.add(
          const GeneratedApiFailure<TagResponse>(
            statusCode: 504,
            data: <String, dynamic>{'error': 'upstream timeout'},
          ),
        );

        final result = await backendClient.tagText(
          text: 'hello diary',
          tags: <String>['work'],
        );

        expect(
          result,
          isA<TagTextFailure>().having(
            (value) => value.reason,
            'reason',
            BackendFailureReason.backendUnavailable,
          ),
        );
      });

      test('DioException timeout maps to timeout', () async {
        generatedClient.tagTextResponses.add(
          DioException(
            requestOptions: RequestOptions(path: '/api/tag'),
            type: DioExceptionType.receiveTimeout,
          ),
        );

        final result = await backendClient.tagText(
          text: 'hello diary',
          tags: <String>['work'],
        );

        expect(
          result,
          isA<TagTextFailure>().having(
            (value) => value.reason,
            'reason',
            BackendFailureReason.timeout,
          ),
        );
      });

      test('DioException connection error maps to no internet', () async {
        generatedClient.tagTextResponses.add(
          DioException(
            requestOptions: RequestOptions(path: '/api/tag'),
            type: DioExceptionType.connectionError,
            error: const SocketException('offline'),
          ),
        );

        final result = await backendClient.tagText(
          text: 'hello diary',
          tags: <String>['work'],
        );

        expect(
          result,
          isA<TagTextFailure>().having(
            (value) => value.reason,
            'reason',
            BackendFailureReason.noInternet,
          ),
        );
      });

      test('FormatException maps to api error', () async {
        generatedClient.tagTextResponses.add(
          const FormatException('malformed tag response'),
        );

        final result = await backendClient.tagText(
          text: 'hello diary',
          tags: <String>['work'],
        );

        expect(
          result,
          isA<TagTextFailure>().having(
            (value) => value.reason,
            'reason',
            BackendFailureReason.apiError,
          ),
        );
      });
    });
  });
}

class _FakeGeneratedBackendApiClient implements GeneratedBackendApiClient {
  final List<Object> registerResponses = <Object>[];
  final List<Object> transcribeResponses = <Object>[];
  final List<Object> cleanupResponses = <Object>[];
  final List<Object> tagTextResponses = <Object>[];

  final List<String?> registerTokens = <String?>[];
  final List<String> registerDeviceIds = <String>[];
  void Function()? onRegister;

  int registerCallCount = 0;
  int transcribeCallCount = 0;
  int tagTextCallCount = 0;
  TagRequest? lastTagRequest;
  String? lastTranscriptionLanguage;

  @override
  Future<GeneratedApiResponse<CleanupResponse>> cleanupTranscript({
    required CleanupRequest cleanupRequest,
  }) async {
    return _takeNext<GeneratedApiResponse<CleanupResponse>>(cleanupResponses);
  }

  @override
  Future<GeneratedApiResponse<RegisterResponse>> registerDevice({
    required String xDeviceId,
    String? xDeviceToken,
  }) async {
    registerCallCount += 1;
    registerTokens.add(xDeviceToken);
    registerDeviceIds.add(xDeviceId);
    onRegister?.call();
    return _takeNext<GeneratedApiResponse<RegisterResponse>>(registerResponses);
  }

  @override
  Future<GeneratedApiResponse<TranscribeResponse>> transcribeAudio({
    required List<int> audioBytes,
    required String audioFilename,
    String? language,
  }) async {
    transcribeCallCount += 1;
    lastTranscriptionLanguage = language;
    return _takeNext<GeneratedApiResponse<TranscribeResponse>>(
      transcribeResponses,
    );
  }

  @override
  Future<GeneratedApiResponse<TagResponse>> tagText({
    required TagRequest tagRequest,
  }) async {
    tagTextCallCount += 1;
    lastTagRequest = tagRequest;
    return _takeNext<GeneratedApiResponse<TagResponse>>(tagTextResponses);
  }

  Future<T> _takeNext<T>(List<Object> values) async {
    if (values.isEmpty) {
      throw StateError('No queued response left for fake generated client.');
    }

    final next = values.removeAt(0);
    if (next is Exception) {
      throw next;
    }

    return next as T;
  }
}

class _FakePreferencesRepository implements PreferencesRepository {
  final String deviceId =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  @override
  Future<String> getDeviceId() async => deviceId;

  @override
  Future<bool> getHasEverRecorded() async => false;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}

Future<File> _createTempAudioFile(String name) async {
  final directory = await Directory.systemTemp.createTemp('wrait-backend-test');
  final file = File('${directory.path}/$name.m4a');
  await file.writeAsString('audio-data-$name');
  return file;
}

class _WriteFailingKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('keystore write failed');

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

