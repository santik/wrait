import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/data/auth/app_lock_authenticator.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/auth/device_security_settings_opener.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/presentation/app_lock/app_lock_gate.dart';
import 'package:wrait/presentation/app_lock/app_lock_test_keys.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';
import 'package:wrait/presentation/locale/app_localizations_fallback.dart';
import 'package:wrait/presentation/settings/settings_screen.dart';
import 'package:wrait/presentation/settings/settings_test_keys.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'default off, enable without prompt, next resume locks, and disable stays unlocked',
    (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final authenticator = _Authenticator(<AppLockAuthResult>[
        AppLockAuthResult.canceled,
        AppLockAuthResult.success,
      ]);

      await tester.pumpWidget(
        _app(preferences: preferences, authenticator: authenticator),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(appLockOverlayKey), findsNothing);
      expect(authenticator.authenticateCalls, 0);
      expect(
        tester.widget<SwitchListTile>(find.byKey(appLockSwitchKey)).value,
        isFalse,
      );

      await tester.tap(find.byKey(appLockSwitchKey));
      await tester.pumpAndSettle();

      expect(find.byKey(appLockOverlayKey), findsNothing);
      expect(authenticator.availabilityCalls, 1);
      expect(authenticator.authenticateCalls, 0);
      expect(preferences.getBool('app_lock_enabled'), isTrue);

      _simulateForegroundExitAndResume(tester);
      await tester.pumpAndSettle();

      expect(authenticator.authenticateCalls, 1);
      expect(find.byKey(appLockOverlayKey), findsOneWidget);

      await tester.tap(find.byKey(appLockUnlockButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(appLockOverlayKey), findsNothing);
      expect(authenticator.authenticateCalls, 2);

      await tester.tap(find.byKey(appLockSwitchKey));
      await tester.pumpAndSettle();
      expect(preferences.getBool('app_lock_enabled'), isFalse);
      expect(authenticator.authenticateCalls, 2);

      _simulateForegroundExitAndResume(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(appLockOverlayKey), findsNothing);
      expect(authenticator.authenticateCalls, 2);
    },
  );

  testWidgets('saved enabled preference protects the first usable screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'app_lock_enabled': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final authenticator = _Authenticator(<AppLockAuthResult>[
      AppLockAuthResult.canceled,
    ]);

    await tester.pumpWidget(
      _app(preferences: preferences, authenticator: authenticator),
    );
    await tester.pumpAndSettle();

    expect(authenticator.authenticateCalls, 1);
    expect(find.byKey(appLockOverlayKey), findsOneWidget);
    expect(find.text('App lock'), findsOneWidget);
  });

  testWidgets('foreground exit during enablement locks when enable completes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final availability = Completer<AppLockAvailability>();
    final authenticator = _Authenticator(<AppLockAuthResult>[
      AppLockAuthResult.canceled,
    ])..availabilityCompleter = availability;

    await tester.pumpWidget(
      _app(preferences: preferences, authenticator: authenticator),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(appLockSwitchKey));
    await tester.pump();

    _simulateForegroundExitAndResume(tester);
    availability.complete(AppLockAvailability.available);
    await tester.pumpAndSettle();

    expect(preferences.getBool('app_lock_enabled'), isTrue);
    expect(authenticator.authenticateCalls, 1);
    expect(find.byKey(appLockOverlayKey), findsOneWidget);
  });

  testWidgets('enabled choice survives provider-container recreation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final firstAuthenticator = _Authenticator(const <AppLockAuthResult>[]);
    await tester.pumpWidget(
      _app(preferences: preferences, authenticator: firstAuthenticator),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(appLockSwitchKey));
    await tester.pumpAndSettle();
    expect(preferences.getBool('app_lock_enabled'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final relaunchedAuthenticator = _Authenticator(<AppLockAuthResult>[
      AppLockAuthResult.canceled,
    ]);
    await tester.pumpWidget(
      _app(preferences: preferences, authenticator: relaunchedAuthenticator),
    );
    await tester.pumpAndSettle();

    expect(relaunchedAuthenticator.authenticateCalls, 1);
    expect(find.byKey(appLockOverlayKey), findsOneWidget);
  });

  testWidgets('large text keeps the setting visible and operable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final authenticator = _Authenticator(const <AppLockAuthResult>[]);

    await tester.pumpWidget(
      _app(
        preferences: preferences,
        authenticator: authenticator,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(appLockSwitchKey), findsOneWidget);
    await tester.tap(find.byKey(appLockSwitchKey));
    await tester.pumpAndSettle();

    expect(preferences.getBool('app_lock_enabled'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct settings route remains covered while locked', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'app_lock_enabled': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final authenticator = _Authenticator(<AppLockAuthResult>[
      AppLockAuthResult.canceled,
    ]);
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('main')),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          appLockAuthenticatorProvider.overrideWithValue(authenticator),
          deviceSecuritySettingsOpenerProvider.overrideWithValue(
            const _SettingsOpener(),
          ),
          mainRecordingControllerProvider.overrideWith(_IdleController.new),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: const [Locale('en')],
          builder: (context, child) => AppLockGate(child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(find.byKey(appLockOverlayKey), findsOneWidget);
    expect(authenticator.authenticateCalls, 1);
  });
}

void _simulateForegroundExitAndResume(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Widget _app({
  required SharedPreferences preferences,
  required _Authenticator authenticator,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      appLockAuthenticatorProvider.overrideWithValue(authenticator),
      deviceSecuritySettingsOpenerProvider.overrideWithValue(
        const _SettingsOpener(),
      ),
      mainRecordingControllerProvider.overrideWith(_IdleController.new),
    ],
    child: MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: const [Locale('en')],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: const AppLockGate(child: SettingsScreen()),
    ),
  );
}

class _IdleController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();
}

class _Authenticator implements AppLockAuthenticator {
  _Authenticator(this.results);

  final List<AppLockAuthResult> results;
  int availabilityCalls = 0;
  int authenticateCalls = 0;
  Completer<AppLockAvailability>? availabilityCompleter;

  @override
  Future<AppLockAvailability> availability() async {
    availabilityCalls += 1;
    return availabilityCompleter?.future ?? AppLockAvailability.available;
  }

  @override
  Future<AppLockAuthResult> authenticate({
    required String localizedReason,
  }) async {
    authenticateCalls += 1;
    return results.removeAt(0);
  }

  @override
  Future<void> cancel() async {}
}

class _SettingsOpener implements DeviceSecuritySettingsOpener {
  const _SettingsOpener();

  @override
  Future<bool> openDeviceSecuritySettings() async => true;
}
