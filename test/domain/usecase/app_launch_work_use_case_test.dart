import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/domain/usecase/app_launch_work_use_case.dart';
import 'package:wrait/domain/usecase/register_device_on_launch_use_case.dart';

void main() {
  late List<String> logMessages;
  late List<Object?> logErrors;
  late Future<LaunchDeviceRegistrationResult> Function() registerDeviceOnLaunch;
  late int retryCallCount;
  late Future<void> Function() retryPendingDrafts;
  late AppLaunchWorkUseCase useCase;

  setUp(() {
    logMessages = <String>[];
    logErrors = <Object?>[];
    registerDeviceOnLaunch = () async => LaunchDeviceRegistrationResult.success;
    retryCallCount = 0;
    retryPendingDrafts = () async {
      retryCallCount += 1;
    };
    useCase = AppLaunchWorkUseCase(
      registerDeviceOnLaunch: _StubRegisterDeviceOnLaunchUseCase(
        callImpl: () => registerDeviceOnLaunch(),
      ),
      retryPendingDrafts: () => retryPendingDrafts(),
      logWarning: (message, {error, stackTrace}) {
        logMessages.add(message);
        logErrors.add(error);
      },
    );
  });

  test('launch work retries drafts after successful registration', () async {
    await useCase();

    expect(retryCallCount, 1);
    expect(logMessages, isEmpty);
  });

  test('launch work skips draft retry after failed registration', () async {
    registerDeviceOnLaunch = () async => LaunchDeviceRegistrationResult.failure;

    await useCase();

    expect(retryCallCount, 0);
    expect(logMessages, isEmpty);
  });

  test('launch work logs and swallows retry exceptions', () async {
    retryPendingDrafts = () async {
      retryCallCount += 1;
      throw StateError('retry failed');
    };

    await useCase();

    expect(retryCallCount, 1);
    expect(logMessages.single, contains('Draft retry crashed'));
    expect(logErrors.single, isA<StateError>());
  });

  test('launch work uses a single in-flight execution', () async {
    final completer = Completer<LaunchDeviceRegistrationResult>();
    registerDeviceOnLaunch = () => completer.future;

    final firstCall = useCase();
    final secondCall = useCase();

    completer.complete(LaunchDeviceRegistrationResult.success);
    await Future.wait<void>(<Future<void>>[firstCall, secondCall]);

    expect(retryCallCount, 1);
  });
}

class _StubRegisterDeviceOnLaunchUseCase extends RegisterDeviceOnLaunchUseCase {
  _StubRegisterDeviceOnLaunchUseCase({required this.callImpl})
    : super(
        registerDevice: () async {
          throw UnimplementedError();
        },
        setRecordQuota: (_) {},
        logWarning: (_, {error, stackTrace}) {},
      );

  final Future<LaunchDeviceRegistrationResult> Function() callImpl;

  @override
  Future<LaunchDeviceRegistrationResult> call() => callImpl();
}
