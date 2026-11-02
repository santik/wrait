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
    'selects a regional language, persists it, shows it on main, and clears it',
    (tester) async {
      final harness = await _LanguageSettingsHarness.create();
      addTearDown(harness.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(mainTranscriptionLanguageKey), findsNothing);
      await tester.tap(find.byKey(mainSettingsButtonKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(transcriptionLanguageDropdownKey));
      await tester.pumpAndSettle();
      await _selectDropdownOption(tester, 'zh', scrollDelta: 240);
      await tester.pumpAndSettle();
      expect(
        harness.sharedPreferences.getString(
          PreferencesRepositoryImpl.transcriptionLanguageKey,
        ),
        'zh',
      );

      await tester.tap(find.byKey(transcriptionLanguageDropdownKey));
      await tester.pumpAndSettle();
      await _selectDropdownOption(tester, 'de-CH', scrollDelta: -240);
      await tester.pumpAndSettle();
      expect(
        harness.sharedPreferences.getString(
          PreferencesRepositoryImpl.transcriptionLanguageKey,
        ),
        'de-CH',
      );

      await tester.tap(find.byKey(settingsBackButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('Language: Deutsch (Schweiz)'), findsOneWidget);

      await tester.tap(find.byKey(mainTranscriptionLanguageKey));
      await tester.pumpAndSettle();
      expect(find.byKey(transcriptionLanguageDropdownKey), findsOneWidget);
      expect(
        tester
            .widget<Focus>(
              find
                  .descendant(
                    of: find.byKey(transcriptionLanguageFocusKey),
                    matching: find.byType(Focus),
                  )
                  .first,
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.tap(find.byKey(transcriptionLanguageDropdownKey));
      await tester.pumpAndSettle();
      await _selectDropdownOption(tester, '__automatic__', scrollDelta: -240);
      await tester.pumpAndSettle();
      expect(
        harness.sharedPreferences.containsKey(
          PreferencesRepositoryImpl.transcriptionLanguageKey,
        ),
        isFalse,
      );

      await tester.tap(find.byKey(settingsBackButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(mainTranscriptionLanguageKey), findsNothing);
    },
  );
}

Future<void> _selectDropdownOption(
  WidgetTester tester,
  String languageCode, {
  required double scrollDelta,
}) async {
  final option =
      (languageCode == '__automatic__'
              ? find.byKey(transcriptionLanguageAutomaticKey)
              : find.byKey(transcriptionLanguageOptionKey(languageCode)))
          .last;
  await tester.scrollUntilVisible(
    option,
    scrollDelta,
    scrollable: find.byType(Scrollable).last,
  );
  await Scrollable.ensureVisible(tester.element(option), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

class _LanguageSettingsHarness {
  _LanguageSettingsHarness({
    required this.container,
    required this.database,
    required this.tempDirectory,
    required this.sharedPreferences,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory tempDirectory;
  final SharedPreferences sharedPreferences;

  static Future<_LanguageSettingsHarness> create() async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'wrait-language-settings-int',
    );
    final database = await LocalEntryDatabase.open(
      keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(48)),
      databaseFile: File(
        '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
      ),
    );
    SharedPreferences.setMockInitialValues(const <String, Object>{});
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

    return _LanguageSettingsHarness(
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
