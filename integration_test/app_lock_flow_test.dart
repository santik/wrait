import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/data/auth/app_lock_authenticator.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/auth/device_security_settings_opener.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/app_lock_preferences_repository.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/presentation/app_lock/app_lock_test_keys.dart';
import 'package:wrait/presentation/feedback/feedback_preparation_sheet.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/main_screen_test_keys.dart';
import 'package:wrait/presentation/main/recording_state.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold launch auto-unlocks on success', (tester) async {
    final harness = await _buildHarness(
      authResults: <AppLockAuthResult>[AppLockAuthResult.success],
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.byKey(appLockOverlayKey), findsNothing);
    expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);
    expect(harness.authenticator.authenticateCallCount, 1);
    expect(find.byType(FlutterLogo), findsNothing);
  });

  testWidgets('background and resume re-locks then auto-prompts again', (
    tester,
  ) async {
    final harness = await _buildHarness(
      authResults: <AppLockAuthResult>[
        AppLockAuthResult.success,
        AppLockAuthResult.canceled,
      ],
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    expect(find.byKey(appLockOverlayKey), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(harness.authenticator.authenticateCallCount, 2);
    expect(find.byKey(appLockOverlayKey), findsOneWidget);
    expect(find.text('still locked'), findsOneWidget);
    expect(find.byType(FlutterLogo), findsNothing);
  });

  testWidgets(
    'inactive lifecycle churn during in-flight auth does not restart the prompt',
    (tester) async {
      final completer = Completer<AppLockAuthResult>();
      final harness = await _buildHarness(
        authResults: <AppLockAuthResult>[],
        authenticateCompleter: completer,
      );

      await tester.pumpWidget(harness.app);
      await tester.pump();

      expect(harness.authenticator.authenticateCallCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(harness.authenticator.authenticateCallCount, 1);
      expect(find.byKey(appLockOverlayKey), findsOneWidget);

      completer.complete(AppLockAuthResult.success);
      await tester.pumpAndSettle();

      expect(find.byKey(appLockOverlayKey), findsNothing);
    },
  );

  testWidgets('cancel keeps locked until retry succeeds', (tester) async {
    final harness = await _buildHarness(
      authResults: <AppLockAuthResult>[
        AppLockAuthResult.canceled,
        AppLockAuthResult.success,
      ],
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.text('still locked'), findsOneWidget);
    expect(find.byKey(appLockOverlayKey), findsOneWidget);
    expect(find.byType(FlutterLogo), findsNothing);

    await tester.tap(find.byKey(appLockUnlockButtonKey));
    await tester.pumpAndSettle();

    expect(harness.authenticator.authenticateCallCount, 2);
    expect(find.byKey(appLockOverlayKey), findsNothing);
  });

  testWidgets('no-security offers settings and bypass', (tester) async {
    final harness = await _buildHarness(
      authResults: <AppLockAuthResult>[AppLockAuthResult.noSecurityConfigured],
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(
      find.text('set up device security to protect Wrait'),
      findsOneWidget,
    );
    expect(find.byType(FlutterLogo), findsNothing);

    await tester.tap(find.byKey(appLockSettingsButtonKey));
    await tester.pump();
    expect(harness.settingsOpener.openCallCount, 1);

    await tester.tap(find.byKey(appLockBypassButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(appLockOverlayKey), findsNothing);
  });

  testWidgets('temporary unavailable stays locked and allows retry', (
    tester,
  ) async {
    final harness = await _buildHarness(
      authResults: <AppLockAuthResult>[
        AppLockAuthResult.temporarilyUnavailable,
        AppLockAuthResult.success,
      ],
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.text('unlock unavailable · try again'), findsOneWidget);
    expect(find.byKey(appLockOverlayKey), findsOneWidget);
    expect(find.byType(FlutterLogo), findsNothing);

    await tester.tap(find.byKey(appLockUnlockButtonKey));
    await tester.pumpAndSettle();

    expect(harness.authenticator.authenticateCallCount, 2);
    expect(find.byKey(appLockOverlayKey), findsNothing);
  });

  testWidgets(
    'app lock covers an open feedback surface after foreground exit',
    (tester) async {
      final harness = await _buildHarness(
        authResults: <AppLockAuthResult>[
          AppLockAuthResult.success,
          AppLockAuthResult.canceled,
          AppLockAuthResult.success,
        ],
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(mainFeedbackButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(feedbackPrivacyCopyKey), findsOneWidget);
      await tester.tap(find.text('Idea'));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.byKey(appLockOverlayKey), findsOneWidget);
      expect(find.byKey(feedbackPrivacyCopyKey), findsOneWidget);

      await tester.tap(
        find.byKey(feedbackSubmitButtonKey),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(feedbackPrivacyCopyKey), findsOneWidget);

      await tester.tap(find.byKey(appLockUnlockButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(appLockOverlayKey), findsNothing);

      await tester.tap(find.text('cancel'));
      await tester.pumpAndSettle();
      expect(find.byKey(feedbackPrivacyCopyKey), findsNothing);
    },
  );
}

class _Harness {
  const _Harness({
    required this.app,
    required this.authenticator,
    required this.settingsOpener,
  });

  final Widget app;
  final _FakeAppLockAuthenticator authenticator;
  final _FakeDeviceSecuritySettingsOpener settingsOpener;
}

Future<_Harness> _buildHarness({
  required List<AppLockAuthResult> authResults,
  Completer<AppLockAuthResult>? authenticateCompleter,
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final sharedPreferences = await SharedPreferences.getInstance();
  final authenticator = _FakeAppLockAuthenticator(
    authResults,
    authenticateCompleter: authenticateCompleter,
  );
  final settingsOpener = _FakeDeviceSecuritySettingsOpener();

  final app = ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          backendUrl: 'https://wrait-backend.vercel.app',
          proxySecret: '',
          recordingHardCapMs: 120000,
        ),
      ),
      appRouterProvider.overrideWithValue(buildAppRouter()),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      appLockAuthenticatorProvider.overrideWithValue(authenticator),
      deviceSecuritySettingsOpenerProvider.overrideWithValue(settingsOpener),
      preferencesRepositoryProvider.overrideWithValue(
        const _TestPreferencesRepository(),
      ),
      entryRepositoryProvider.overrideWithValue(const _TestEntryRepository()),
      mainRecordingControllerProvider.overrideWith(_SmokeController.new),
    ],
    child: const WraitApp(),
  );

  return _Harness(
    app: app,
    authenticator: authenticator,
    settingsOpener: settingsOpener,
  );
}

class _FakeAppLockAuthenticator implements AppLockAuthenticator {
  _FakeAppLockAuthenticator(
    List<AppLockAuthResult> authResults, {
    this.authenticateCompleter,
  }) : _authResults = authResults;

  final List<AppLockAuthResult> _authResults;
  Completer<AppLockAuthResult>? authenticateCompleter;
  int authenticateCallCount = 0;

  @override
  Future<AppLockAvailability> availability() async {
    final nextResult = _authResults.isEmpty
        ? AppLockAuthResult.success
        : _authResults.first;
    return switch (nextResult) {
      AppLockAuthResult.noSecurityConfigured =>
        AppLockAvailability.noSecurityConfigured,
      AppLockAuthResult.temporarilyUnavailable =>
        AppLockAvailability.temporarilyUnavailable,
      AppLockAuthResult.unavailable => AppLockAvailability.unavailable,
      _ => AppLockAvailability.available,
    };
  }

  @override
  Future<AppLockAuthResult> authenticate({
    required String localizedReason,
  }) async {
    authenticateCallCount += 1;
    final completer = authenticateCompleter;
    if (completer != null) {
      return completer.future;
    }
    if (_authResults.isEmpty) {
      return AppLockAuthResult.success;
    }
    return _authResults.removeAt(0);
  }

  @override
  Future<void> cancel() async {}
}

class _FakeDeviceSecuritySettingsOpener
    implements DeviceSecuritySettingsOpener {
  int openCallCount = 0;

  @override
  Future<bool> openDeviceSecuritySettings() async {
    openCallCount += 1;
    return true;
  }
}

class _SmokeController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();

  @override
  Future<void> onMainButtonTapped() async {}
}

class _TestEntryRepository implements EntryRepository {
  const _TestEntryRepository();

  @override
  Stream<List<Entry>> watchAllEntries() =>
      Stream<List<Entry>>.value(const <Entry>[]);

  @override
  Stream<Entry?> watchEntryById(int id) => const Stream<Entry?>.empty();

  @override
  Future<Entry?> getEntryById(int id) async => null;

  @override
  Future<List<int>> importEntries(List<Entry> entries) async => const [];

  @override
  Future<int> saveDraft(String transcript, String language) async => 1;

  @override
  Future<int> saveEntry(String transcript, String language) async => 1;

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async => 1;

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {}

  @override
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<void> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  ) async {}

  @override
  Future<void> updateDraftTranscriptAndLanguage(
    int id,
    String rawTranscript,
    int wordCount,
    String language,
  ) async {}

  @override
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<void> updateEntryLanguage(int id, String language) async {}

  @override
  Future<List<Entry>> getPendingDrafts() async => const <Entry>[];

  @override
  Future<void> deleteEntry(int id) async {}

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}
}

class _TestPreferencesRepository
    implements PreferencesRepository, AppLockPreferencesRepository {
  const _TestPreferencesRepository();

  @override
  Future<bool> getAppLockEnabled() async => true;

  @override
  Future<void> setAppLockEnabled(bool value) async {}

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => true;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}
