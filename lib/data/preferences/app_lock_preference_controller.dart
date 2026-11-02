import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/app_lock_authenticator.dart';
import '../auth/app_lock_providers.dart';
import 'preferences_providers.dart';

enum AppLockPreferenceStatus { loading, ready, loadFailure }

enum AppLockPreferenceIssue {
  noSecurity,
  temporarilyUnavailable,
  unavailable,
  saveFailed,
  settingsFailed,
}

class AppLockPreferenceState {
  const AppLockPreferenceState({
    required this.status,
    this.enabled = false,
    this.isSaving = false,
    this.requestedValue,
    this.issue,
  });

  const AppLockPreferenceState.loading()
    : this(status: AppLockPreferenceStatus.loading);

  const AppLockPreferenceState.loadFailure()
    : this(status: AppLockPreferenceStatus.loadFailure);

  final AppLockPreferenceStatus status;
  final bool enabled;
  final bool isSaving;
  final bool? requestedValue;
  final AppLockPreferenceIssue? issue;

  bool get isReady => status == AppLockPreferenceStatus.ready;

  AppLockPreferenceState copyWith({
    bool? enabled,
    bool? isSaving,
    bool clearRequestedValue = false,
    bool? requestedValue,
    bool clearIssue = false,
    AppLockPreferenceIssue? issue,
  }) {
    return AppLockPreferenceState(
      status: status,
      enabled: enabled ?? this.enabled,
      isSaving: isSaving ?? this.isSaving,
      requestedValue: clearRequestedValue
          ? null
          : requestedValue ?? this.requestedValue,
      issue: clearIssue ? null : issue ?? this.issue,
    );
  }
}

final appLockPreferenceControllerProvider =
    NotifierProvider<AppLockPreferenceController, AppLockPreferenceState>(
      AppLockPreferenceController.new,
    );

final appLockAvailabilityTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 30),
);

class AppLockPreferenceController extends Notifier<AppLockPreferenceState> {
  int _operationId = 0;
  bool _isOpeningSettings = false;

  @override
  AppLockPreferenceState build() {
    ref.onDispose(() {
      _operationId += 1;
    });
    unawaited(_load());
    return const AppLockPreferenceState.loading();
  }

  Future<void> retryLoad() async {
    if (state.status == AppLockPreferenceStatus.loading) {
      return;
    }
    state = const AppLockPreferenceState.loading();
    await _load();
  }

  Future<bool> setEnabled(bool value) async {
    if (!state.isReady || state.isSaving || state.enabled == value) {
      return false;
    }

    final operationId = ++_operationId;
    state = state.copyWith(
      isSaving: true,
      requestedValue: value,
      clearIssue: true,
    );

    if (value) {
      final availability = await _availability();
      if (!ref.mounted || operationId != _operationId) {
        return false;
      }
      final issue = switch (availability) {
        AppLockAvailability.available => null,
        AppLockAvailability.noSecurityConfigured =>
          AppLockPreferenceIssue.noSecurity,
        AppLockAvailability.temporarilyUnavailable =>
          AppLockPreferenceIssue.temporarilyUnavailable,
        AppLockAvailability.unavailable => AppLockPreferenceIssue.unavailable,
      };
      if (issue != null) {
        state = state.copyWith(
          isSaving: false,
          clearRequestedValue: true,
          issue: issue,
        );
        return false;
      }
    }

    try {
      await ref
          .read(appLockPreferencesRepositoryProvider)
          .setAppLockEnabled(value);
    } catch (_) {
      if (ref.mounted && operationId == _operationId) {
        state = state.copyWith(
          isSaving: false,
          clearRequestedValue: true,
          issue: AppLockPreferenceIssue.saveFailed,
        );
      }
      return false;
    }

    if (!ref.mounted || operationId != _operationId) {
      return false;
    }
    state = state.copyWith(
      enabled: value,
      isSaving: false,
      clearRequestedValue: true,
      clearIssue: true,
    );
    return true;
  }

  Future<bool> openDeviceSecuritySettings() async {
    if (_isOpeningSettings) {
      return false;
    }
    _isOpeningSettings = true;
    try {
      final opened = await ref
          .read(deviceSecuritySettingsOpenerProvider)
          .openDeviceSecuritySettings();
      if (!opened && ref.mounted && state.isReady) {
        state = state.copyWith(issue: AppLockPreferenceIssue.settingsFailed);
      }
      return opened;
    } catch (_) {
      if (ref.mounted && state.isReady) {
        state = state.copyWith(issue: AppLockPreferenceIssue.settingsFailed);
      }
      return false;
    } finally {
      _isOpeningSettings = false;
    }
  }

  Future<void> _load() async {
    final operationId = ++_operationId;
    try {
      final enabled = await ref
          .read(appLockPreferencesRepositoryProvider)
          .getAppLockEnabled();
      if (!ref.mounted || operationId != _operationId) {
        return;
      }
      state = AppLockPreferenceState(
        status: AppLockPreferenceStatus.ready,
        enabled: enabled,
      );
    } catch (_) {
      if (ref.mounted && operationId == _operationId) {
        state = const AppLockPreferenceState.loadFailure();
      }
    }
  }

  Future<AppLockAvailability> _availability() async {
    try {
      return await ref
          .read(appLockAuthenticatorProvider)
          .availability()
          .timeout(
            ref.read(appLockAvailabilityTimeoutProvider),
            onTimeout: () => AppLockAvailability.temporarilyUnavailable,
          );
    } catch (_) {
      return AppLockAvailability.unavailable;
    }
  }
}
