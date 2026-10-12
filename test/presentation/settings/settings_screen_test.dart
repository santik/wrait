import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/auth/app_lock_authenticator.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/repository/app_lock_preferences_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/domain/repository/theme_preferences_repository.dart';
import 'package:wrait/domain/repository/transcription_language_preferences_repository.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';
import 'package:wrait/presentation/settings/settings_screen.dart';
import 'package:wrait/presentation/settings/settings_test_keys.dart';
import 'package:wrait/presentation/theme/wrait_theme.dart';

import '../../test_doubles/l10n_test_helper.dart';

void main() {
  testWidgets('shows disabled default and enables without authenticating', (
    tester,
  ) async {
    final repository = _PreferencesRepository();
    final authenticator = _Authenticator();
    await tester.pumpWidget(
      _app(repository: repository, authenticator: authenticator),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(find.byKey(appLockSwitchKey)).value,
      false,
    );

    await tester.tap(find.byKey(appLockSwitchKey));
    await tester.pumpAndSettle();

    expect(repository.enabled, isTrue);
    expect(authenticator.authenticateCalls, 0);
    expect(
      tester.widget<SwitchListTile>(find.byKey(appLockSwitchKey)).value,
      true,
    );
  });

  testWidgets('selects and clears the transcription language immediately', (
    tester,
  ) async {
    final repository = _PreferencesRepository();
    await tester.pumpWidget(
      _app(repository: repository, authenticator: _Authenticator()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Automatic detection'), findsWidgets);
    await tester.tap(find.byKey(transcriptionLanguageDropdownKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(transcriptionLanguageOptionKey('bg')).last);
    await tester.pumpAndSettle();
    expect(repository.language, 'bg');
    expect(find.text('Български'), findsWidgets);

    await tester.tap(find.byKey(transcriptionLanguageDropdownKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(transcriptionLanguageAutomaticKey).last);
    await tester.pumpAndSettle();
    expect(repository.language, isNull);
    expect(find.text('Automatic detection'), findsWidgets);
  });

  testWidgets('focused entry scrolls to and focuses the compact dropdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        repository: _PreferencesRepository(),
        authenticator: _Authenticator(),
        focusTranscriptionLanguage: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(transcriptionLanguageSectionKey), findsOneWidget);
    expect(
      tester
          .widget<DropdownMenu<String>>(
            find.byKey(transcriptionLanguageDropdownKey),
          )
          .enabled,
      isTrue,
    );
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
    expect(
      tester.getRect(find.byKey(transcriptionLanguageDropdownKey)).bottom,
      lessThanOrEqualTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      ),
    );
  });

  testWidgets('uses themed body typography and compact menu rows', (
    tester,
  ) async {
    for (final theme in [wraitLightTheme, wraitDarkTheme]) {
      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownMenu<String>>(
        find.byKey(transcriptionLanguageDropdownKey),
      );
      final activeTheme = Theme.of(
        tester.element(find.byKey(transcriptionLanguageDropdownKey)),
      );
      final firstEntry = dropdown.dropdownMenuEntries.first;
      expect(dropdown.textStyle, activeTheme.textTheme.bodyLarge);
      expect(
        firstEntry.style?.textStyle?.resolve(const <WidgetState>{}),
        activeTheme.textTheme.bodyLarge,
      );
      expect(
        firstEntry.style?.visualDensity,
        VisualDensity.compact,
      );

      await tester.tap(find.byKey(transcriptionLanguageDropdownKey));
      await tester.pumpAndSettle();
      final menuItem = find
          .ancestor(
            of: find.byKey(transcriptionLanguageOptionKey('bg')).last,
            matching: find.byType(MenuItemButton),
          )
          .last;
      expect(tester.getSize(menuItem).height, 40);

      await tester.tap(find.byKey(transcriptionLanguageOptionKey('bg')).last);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('failed language save reverts the dropdown text', (
    tester,
  ) async {
    final repository = _PreferencesRepository();
    await tester.pumpWidget(
      _app(repository: repository, authenticator: _Authenticator()),
    );
    await tester.pumpAndSettle();

    String fieldText() => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(transcriptionLanguageDropdownKey),
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;

    expect(fieldText(), 'Automatic detection');

    repository.failSave = true;
    await tester.tap(find.byKey(transcriptionLanguageDropdownKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(transcriptionLanguageOptionKey('bg')).last);
    await tester.pumpAndSettle();

    expect(repository.language, isNull);
    expect(fieldText(), 'Automatic detection');
  });

  testWidgets('keyboard does not open the menu while changes are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        repository: _PreferencesRepository(),
        authenticator: _Authenticator(),
        focusTranscriptionLanguage: true,
        recordingController: _RecordingController.new,
      ),
    );
    await tester.pumpAndSettle();

    final focusNode = tester
        .widget<Focus>(
          find
              .descendant(
                of: find.byKey(transcriptionLanguageFocusKey),
                matching: find.byType(Focus),
              )
              .first,
        )
        .focusNode!;
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(_menuIsOpen(tester), isFalse);
  });

  testWidgets('keyboard opens the menu when changes are enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        repository: _PreferencesRepository(),
        authenticator: _Authenticator(),
        focusTranscriptionLanguage: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(_menuIsOpen(tester), isTrue);
  });

  testWidgets('no security keeps switch off and offers device settings', (
    tester,
  ) async {
    final repository = _PreferencesRepository();
    final authenticator = _Authenticator(
      nextAvailability: AppLockAvailability.noSecurityConfigured,
    );
    await tester.pumpWidget(
      _app(repository: repository, authenticator: authenticator),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(appLockSwitchKey));
    await tester.pumpAndSettle();

    expect(repository.enabled, isFalse);
    expect(find.byKey(appLockDeviceSettingsKey), findsOneWidget);
    expect(find.textContaining('Set up a device screen lock'), findsOneWidget);
  });

  testWidgets('large text keeps settings controls reachable', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('App lock'), findsOneWidget);
    expect(find.byKey(appLockSwitchKey), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(transcriptionLanguageDropdownKey),
      200,
    );
    expect(find.byKey(transcriptionLanguageDropdownKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme segmented button defaults to system and switches modes', (
    tester,
  ) async {
    final repository = _PreferencesRepository();
    await tester.pumpWidget(
      _app(repository: repository, authenticator: _Authenticator()),
    );
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<ThemeMode>>(
      find.byKey(themeSegmentedButtonKey),
    );
    expect(segmented.selected, {ThemeMode.system});

    await tester.tap(find.byKey(themeDarkSegmentKey));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SegmentedButton<ThemeMode>>(
        find.byKey(themeSegmentedButtonKey),
      ).selected,
      {ThemeMode.dark},
    );
    expect(repository.themeMode, 'dark');

    await tester.tap(find.byKey(themeLightSegmentKey));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SegmentedButton<ThemeMode>>(
        find.byKey(themeSegmentedButtonKey),
      ).selected,
      {ThemeMode.light},
    );
    expect(repository.themeMode, 'light');
  });

  testWidgets('theme save failure shows error message', (tester) async {
    final repository = _PreferencesRepository()..failThemeSave = true;
    await tester.pumpWidget(
      _app(repository: repository, authenticator: _Authenticator()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(themeDarkSegmentKey));
    await tester.pumpAndSettle();

    expect(find.byKey(themeSaveFailedKey), findsOneWidget);
  });

  testWidgets('recording disables theme segmented button', (tester) async {
    await tester.pumpWidget(
      _app(
        repository: _PreferencesRepository(),
        authenticator: _Authenticator(),
        recordingController: _RecordingController.new,
      ),
    );
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<ThemeMode>>(
      find.byKey(themeSegmentedButtonKey),
    );
    expect(segmented.onSelectionChanged, isNull);
  });

  testWidgets('recording disables changes until recording stops', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        repository: _PreferencesRepository(),
        authenticator: _Authenticator(),
        recordingController: _RecordingController.new,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(find.byKey(appLockSwitchKey)).onChanged,
      isNull,
    );
    expect(
      tester
          .widget<DropdownMenu<String>>(
            find.byKey(transcriptionLanguageDropdownKey),
          )
          .enabled,
      isFalse,
    );
    expect(
      find.text('Finish the current recording or transcription before changing settings.'),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    final controller = container.read(
      mainRecordingControllerProvider.notifier,
    ) as _RecordingController;
    controller.finishRecording();
    await tester.pump();

    expect(
      tester.widget<SwitchListTile>(find.byKey(appLockSwitchKey)).onChanged,
      isNotNull,
    );
    expect(
      tester
          .widget<DropdownMenu<String>>(
            find.byKey(transcriptionLanguageDropdownKey),
          )
          .enabled,
      isTrue,
    );
    expect(
      find.text('Finish the current recording or transcription before changing settings.'),
      findsNothing,
    );
  });
}

