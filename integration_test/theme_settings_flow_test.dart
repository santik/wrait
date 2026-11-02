import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/preferences/preferences_repository_impl.dart';
import 'package:wrait/data/transcription/transcription_providers.dart';
import 'package:wrait/data/transcription/transcription_service.dart';
import 'package:wrait/presentation/main/main_screen_test_keys.dart';
import 'package:wrait/presentation/settings/settings_test_keys.dart';

import '../test/test_doubles/fake_secure_storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'defaults to system, switches to light and dark, persists across restart',
    (tester) async {
      final harness = await _ThemeSettingsHarness.create();
      addTearDown(harness.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to settings.
      await tester.tap(find.byKey(mainSettingsButtonKey));
      await tester.pumpAndSettle();

      // System is the default selection.
      final segmented = tester.widget<SegmentedButton<ThemeMode>>(
        find.byKey(themeSegmentedButtonKey),
      );
      expect(segmented.selected, {ThemeMode.system});
      expect(
        harness.sharedPreferences.getString(
          PreferencesRepositoryImpl.themeModeKey,
        ),
        isNull,
      );

      // Switch to Light.
      await tester.tap(find.byKey(themeLightSegmentKey));
      await tester.pumpAndSettle();

      final afterLight = tester.widget<SegmentedButton<ThemeMode>>(
        find.byKey(themeSegmentedButtonKey),
      );
      expect(afterLight.selected, {ThemeMode.light});
      expect(
        harness.sharedPreferences.getString(
          PreferencesRepositoryImpl.themeModeKey,
        ),
        'light',
      );

      // Verify the MaterialApp switched to light theme.
      final materialApp = tester.widget<MaterialApp>(
        find.byType(MaterialApp).last,
      );
      expect(materialApp.themeMode, ThemeMode.light);

      // Switch to Dark.
      await tester.tap(find.byKey(themeDarkSegmentKey));
      await tester.pumpAndSettle();

      final afterDark = tester.widget<SegmentedButton<ThemeMode>>(
        find.byKey(themeSegmentedButtonKey),
      );
      expect(afterDark.selected, {ThemeMode.dark});
      expect(
        harness.sharedPreferences.getString(
          PreferencesRepositoryImpl.themeModeKey,
        ),
        'dark',
      );

      final darkMaterialApp = tester.widget<MaterialApp>(
        find.byType(MaterialApp).last,
      );
      expect(darkMaterialApp.themeMode, ThemeMode.dark);

      // Switch back to System.
      await tester.tap(find.byKey(themeSystemSegmentKey));
      await tester.pumpAndSettle();

      final afterSystem = tester.widget<SegmentedButton<ThemeMode>>(
        find.byKey(themeSegmentedButtonKey),
      );
      expect(afterSystem.selected, {ThemeMode.system});
      expect(
        harness.sharedPreferences.getString(
          PreferencesRepositoryImpl.themeModeKey,
        ),
        'system',
      );

      final systemMaterialApp = tester.widget<MaterialApp>(
        find.byType(MaterialApp).last,
      );
      expect(systemMaterialApp.themeMode, ThemeMode.system);
    },
  );

  testWidgets('saved dark preference loads correctly on fresh launch', (
    tester,
  ) async {
    final harness = await _ThemeSettingsHarness.create(
      initialPreferences: {'theme_mode': 'dark'},
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The MaterialApp should already be in dark mode from the saved preference.
    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp).last,
    );
    expect(materialApp.themeMode, ThemeMode.dark);

    // Navigate to settings and verify the segmented button reflects the saved choice.
    await tester.tap(find.byKey(mainSettingsButtonKey));
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<ThemeMode>>(
      find.byKey(themeSegmentedButtonKey),
    );
    expect(segmented.selected, {ThemeMode.dark});
  });

  testWidgets('saved light preference loads correctly on fresh launch', (
    tester,
  ) async {
    final harness = await _ThemeSettingsHarness.create(
      initialPreferences: {'theme_mode': 'light'},
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp).last,
    );
    expect(materialApp.themeMode, ThemeMode.light);

    await tester.tap(find.byKey(mainSettingsButtonKey));
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<ThemeMode>>(
      find.byKey(themeSegmentedButtonKey),
    );
    expect(segmented.selected, {ThemeMode.light});
  });

  testWidgets('invalid stored value falls back to system', (tester) async {
    final harness = await _ThemeSettingsHarness.create(
      initialPreferences: {'theme_mode': 'neon'},
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp).last,
    );
    expect(materialApp.themeMode, ThemeMode.system);
  });

  testWidgets('theme selection survives provider-container recreation', (
    tester,
  ) async {
    final harness = await _ThemeSettingsHarness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to settings and select dark.
    await tester.tap(find.byKey(mainSettingsButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(themeDarkSegmentKey));
    await tester.pumpAndSettle();

    expect(
      harness.sharedPreferences.getString(
        PreferencesRepositoryImpl.themeModeKey,
      ),
      'dark',
    );

    // Tear down and rebuild with a fresh container but same SharedPreferences.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final secondContainer = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            backendUrl: 'https://wrait-backend.vercel.app',
            proxySecret: '',
            recordingHardCapMs: 120000,
          ),
        ),
        appRouterProvider.overrideWithValue(buildAppRouter()),
        appLockEnabledProvider.overrideWithValue(false),
        localEntryDatabaseProvider.overrideWithValue(harness.database),
        sharedPreferencesProvider.overrideWithValue(
          harness.sharedPreferences,
        ),
        transcriptionServiceProvider.overrideWithValue(
          const _IdleTranscriptionService(),
        ),
      ],
    );
    addTearDown(secondContainer.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: secondContainer,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp).last,
    );
    expect(materialApp.themeMode, ThemeMode.dark);
  });
}

class _ThemeSettingsHarness {
  _ThemeSettingsHarness({
    required this.container,
    required this.database,
    required this.tempDirectory,
    required this.sharedPreferences,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory tempDirectory;
  final SharedPreferences sharedPreferences;

  static Future<_ThemeSettingsHarness> create({
    Map<String, Object> initialPreferences = const <String, Object>{},
  }) async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'wrait-theme-settings-int',
    );
    final database = await LocalEntryDatabase.open(
      keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(48)),
      databaseFile: File(
        '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
      ),
    );
    SharedPreferences.setMockInitialValues(initialPreferences);
    final sharedPreferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            backendUrl: 'https://wrait-backend.vercel.app',
            proxySecret: '',
            recordingHardCapMs: 120000,
          ),
        ),
        appRouterProvider.overrideWithValue(buildAppRouter()),
        appLockEnabledProvider.overrideWithValue(false),
        localEntryDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        transcriptionServiceProvider.overrideWithValue(
          const _IdleTranscriptionService(),
        ),
      ],
    );

    return _ThemeSettingsHarness(
      container: container,
      database: database,
      tempDirectory: tempDirectory,
      sharedPreferences: sharedPreferences,
    );
  }

  Future<void> dispose() async {
    container.dispose();
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

class _IdleTranscriptionService implements TranscriptionService {
  const _IdleTranscriptionService();

  @override
  int? get hardCapDeadlineElapsedRealtime => null;

  @override
  bool get isRecording => false;

  @override
  bool get isTranscribing => false;

  @override
  Future<void> cancelLiveTranscription() async {}

  @override
  Future<void> startLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {}

  @override
  Future<TranscriptionResult> stopLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async => throw StateError('No recording is active.');

  @override
  Future<TranscriptionResult> transcribeAudioDraft(String audioPath) async =>
      throw StateError('No draft retry is active.');
}
