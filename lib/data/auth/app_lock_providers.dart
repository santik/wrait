import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_authenticator.dart';
import 'device_security_settings_opener.dart';
import '../preferences/app_lock_preference_controller.dart';

const _appLockEnabledDefine = 'APP_LOCK_ENABLED';
const _appLockBuildEnabled = bool.fromEnvironment(
  _appLockEnabledDefine,
  defaultValue: true,
);

/// Explicit false remains a validation escape hatch. Normal builds use the
/// user's persisted opt-in choice.
final appLockBuildEnabledProvider = Provider<bool>(
  (ref) => _appLockBuildEnabled,
);

/// Conservative while the preference is unknown; [AppLockGate] separately
/// owns the opaque loading/error cover and never authenticates until ready.
final appLockEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(appLockBuildEnabledProvider)) {
    return false;
  }
  final preference = ref.watch(appLockPreferenceControllerProvider);
  return preference.isReady ? preference.enabled : true;
});

final appLockWarningLoggerProvider = Provider<AppLockLogWarning>((ref) {
  return (message, {error, stackTrace}) {
    developer.log(
      message,
      name: 'AppLock',
      error: error,
      stackTrace: stackTrace,
    );
  };
});

final appLockAuthenticatorProvider = Provider<AppLockAuthenticator>((ref) {
  return LocalAuthAppLockAuthenticator(
    logWarning: ref.read(appLockWarningLoggerProvider),
  );
});

final deviceSecuritySettingsOpenerProvider =
    Provider<DeviceSecuritySettingsOpener>((ref) {
      return BestEffortDeviceSecuritySettingsOpener();
    });
