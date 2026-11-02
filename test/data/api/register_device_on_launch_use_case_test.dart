import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/api/backend_results.dart';
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/domain/usecase/register_device_on_launch_use_case.dart';

void main() {
  late RecordQuotaState? currentQuota;
  late List<String> logMessages;
  late List<Object?> logErrors;
  late RegisterDeviceOnLaunchUseCase useCase;
  late Future<RegistrationResult> Function() registerDevice;

  setUp(() {
    currentQuota = RecordQuotaState(
      limit: 5,
      count: 1,
      remaining: 4,
      resetAt: DateTime.utc(2026, 6, 10),
    );
    logMessages = <String>[];
    logErrors = <Object?>[];
    registerDevice = () async => const RegistrationSuccess();
    useCase = RegisterDeviceOnLaunchUseCase(
      registerDevice: () => registerDevice(),
      setRecordQuota: (quota) => currentQuota = quota,
      logWarning: (message, {error, stackTrace}) {
        logMessages.add(message);
        logErrors.add(error);
      },
    );
  });

  test(
    'replaces in-memory quota on successful registration with valid quota',
    () async {
      final updatedQuota = RecordQuotaState(
        limit: 6,
        count: 2,
        remaining: 4,
        resetAt: DateTime.utc(2026, 6, 11),
      );
      registerDevice = () async => RegistrationSuccess(quota: updatedQuota);

      final result = await useCase();

      expect(result, LaunchDeviceRegistrationResult.success);
      expect(currentQuota, updatedQuota);
      expect(logMessages, isEmpty);
    },
  );

  test('preserves the previous in-memory quota when success exposes no usable quota', () async {
    registerDevice = () async => const RegistrationSuccess();

    final result = await useCase();

    expect(result, LaunchDeviceRegistrationResult.success);
    expect(currentQuota?.remaining, 4);
    expect(logMessages, isEmpty);
  });

  test(
    'logs and swallows registration failures without clearing quota',
    () async {
      registerDevice = () async =>
          const RegistrationFailure(RegistrationFailureReason.transient);

      final result = await useCase();

      expect(result, LaunchDeviceRegistrationResult.failure);
      expect(currentQuota?.remaining, 4);
      expect(logMessages, hasLength(1));
      expect(logMessages.single, contains('transient'));
      expect(logErrors.single, isNull);
    },
  );

  test(
    'logs and swallows unexpected exceptions without clearing quota',
    () async {
      registerDevice = () async => throw StateError('boom');

      final result = await useCase();

      expect(result, LaunchDeviceRegistrationResult.failure);
      expect(currentQuota?.remaining, 4);
      expect(logMessages, hasLength(1));
      expect(logMessages.single, contains('crashed'));
      expect(logErrors.single, isA<StateError>());
    },
  );
}
