import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/app_lock_authenticator.dart';
import '../../data/auth/app_lock_providers.dart';
import '../../data/auth/device_security_settings_opener.dart';

enum AppLockStatus {
  locked,
  authenticating,
  canceled,
  noSecurity,
  temporarilyUnavailable,
  unavailable,
  unlocked,
}

class AppLockState {
  const AppLockState({
    required this.status,
    required this.isLocked,
    required this.isPromptPending,
    required this.shouldPromptOnForeground,
  });

  const AppLockState.locked({
    AppLockStatus status = AppLockStatus.locked,
    bool isPromptPending = false,
    bool shouldPromptOnForeground = true,
  }) : this(
         status: status,
         isLocked: true,
         isPromptPending: isPromptPending,
         shouldPromptOnForeground: shouldPromptOnForeground,
       );

  const AppLockState.unlocked()
    : this(
        status: AppLockStatus.unlocked,
        isLocked: false,
        isPromptPending: false,
        shouldPromptOnForeground: false,
      );

  final AppLockStatus status;
  final bool isLocked;
  final bool isPromptPending;
  final bool shouldPromptOnForeground;

  bool get canOpenSettings => status == AppLockStatus.noSecurity;
  bool get canBypass => status == AppLockStatus.noSecurity;

  AppLockState copyWith({
    AppLockStatus? status,
    bool? isLocked,
    bool? isPromptPending,
    bool? shouldPromptOnForeground,
  }) {
    return AppLockState(
      status: status ?? this.status,
      isLocked: isLocked ?? this.isLocked,
      isPromptPending: isPromptPending ?? this.isPromptPending,
      shouldPromptOnForeground:
          shouldPromptOnForeground ?? this.shouldPromptOnForeground,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppLockState &&
        other.status == status &&
        other.isLocked == isLocked &&
        other.isPromptPending == isPromptPending &&
        other.shouldPromptOnForeground == shouldPromptOnForeground;
  }

  @override
  int get hashCode =>
      Object.hash(status, isLocked, isPromptPending, shouldPromptOnForeground);
}

final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);

class AppLockController extends Notifier<AppLockState> {
  AppLockAuthenticator get _authenticator =>
      ref.read(appLockAuthenticatorProvider);
  DeviceSecuritySettingsOpener get _settingsOpener =>
      ref.read(deviceSecuritySettingsOpenerProvider);
  AppLockLogWarning get _logWarning => ref.read(appLockWarningLoggerProvider);

  int _authAttemptId = 0;
  bool _isOpeningSecuritySettings = false;

  @override
  AppLockState build() {
    final authenticator = _authenticator;
    ref.onDispose(() {
      unawaited(authenticator.cancel());
    });
    return const AppLockState.locked();
  }

  void lockForForegroundExit() {
    _authAttemptId += 1;
    unawaited(_authenticator.cancel());
    state = const AppLockState.locked();
  }

  void startEnabledSession({required bool shouldLock}) {
    _authAttemptId += 1;
    unawaited(_authenticator.cancel());
    state = shouldLock
        ? const AppLockState.locked()
        : const AppLockState.unlocked();
  }

  void disableSession() {
    _authAttemptId += 1;
    unawaited(_authenticator.cancel());
    state = const AppLockState.unlocked();
  }

  Future<void> onForegroundReady() async {
    if (!state.isLocked || !state.shouldPromptOnForeground) {
      return;
    }

    await unlock();
  }

  Future<void> unlock() async {
    if (!state.isLocked || state.isPromptPending) {
      return;
    }

    final attemptId = ++_authAttemptId;
    state = state.copyWith(
      status: AppLockStatus.authenticating,
      isPromptPending: true,
      shouldPromptOnForeground: false,
    );

    final result = await _authenticator.authenticate(
      localizedReason: 'Unlock Wrait to continue.',
    );
    if (!ref.mounted) {
      return;
    }
    if (attemptId != _authAttemptId) {
      return;
    }

    switch (result) {
      case AppLockAuthResult.success:
        state = const AppLockState.unlocked();
      case AppLockAuthResult.canceled:
        state = const AppLockState.locked(
          status: AppLockStatus.canceled,
          shouldPromptOnForeground: false,
        );
      case AppLockAuthResult.noSecurityConfigured:
        state = const AppLockState.locked(
          status: AppLockStatus.noSecurity,
          shouldPromptOnForeground: false,
        );
      case AppLockAuthResult.temporarilyUnavailable:
        state = const AppLockState.locked(
          status: AppLockStatus.temporarilyUnavailable,
          shouldPromptOnForeground: false,
        );
      case AppLockAuthResult.unavailable:
        state = const AppLockState.locked(
          status: AppLockStatus.unavailable,
          shouldPromptOnForeground: false,
        );
    }
  }

  Future<void> openSecuritySettings() async {
    if (_isOpeningSecuritySettings) {
      return;
    }

    _isOpeningSecuritySettings = true;
    try {
      final opened = await _settingsOpener.openDeviceSecuritySettings();
      if (!opened) {
        _logWarning('Failed to open device security settings.');
      }
    } catch (error, stackTrace) {
      _logWarning(
        'Failed to open device security settings.',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isOpeningSecuritySettings = false;
    }
  }

  void continueWithoutLock() {
    if (!state.canBypass) {
      return;
    }

    _authAttemptId += 1;
    state = const AppLockState.unlocked();
  }
}
