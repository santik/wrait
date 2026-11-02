import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/api/backend_client.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/launch/app_launch_providers.dart';
import 'package:wrait/data/preferences/platform_device_id_provider.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/preferences/preferences_repository_impl.dart';
import 'package:wrait/domain/usecase/app_launch_work_use_case.dart';
import 'package:wrait/main.dart';
import 'package:wrait/presentation/main/main_screen_test_keys.dart';

import 'support/microphone_test_overrides.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'launch registration is non-blocking and updates session quota on success',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var retryCallCount = 0;

      final requests = <_ObservedRequest>[];
      final requestSeen = Completer<void>();
      final releaseResponse = Completer<void>();
      final serverFuture = _serveBackend(
        server,
        requests,
        onRegister: (request) async {
          if (!requestSeen.isCompleted) {
            requestSeen.complete();
          }
          await releaseResponse.future;
          return _StubResponse.created(
            '{"ok":true,"quota":{"limit":5,"count":1,"remaining":4,"resetAt":"2026-06-10T00:00:00Z"}}',
          );
        },
      );
      addTearDown(() async {
        if (!releaseResponse.isCompleted) {
          releaseResponse.complete();
        }
        await server.close(force: true);
        await serverFuture;
      });

      final container = createAppContainer(
        appConfig: AppConfig.fromValues(
          backendUrl: 'http://${server.address.host}:${server.port}',
          proxySecret: 'proxy-secret',
        ),
        sharedPreferences: sharedPreferences,
        overrides: [
          ...grantedMicrophoneOverrides,
          appLockEnabledProvider.overrideWithValue(false),
          platformDeviceIdProvider.overrideWithValue(
            const _FakePlatformDeviceIdProvider('platform-device-id'),
          ),
          appLaunchWorkUseCaseProvider.overrideWith(
            (ref) => AppLaunchWorkUseCase(
              registerDeviceOnLaunch: ref.watch(
                registerDeviceOnLaunchUseCaseProvider,
              ),
              retryPendingDrafts: () async {
                retryCallCount += 1;
              },
              logWarning: (_, {error, stackTrace}) {},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      startAppLaunchWork(container);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const WraitApp(),
        ),
      );
      await tester.pump();

      _expectMainLaunchUiVisible();
      await _pumpUntil(tester, () => requestSeen.isCompleted);
      expect(container.read(sessionRecordQuotaStateProvider), isNull);

      releaseResponse.complete();
      await _pumpUntil(
        tester,
        () => container.read(sessionRecordQuotaStateProvider) != null,
      );

      final quota = container.read(sessionRecordQuotaStateProvider);
      final storedDeviceId = sharedPreferences.getString(
        PreferencesRepositoryImpl.deviceIdKey,
      );

      expect(quota?.remaining, 4);
      expect(storedDeviceId, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(requests.single.deviceId, storedDeviceId);
      expect(retryCallCount, 1);
    },
  );

  testWidgets(
    'a new launch reuses the stored device id but starts with fresh in-memory quota state',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var retryCallCount = 0;

      final requests = <_ObservedRequest>[];
      var registerCount = 0;
      final serverFuture = _serveBackend(
        server,
        requests,
        onRegister: (request) async {
          registerCount += 1;
          final remaining = registerCount == 1 ? 4 : 3;
          return _StubResponse.created(
            '{"ok":true,"quota":{"limit":5,"count":$registerCount,"remaining":$remaining,"resetAt":"2026-06-10T00:00:00Z"}}',
          );
        },
      );
      addTearDown(() async {
        await server.close(force: true);
        await serverFuture;
      });

      final firstContainer = createAppContainer(
        appConfig: AppConfig.fromValues(
          backendUrl: 'http://${server.address.host}:${server.port}',
          proxySecret: 'proxy-secret',
        ),
        sharedPreferences: sharedPreferences,
        overrides: [
          ...grantedMicrophoneOverrides,
          appLockEnabledProvider.overrideWithValue(false),
          platformDeviceIdProvider.overrideWithValue(
            const _FakePlatformDeviceIdProvider('first-platform-device'),
          ),
          appLaunchWorkUseCaseProvider.overrideWith(
            (ref) => AppLaunchWorkUseCase(
              registerDeviceOnLaunch: ref.watch(
                registerDeviceOnLaunchUseCaseProvider,
              ),
              retryPendingDrafts: () async {
                retryCallCount += 1;
              },
              logWarning: (_, {error, stackTrace}) {},
            ),
          ),
        ],
      );

      startAppLaunchWork(firstContainer);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: firstContainer,
          child: const WraitApp(),
        ),
      );
      await _pumpUntil(
        tester,
        () => firstContainer.read(sessionRecordQuotaStateProvider) != null,
      );

      final firstLaunchDeviceId = requests.single.deviceId;
      expect(
        firstContainer.read(sessionRecordQuotaStateProvider)?.remaining,
        4,
      );

      firstContainer.dispose();

      final secondContainer = createAppContainer(
        appConfig: AppConfig.fromValues(
          backendUrl: 'http://${server.address.host}:${server.port}',
          proxySecret: 'proxy-secret',
        ),
        sharedPreferences: sharedPreferences,
        overrides: [
          ...grantedMicrophoneOverrides,
          appLockEnabledProvider.overrideWithValue(false),
          platformDeviceIdProvider.overrideWithValue(
            const _FakePlatformDeviceIdProvider('second-platform-device'),
          ),
          appLaunchWorkUseCaseProvider.overrideWith(
            (ref) => AppLaunchWorkUseCase(
              registerDeviceOnLaunch: ref.watch(
                registerDeviceOnLaunchUseCaseProvider,
              ),
              retryPendingDrafts: () async {
                retryCallCount += 1;
              },
              logWarning: (_, {error, stackTrace}) {},
            ),
          ),
        ],
      );
      addTearDown(secondContainer.dispose);

      expect(secondContainer.read(sessionRecordQuotaStateProvider), isNull);

      startAppLaunchWork(secondContainer);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: secondContainer,
          child: const WraitApp(),
        ),
      );
      await _pumpUntil(
        tester,
        () =>
            requests.length == 2 &&
            secondContainer.read(sessionRecordQuotaStateProvider) != null,
      );

      expect(requests, hasLength(2));
      expect(requests[1].deviceId, firstLaunchDeviceId);
      expect(
        secondContainer.read(sessionRecordQuotaStateProvider)?.remaining,
        3,
      );
      expect(retryCallCount, 2);
    },
  );

  testWidgets(
    'transient launch registration failure is non-blocking and preserves quota',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var retryCallCount = 0;

      final requests = <_ObservedRequest>[];
      final serverFuture = _serveBackend(
        server,
        requests,
        onRegister: (request) async =>
            _StubResponse.json(500, '{"error":"temporary backend failure"}'),
      );
      addTearDown(() async {
        await server.close(force: true);
        await serverFuture;
      });

      final container = createAppContainer(
        appConfig: AppConfig.fromValues(
          backendUrl: 'http://${server.address.host}:${server.port}',
          proxySecret: 'proxy-secret',
        ),
        sharedPreferences: sharedPreferences,
        overrides: [
          ...grantedMicrophoneOverrides,
          appLockEnabledProvider.overrideWithValue(false),
          platformDeviceIdProvider.overrideWithValue(
            const _FakePlatformDeviceIdProvider('platform-device-id'),
          ),
          appLaunchWorkUseCaseProvider.overrideWith(
            (ref) => AppLaunchWorkUseCase(
              registerDeviceOnLaunch: ref.watch(
                registerDeviceOnLaunchUseCaseProvider,
              ),
              retryPendingDrafts: () async {
                retryCallCount += 1;
              },
              logWarning: (_, {error, stackTrace}) {},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(sessionRecordQuotaStateProvider.notifier)
          .setQuota(_TestQuotaState());

      startAppLaunchWork(container);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const WraitApp(),
        ),
      );
      await tester.pump();

      _expectMainLaunchUiVisible();
      await _pumpUntil(
        tester,
        () => requests.length == WraitBackendClient.maxRegisterAttempts,
        timeout: const Duration(seconds: 5),
        step: const Duration(milliseconds: 100),
      );

      expect(requests, hasLength(WraitBackendClient.maxRegisterAttempts));
      expect(container.read(sessionRecordQuotaStateProvider)?.remaining, 4);
      expect(retryCallCount, 0);
    },
  );
}

