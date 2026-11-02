import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/auth/app_lock_authenticator.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/auth/device_security_settings_opener.dart';
import 'package:wrait/data/preferences/app_lock_preference_controller.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/repository/app_lock_preferences_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';

void main() {
  late _PreferencesRepository repository;
  late _Authenticator authenticator;
  late _SettingsOpener settingsOpener;
  late ProviderContainer container;

  setUp(() {
    repository = _PreferencesRepository();
    authenticator = _Authenticator();
    settingsOpener = _SettingsOpener();
    container = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(repository),
        appLockAuthenticatorProvider.overrideWithValue(authenticator),
        deviceSecuritySettingsOpenerProvider.overrideWithValue(settingsOpener),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<AppLockPreferenceState> ready() async {
    container.read(appLockPreferenceControllerProvider);
    await Future<void>.delayed(Duration.zero);
    return container.read(appLockPreferenceControllerProvider);
  }

  test('loads missing preference as disabled', () async {
    final state = await ready();

    expect(state.isReady, isTrue);
    expect(state.enabled, isFalse);
  });

  test('enable checks availability and saves without authenticating', () async {
    await ready();

    final changed = await container
        .read(appLockPreferenceControllerProvider.notifier)
        .setEnabled(true);

    expect(changed, isTrue);
    expect(repository.enabled, isTrue);
    expect(authenticator.availabilityCalls, 1);
    expect(authenticator.authenticateCalls, 0);
  });

  test('no device security leaves preference disabled', () async {
    await ready();
    authenticator.nextAvailability = AppLockAvailability.noSecurityConfigured;

    final changed = await container
        .read(appLockPreferenceControllerProvider.notifier)
        .setEnabled(true);

    final state = container.read(appLockPreferenceControllerProvider);
    expect(changed, isFalse);
    expect(state.enabled, isFalse);
    expect(state.issue, AppLockPreferenceIssue.noSecurity);
    expect(repository.writeCount, 0);
  });

  test(
    'disable saves without checking availability or authenticating',
    () async {
      repository.enabled = true;
      await ready();

      final changed = await container
          .read(appLockPreferenceControllerProvider.notifier)
          .setEnabled(false);

      expect(changed, isTrue);
      expect(repository.enabled, isFalse);
      expect(authenticator.availabilityCalls, 0);
      expect(authenticator.authenticateCalls, 0);
    },
  );

  test(
    'failed save retains committed value and exposes sanitized issue',
    () async {
      await ready();
      repository.failWrites = true;

      final changed = await container
          .read(appLockPreferenceControllerProvider.notifier)
          .setEnabled(true);

      final state = container.read(appLockPreferenceControllerProvider);
      expect(changed, isFalse);
      expect(state.enabled, isFalse);
      expect(state.issue, AppLockPreferenceIssue.saveFailed);
    },
  );

  test('repeated request is single-flight', () async {
    await ready();
    final completer = Completer<AppLockAvailability>();
    authenticator.availabilityCompleter = completer;

    final notifier = container.read(
      appLockPreferenceControllerProvider.notifier,
    );
    final first = notifier.setEnabled(true);
    final second = notifier.setEnabled(true);
    expect(authenticator.availabilityCalls, 1);

    completer.complete(AppLockAvailability.available);
    expect(await first, isTrue);
    expect(await second, isFalse);
    expect(repository.writeCount, 1);
  });

  test('availability timeout keeps the committed value disabled', () async {
    container.dispose();
    authenticator.availabilityCompleter = Completer<AppLockAvailability>();
    container = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(repository),
        appLockAuthenticatorProvider.overrideWithValue(authenticator),
        deviceSecuritySettingsOpenerProvider.overrideWithValue(settingsOpener),
        appLockAvailabilityTimeoutProvider.overrideWithValue(
          const Duration(milliseconds: 1),
        ),
      ],
    );
    await ready();

    final changed = await container
        .read(appLockPreferenceControllerProvider.notifier)
        .setEnabled(true);

    final state = container.read(appLockPreferenceControllerProvider);
    expect(changed, isFalse);
    expect(state.enabled, isFalse);
    expect(state.issue, AppLockPreferenceIssue.temporarilyUnavailable);
    expect(repository.writeCount, 0);
  });

  test('failed load can be retried', () async {
    repository.failReads = true;
    expect((await ready()).status, AppLockPreferenceStatus.loadFailure);

    repository.failReads = false;
    await container
        .read(appLockPreferenceControllerProvider.notifier)
        .retryLoad();

    expect(container.read(appLockPreferenceControllerProvider).isReady, isTrue);
  });

  test('late availability completion is ignored after disposal', () async {
    await ready();
    final availability = Completer<AppLockAvailability>();
    authenticator.availabilityCompleter = availability;
    final change = container
        .read(appLockPreferenceControllerProvider.notifier)
        .setEnabled(true);

    container.dispose();
    container = ProviderContainer();
    availability.complete(AppLockAvailability.available);

    expect(await change, isFalse);
    expect(repository.writeCount, 0);
  });

  test('settings-opening failure is sanitized and retry can succeed', () async {
    await ready();
    settingsOpener.nextResult = false;

    final first = await container
        .read(appLockPreferenceControllerProvider.notifier)
        .openDeviceSecuritySettings();

    expect(first, isFalse);
    expect(
      container.read(appLockPreferenceControllerProvider).issue,
      AppLockPreferenceIssue.settingsFailed,
    );

    settingsOpener.nextResult = true;
    final second = await container
        .read(appLockPreferenceControllerProvider.notifier)
        .openDeviceSecuritySettings();
    expect(second, isTrue);
    expect(settingsOpener.openCalls, 2);
  });

  test('conflicting request is ignored while enable is pending', () async {
    await ready();
    final availability = Completer<AppLockAvailability>();
    authenticator.availabilityCompleter = availability;
    final notifier = container.read(
      appLockPreferenceControllerProvider.notifier,
    );

    final enable = notifier.setEnabled(true);
    final disable = await notifier.setEnabled(false);
    availability.complete(AppLockAvailability.available);

    expect(disable, isFalse);
    expect(await enable, isTrue);
    expect(repository.enabled, isTrue);
    expect(repository.writeCount, 1);
  });
}

class _PreferencesRepository
    implements PreferencesRepository, AppLockPreferencesRepository {
  bool enabled = false;
  bool failWrites = false;
  bool failReads = false;
  int writeCount = 0;

  @override
  Future<bool> getAppLockEnabled() async {
    if (failReads) {
      throw StateError('read failed');
    }
    return enabled;
  }

  @override
  Future<void> setAppLockEnabled(bool value) async {
    writeCount += 1;
    if (failWrites) {
      throw StateError('write failed');
    }
    enabled = value;
  }

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => false;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}

class _Authenticator implements AppLockAuthenticator {
  AppLockAvailability nextAvailability = AppLockAvailability.available;
  Completer<AppLockAvailability>? availabilityCompleter;
  int availabilityCalls = 0;
  int authenticateCalls = 0;

  @override
  Future<AppLockAvailability> availability() async {
    availabilityCalls += 1;
    return availabilityCompleter?.future ?? nextAvailability;
  }

  @override
  Future<AppLockAuthResult> authenticate({
    required String localizedReason,
  }) async {
    authenticateCalls += 1;
    return AppLockAuthResult.success;
  }

  @override
  Future<void> cancel() async {}
}

class _SettingsOpener implements DeviceSecuritySettingsOpener {
  bool nextResult = true;
  int openCalls = 0;

  @override
  Future<bool> openDeviceSecuritySettings() async {
    openCalls += 1;
    return nextResult;
  }
}
