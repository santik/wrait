import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:wrait/data/auth/app_lock_authenticator.dart';

void main() {
  test(
    'availability reports available when device auth is supported',
    () async {
      final authenticator = LocalAuthAppLockAuthenticator(
        client: _FakeLocalAuthClient(isDeviceSupportedResult: true),
      );

      expect(await authenticator.availability(), AppLockAvailability.available);
    },
  );

  test(
    'availability reports no security configured when unsupported',
    () async {
      final authenticator = LocalAuthAppLockAuthenticator(
        client: _FakeLocalAuthClient(isDeviceSupportedResult: false),
      );

      expect(
        await authenticator.availability(),
        AppLockAvailability.noSecurityConfigured,
      );
    },
  );

  test('authenticate reports success and cancel results', () async {
    final successAuthenticator = LocalAuthAppLockAuthenticator(
      client: _FakeLocalAuthClient(
        isDeviceSupportedResult: true,
        authenticateResult: true,
      ),
    );
    final cancelAuthenticator = LocalAuthAppLockAuthenticator(
      client: _FakeLocalAuthClient(
        isDeviceSupportedResult: true,
        authenticateResult: false,
      ),
    );

    expect(
      await successAuthenticator.authenticate(localizedReason: 'reason'),
      AppLockAuthResult.success,
    );
    expect(
      await cancelAuthenticator.authenticate(localizedReason: 'reason'),
      AppLockAuthResult.canceled,
    );
  });

  test('availability maps explicit local auth exception codes', () async {
    final expectedAvailability = <LocalAuthExceptionCode, AppLockAvailability>{
      LocalAuthExceptionCode.noCredentialsSet:
          AppLockAvailability.noSecurityConfigured,
      LocalAuthExceptionCode.noBiometricsEnrolled:
          AppLockAvailability.noSecurityConfigured,
      LocalAuthExceptionCode.noBiometricHardware:
          AppLockAvailability.noSecurityConfigured,
      LocalAuthExceptionCode.authInProgress:
          AppLockAvailability.temporarilyUnavailable,
      LocalAuthExceptionCode.uiUnavailable:
          AppLockAvailability.temporarilyUnavailable,
      LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          AppLockAvailability.temporarilyUnavailable,
      LocalAuthExceptionCode.temporaryLockout:
          AppLockAvailability.temporarilyUnavailable,
      LocalAuthExceptionCode.biometricLockout:
          AppLockAvailability.temporarilyUnavailable,
      LocalAuthExceptionCode.deviceError:
          AppLockAvailability.temporarilyUnavailable,
      LocalAuthExceptionCode.unknownError: AppLockAvailability.unavailable,
    };

    for (final entry in expectedAvailability.entries) {
      final authenticator = LocalAuthAppLockAuthenticator(
        client: _FakeLocalAuthClient(
          isDeviceSupportedResult: true,
          isDeviceSupportedError: LocalAuthException(code: entry.key),
        ),
      );

      expect(await authenticator.availability(), entry.value);
    }
  });

  test('authenticate maps explicit local auth exception codes', () async {
    final expectedResult = <LocalAuthExceptionCode, AppLockAuthResult>{
      LocalAuthExceptionCode.userCanceled: AppLockAuthResult.canceled,
      LocalAuthExceptionCode.timeout: AppLockAuthResult.canceled,
      LocalAuthExceptionCode.systemCanceled: AppLockAuthResult.canceled,
      LocalAuthExceptionCode.userRequestedFallback: AppLockAuthResult.canceled,
      LocalAuthExceptionCode.noCredentialsSet:
          AppLockAuthResult.noSecurityConfigured,
      LocalAuthExceptionCode.noBiometricsEnrolled:
          AppLockAuthResult.noSecurityConfigured,
      LocalAuthExceptionCode.noBiometricHardware:
          AppLockAuthResult.noSecurityConfigured,
      LocalAuthExceptionCode.authInProgress:
          AppLockAuthResult.temporarilyUnavailable,
      LocalAuthExceptionCode.uiUnavailable:
          AppLockAuthResult.temporarilyUnavailable,
      LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          AppLockAuthResult.temporarilyUnavailable,
      LocalAuthExceptionCode.temporaryLockout:
          AppLockAuthResult.temporarilyUnavailable,
      LocalAuthExceptionCode.biometricLockout:
          AppLockAuthResult.temporarilyUnavailable,
      LocalAuthExceptionCode.deviceError:
          AppLockAuthResult.temporarilyUnavailable,
      LocalAuthExceptionCode.unknownError: AppLockAuthResult.unavailable,
    };

    for (final entry in expectedResult.entries) {
      final authenticator = LocalAuthAppLockAuthenticator(
        client: _FakeLocalAuthClient(
          isDeviceSupportedResult: true,
          authenticateError: LocalAuthException(code: entry.key),
        ),
      );

      expect(
        await authenticator.authenticate(localizedReason: 'reason'),
        entry.value,
      );
    }
  });

  test('authenticate maps unknown errors to unavailable', () async {
    final authenticator = LocalAuthAppLockAuthenticator(
      client: _FakeLocalAuthClient(
        isDeviceSupportedResult: true,
        authenticateError: const LocalAuthException(
          code: LocalAuthExceptionCode.unknownError,
        ),
      ),
    );

    expect(
      await authenticator.authenticate(localizedReason: 'reason'),
      AppLockAuthResult.unavailable,
    );
  });

  test(
    'authenticate times out, cancels auth, and reports unavailable retry',
    () async {
      final client = _FakeLocalAuthClient(
        isDeviceSupportedResult: true,
        authenticateCompleter: Completer<bool>(),
      );
      final authenticator = LocalAuthAppLockAuthenticator(
        client: client,
        authenticationTimeout: const Duration(milliseconds: 1),
      );

      expect(
        await authenticator.authenticate(localizedReason: 'reason'),
        AppLockAuthResult.temporarilyUnavailable,
      );
      expect(client.stopAuthenticationCallCount, 1);
    },
  );

  test('cancel delegates stopAuthentication best-effort', () async {
    final client = _FakeLocalAuthClient(isDeviceSupportedResult: true);
    final authenticator = LocalAuthAppLockAuthenticator(client: client);

    await authenticator.cancel();

    expect(client.stopAuthenticationCallCount, 1);
  });
}

class _FakeLocalAuthClient implements LocalAuthClient {
  _FakeLocalAuthClient({
    required this.isDeviceSupportedResult,
    this.authenticateResult = true,
    this.isDeviceSupportedError,
    this.authenticateError,
    this.authenticateCompleter,
  });

  final bool isDeviceSupportedResult;
  final bool authenticateResult;
  final Object? isDeviceSupportedError;
  final Object? authenticateError;
  final Completer<bool>? authenticateCompleter;
  int stopAuthenticationCallCount = 0;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    final completer = authenticateCompleter;
    if (completer != null) {
      return completer.future;
    }
    final error = authenticateError;
    if (error != null) {
      throw error;
    }
    return authenticateResult;
  }

  @override
  Future<bool> isDeviceSupported() async {
    final error = isDeviceSupportedError;
    if (error != null) {
      throw error;
    }
    return isDeviceSupportedResult;
  }

  @override
  Future<bool> stopAuthentication() async {
    stopAuthenticationCallCount += 1;
    return true;
  }
}