void _expectMainLaunchUiVisible() {
  expect(find.byKey(mainActionButtonKey), findsOneWidget);
  expect(find.byKey(mainStatusLineSlotKey), findsOneWidget);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
  Duration step = const Duration(milliseconds: 10),
}) async {
  final endTime = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(endTime)) {
    if (condition()) {
      return;
    }
    await tester.pump(step);
  }

  if (!condition()) {
    fail('Timed out waiting for condition after $timeout.');
  }
}

Future<void> _serveBackend(
  HttpServer server,
  List<_ObservedRequest> requests, {
  required Future<_StubResponse> Function(_ObservedRequest request) onRegister,
}) async {
  await for (final request in server) {
    final bodyBytes = await request.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    final observed = _ObservedRequest(
      path: request.uri.path,
      deviceId: request.headers.value('X-Device-Id'),
      proxySecret: request.headers.value('X-Proxy-Secret'),
      jsonBody:
          request.headers.contentType?.mimeType == ContentType.json.mimeType
          ? jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>
          : null,
    );
    requests.add(observed);

    final response = switch (request.uri.path) {
      '/api/register' => await onRegister(observed),
      _ => _StubResponse.json(404, '{"error":"not found"}'),
    };

    request.response.statusCode = response.statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(response.body);
    await request.response.close();
  }
}

class _ObservedRequest {
  const _ObservedRequest({
    required this.path,
    required this.deviceId,
    required this.proxySecret,
    required this.jsonBody,
  });

  final String path;
  final String? deviceId;
  final String? proxySecret;
  final Map<String, dynamic>? jsonBody;
}

class _StubResponse {
  const _StubResponse._({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  factory _StubResponse.created(String body) =>
      _StubResponse._(statusCode: 201, body: body);

  factory _StubResponse.json(int statusCode, String body) =>
      _StubResponse._(statusCode: statusCode, body: body);
}

class _FakePlatformDeviceIdProvider implements PlatformDeviceIdProvider {
  const _FakePlatformDeviceIdProvider(this.value);

  final String value;

  @override
  Future<String?> getPlatformDeviceId() async => value;
}

class _TestQuotaState extends RecordQuotaState {
  _TestQuotaState()
    : super(
        limit: 5,
        count: 1,
        remaining: 4,
        resetAt: DateTime.utc(2026, 6, 10),
      );
}
