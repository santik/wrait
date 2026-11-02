import 'package:local_auth/local_auth.dart';

enum AppLockAvailability {
  available,
  noSecurityConfigured,
  temporarilyUnavailable,
  unavailable,
}

enum AppLockAuthResult {
  success,
  canceled,
  noSecurityConfigured,
  temporarilyUnavailable,
  unavailable,
}

abstract interface class AppLockAuthenticator {
  Future<AppLockAvailability> availability();
  Future<AppLockAuthResult> authenticate({required String localizedReason});
  Future<void> cancel();
}

typedef AppLockLogWarning = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

abstract interface class LocalAuthClient {
  Future<bool> isDeviceSupported();
  Future<bool> authenticate({required String localizedReason});
  Future<bool> stopAuthentication();
}

class LocalAuthenticationClient implements LocalAuthClient {
  LocalAuthenticationClient({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> isDeviceSupported() {
    return _authentication.isDeviceSupported();
  }

  @override
  Future<bool> authenticate({required String localizedReason}) {
    return _authentication.authenticate(
      localizedReason: localizedReason,
      persistAcrossBackgrounding: false,
      sensitiveTransaction: true,
    );
  }

  @override
  Future<bool> stopAuthentication() async {
    return _authentication.stopAuthentication();
  }
}

class LocalAuthAppLockAuthenticator implements AppLockAuthenticator {
  LocalAuthAppLockAuthenticator({
    LocalAuthClient? client,
    this._authenticationTimeout = const Duration(seconds: 30),
    this._logWarning,
  }) : _client = client ?? LocalAuthenticationClient();

  final LocalAuthClient _client;
  final Duration _authenticationTimeout;
  final AppLockLogWarning? _logWarning;

  @override
  Future<AppLockAvailability> availability() async {
    try {
      final isSupported = await _client.isDeviceSupported();
      if (isSupported) {
        return AppLockAvailability.available;
      }

      return AppLockAvailability.noSecurityConfigured;
    } on LocalAuthException catch (error, stackTrace) {
      final availability = _mapAvailabilityException(error.code);
      _logWarning?.call(
        'App lock availability check failed with ${error.code.name}.',
        error: error,
        stackTrace: stackTrace,
      );
      return availability;
    } catch (_) {
      return AppLockAvailability.unavailable;
    }
  }

  @override
  Future<AppLockAuthResult> authenticate({
    required String localizedReason,
  }) async {
    final availability = await this.availability();
    if (availability != AppLockAvailability.available) {
      final result = switch (availability) {
        AppLockAvailability.noSecurityConfigured =>
          AppLockAuthResult.noSecurityConfigured,
        AppLockAvailability.temporarilyUnavailable =>
          AppLockAuthResult.temporarilyUnavailable,
        AppLockAvailability.unavailable => AppLockAuthResult.unavailable,
        AppLockAvailability.available => AppLockAuthResult.unavailable,
      };
      _logResult(result);
      return result;
    }

    try {
      final didAuthenticate = await _client
          .authenticate(localizedReason: localizedReason)
          .timeout(
            _authenticationTimeout,
            onTimeout: () async {
              await _stopAuthenticationBestEffort();
              throw const _AppLockAuthenticationTimedOut();
            },
          );
      final result = didAuthenticate
          ? AppLockAuthResult.success
          : AppLockAuthResult.canceled;
      _logResult(result);
      return result;
    } on _AppLockAuthenticationTimedOut catch (error, stackTrace) {
      _logWarning?.call(
        'App lock authentication timed out.',
        error: error,
        stackTrace: stackTrace,
      );
      return AppLockAuthResult.temporarilyUnavailable;
    } on LocalAuthException catch (error, stackTrace) {
      final result = _mapAuthenticationException(error.code);
      _logWarning?.call(
        'App lock authentication failed with ${error.code.name}.',
        error: error,
        stackTrace: stackTrace,
      );
      return result;
    } catch (error, stackTrace) {
      _logWarning?.call(
        'App lock authentication failed with an unexpected error.',
        error: error,
        stackTrace: stackTrace,
      );
      return AppLockAuthResult.unavailable;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _client.stopAuthentication();
    } catch (_) {
      // Best-effort cancellation only.
    }
  }

  Future<void> _stopAuthenticationBestEffort() async {
    try {
      await _client.stopAuthentication();
    } catch (_) {
      // Best-effort cancellation only.
    }
  }

  void _logResult(AppLockAuthResult result) {
    if (result == AppLockAuthResult.success) {
      return;
    }

    _logWarning?.call('App lock authentication result: ${result.name}.');
  }

  AppLockAvailability _mapAvailabilityException(LocalAuthExceptionCode code) {
    return switch (code) {
      LocalAuthExceptionCode.noCredentialsSet ||
      LocalAuthExceptionCode.noBiometricHardware ||
      LocalAuthExceptionCode.noBiometricsEnrolled =>
        AppLockAvailability.noSecurityConfigured,
      LocalAuthExceptionCode.authInProgress ||
      LocalAuthExceptionCode.uiUnavailable ||
      LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
      LocalAuthExceptionCode.temporaryLockout ||
      LocalAuthExceptionCode.biometricLockout ||
      LocalAuthExceptionCode.deviceError =>
        AppLockAvailability.temporarilyUnavailable,
      _ => AppLockAvailability.unavailable,
    };
  }

  AppLockAuthResult _mapAuthenticationException(LocalAuthExceptionCode code) {
    return switch (code) {
      LocalAuthExceptionCode.userCanceled ||
      LocalAuthExceptionCode.systemCanceled ||
      LocalAuthExceptionCode.timeout ||
      LocalAuthExceptionCode.userRequestedFallback =>
        AppLockAuthResult.canceled,
      LocalAuthExceptionCode.noCredentialsSet ||
      LocalAuthExceptionCode.noBiometricHardware ||
      LocalAuthExceptionCode.noBiometricsEnrolled =>
        AppLockAuthResult.noSecurityConfigured,
      LocalAuthExceptionCode.authInProgress ||
      LocalAuthExceptionCode.uiUnavailable ||
      LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
      LocalAuthExceptionCode.temporaryLockout ||
      LocalAuthExceptionCode.biometricLockout ||
      LocalAuthExceptionCode.deviceError =>
        AppLockAuthResult.temporarilyUnavailable,
      _ => AppLockAuthResult.unavailable,
    };
  }
}

class _AppLockAuthenticationTimedOut implements Exception {
  const _AppLockAuthenticationTimedOut();
}