bool _menuIsOpen(WidgetTester tester) {
  return tester
      .widget<MenuAnchor>(
        find
            .descendant(
              of: find.byKey(transcriptionLanguageDropdownKey),
              matching: find.byType(MenuAnchor),
            )
            .first,
      )
      .controller!
      .isOpen;
}

Widget _app({
  required _PreferencesRepository repository,
  required _Authenticator authenticator,
  MainRecordingController Function()? recordingController,
  bool focusTranscriptionLanguage = false,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      preferencesRepositoryProvider.overrideWithValue(repository),
      appLockAuthenticatorProvider.overrideWithValue(authenticator),
      mainRecordingControllerProvider.overrideWith(
        recordingController ?? _IdleController.new,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      theme: theme,
      home: SettingsScreen(
        focusTranscriptionLanguage: focusTranscriptionLanguage,
      ),
    ),
  );
}

class _IdleController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();
}

class _RecordingController extends MainRecordingController {
  @override
  RecordingControllerState build() => RecordingControllerState(
    recordingState: RecordingListening(hardCapDeadlineElapsedRealtime: 1),
  );

  void finishRecording() {
    state = const RecordingControllerState();
  }
}

class _PreferencesRepository
    implements
        PreferencesRepository,
        AppLockPreferencesRepository,
        ThemePreferencesRepository,
        TranscriptionLanguagePreferencesRepository {
  bool enabled = false;
  String? language;
  String? themeMode;
  bool failSave = false;
  bool failThemeSave = false;

  @override
  Future<bool> getAppLockEnabled() async => enabled;

  @override
  Future<void> setAppLockEnabled(bool value) async {
    enabled = value;
  }

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => false;

  @override
  Future<void> setHasEverRecorded(bool value) async {}

  @override
  Future<String?> getTranscriptionLanguage() async => language;

  @override
  Future<void> setTranscriptionLanguage(String? value) async {
    if (failSave) {
      throw StateError('save failed');
    }
    language = value;
  }

  @override
  Future<String?> getThemeMode() async => themeMode;

  @override
  Future<void> setThemeMode(String value) async {
    if (failThemeSave) {
      throw StateError('save failed');
    }
    themeMode = value;
  }
}

class _Authenticator implements AppLockAuthenticator {
  _Authenticator({this.nextAvailability = AppLockAvailability.available});

  final AppLockAvailability nextAvailability;
  int authenticateCalls = 0;

  @override
  Future<AppLockAvailability> availability() async => nextAvailability;

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
