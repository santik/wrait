import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/auth/app_lock_authenticator.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/auth/device_security_settings_opener.dart';
import 'package:wrait/presentation/app_lock/app_lock_controller.dart';

void main() {
  late _FakeAppLockAuthenticator authenticator;
  late _FakeDeviceSecuritySettingsOpener settingsOpener;
  late ProviderContainer container;

  ProviderContainer buildContainer() {
    authenticator = _FakeAppLockAuthenticator();
    settingsOpener = _FakeDeviceSecuritySettingsOpener();

    return ProviderContainer(
      overrides: [
        appLockAuthenticatorProvider.overrideWithValue(authenticator),
        deviceSecuritySettingsOpenerProvider.overrideWithValue(settingsOpener),
      ],
    );
  }

  setUp(() {
    container = buildContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('starts locked and waiting to auto-prompt on foreground', () {
    expect(
      container.read(appLockControllerProvider),
      const AppLockState.locked(),
    );
  });

  test('foreground ready auto-prompts and unlocks on success', () async {
    authenticator.nextAuthenticateResult = AppLockAuthResult.success;

    await container
        .read(appLockControllerProvider.notifier)
        .onForegroundReady();

    expect(authenticator.authenticateCallCount, 1);
    expect(
      container.read(appLockControllerProvider),
      const AppLockState.unlocked(),
    );
  });

  test('canceled auth stays locked and does not auto-prompt again', () async {
    authenticator.nextAuthenticateResult = AppLockAuthResult.canceled;

    await container
        .read(appLockControllerProvider.notifier)
        .onForegroundReady();
    expect(
      container.read(appLockControllerProvider),
      const AppLockState.locked(
        status: AppLockStatus.canceled,
        shouldPromptOnForeground: false,
      ),
    );

    await container
        .read(appLockControllerProvider.notifier)
        .onForegroundReady();
    expect(authenticator.authenticateCallCount, 1);
  });

  test('manual unlock retries after cancel', () async {
    authenticator.nextAuthenticateResult = AppLockAuthResult.canceled;
    await container
        .read(appLockControllerProvider.notifier)
        .onForegroundReady();

    authenticator.nextAuthenticateResult = AppLockAuthResult.success;
    await container.read(appLockControllerProvider.notifier).unlock();

    expect(authenticator.authenticateCallCount, 2);
    expect(
      container.read(appLockControllerProvider),
      const AppLockState.unlocked(),
    );
  });

  test('no-security state exposes bypass and settings paths', () async {
    authenticator.nextAuthenticateResult =
        AppLockAuthResult.noSecurityConfigured;

    await container
        .read(appLockControllerProvider.notifier)
        .onForegroundReady();

    expect(
      container.read(appLockControllerProvider),
      const AppLockState.locked(
        status: AppLockStatus.noSecurity,
        shouldPromptOnForeground: false,
      ),
    );

    await container
        .read(appLockControllerProvider.notifier)
        .openSecuritySettings();
    expect(settingsOpener.openCallCount, 1);

    container.read(appLockControllerProvider.notifier).continueWithoutLock();
    expect(
      container.read(appLockControllerProvider),
      const AppLockState.unlocked(),
    );
  });

  test(
    'open security settings is single-flight while already in progress',
    () async {
      final completer = Completer<bool>();
      settingsOpener.openCompleter = completer;

      final notifier = container.read(appLockControllerProvider.notifier);
      final firstOpen = notifier.openSecuritySettings();
      final secondOpen = notifier.openSecuritySettings();

      expect(settingsOpener.openCallCount, 1);

      completer.complete(true);
      await Future.wait([firstOpen, secondOpen]);

      expect(settingsOpener.openCallCount, 1);
    },
  );

  test('temporary unavailable stays locked and allows retry', () async {
    authenticator.nextAuthenticateResult =
        AppLockAuthResult.temporarilyUnavailable;

    await container
        .read(appLockControllerProvider.notifier)
        .onForegroundReady();

    expect(
      container.read(appLockControllerProvider),
      const AppLockState.locked(
        status: AppLockStatus.temporarilyUnavailable,
        shouldPromptOnForeground: false,
      ),
    );

    authenticator.nextAuthenticateResult = AppLockAuthResult.success;
    await container.read(appLockControllerProvider.notifier).unlock();

    expect(authenticator.authenticateCallCount, 2);
    expect(
      container.read(appLockControllerProvider),
      const AppLockState.unlocked(),
    );
  });

  test('background relock restores auto-prompt behavior', () async {
    authenticator.nextAuthenticateResult = AppLockAuthResult.success;
    await container
        .read(appLockControllerProvider.notifier)
        .onForegroundReady();

    container.read(appLockControllerProvider.notifier).lockForForegroundExit();

    expect(
      container.read(appLockControllerProvider),
      const AppLockState.locked(),
    );
  });

  test('single-flight unlock ignores overlapping prompt attempts', () async {
    final completer = Completer<AppLockAuthResult>();
    authenticator.authenticateCompleter = completer;

    final notifier = container.read(appLockControllerProvider.notifier);
    final firstAttempt = notifier.unlock();
    final secondAttempt = notifier.unlock();

    expect(authenticator.authenticateCallCount, 1);
    expect(
      container.read(appLockControllerProvider),
      const AppLockState.locked(
        status: AppLockStatus.authenticating,
        isPromptPending: true,
        shouldPromptOnForeground: false,
      ),
    );

    completer.complete(AppLockAuthResult.success);
    await Future.wait([firstAttempt, secondAttempt]);

    expect(
      container.read(appLockControllerProvider),
      const AppLockState.unlocked(),
    );
  });

  test(
    'disposing during a pending unlock ignores the auth completion',
    () async {
      final completer = Completer<AppLockAuthResult>();
      authenticator.authenticateCompleter = completer;

      final unlockFuture = container
          .read(appLockControllerProvider.notifier)
          .unlock();

      container.dispose();
      completer.complete(AppLockAuthResult.success);

      await unlockFuture;
    },
  );
}

class _FakeAppLockAuthenticator implements AppLockAuthenticator {
  AppLockAvailability nextAvailability = AppLockAvailability.available;
  AppLockAuthResult nextAuthenticateResult = AppLockAuthResult.success;
  Completer<AppLockAuthResult>? authenticateCompleter;
  int authenticateCallCount = 0;

  @override
  Future<AppLockAvailability> availability() async => nextAvailability;

  @override
  Future<AppLockAuthResult> authenticate({
    required String localizedReason,
  }) async {
    authenticateCallCount += 1;
    final completer = authenticateCompleter;
    if (completer != null) {
      return completer.future;
    }
    return nextAuthenticateResult;
  }

  @override
  Future<void> cancel() async {}
}

class _FakeDeviceSecuritySettingsOpener
    implements DeviceSecuritySettingsOpener {
  int openCallCount = 0;
  Completer<bool>? openCompleter;

  @override
  Future<bool> openDeviceSecuritySettings() async {
    openCallCount += 1;
    final completer = openCompleter;
    if (completer != null) {
      return completer.future;
    }
    return true;
  }
}
