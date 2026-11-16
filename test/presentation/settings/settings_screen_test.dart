import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/auth/app_lock_authenticator.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/entries/entry_export_file_writer.dart';
import 'package:wrait/data/entries/entry_export_providers.dart';
import 'package:wrait/data/entries/entry_import_file_reader.dart';
import 'package:wrait/data/entries/entry_import_providers.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/app_lock_preferences_repository.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/domain/repository/theme_preferences_repository.dart';
import 'package:wrait/domain/repository/transcription_language_preferences_repository.dart';
import 'package:wrait/domain/service/entry_export_service.dart';
import 'package:wrait/domain/service/entry_import_service.dart';
import 'package:wrait/presentation/entries/entry_list_controller.dart';
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
    await tester.dragUntilVisible(
      find.text(
        'Finish the current recording or transcription before changing settings.',
      ),
      find.byType(ListView),
      const Offset(0, -200),
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

    // Feature 058 added a Backup & restore section below, lengthening the list;
    // scroll back to the top so the re-enabled top controls are built again.
    await tester.dragUntilVisible(
      find.byKey(appLockSwitchKey),
      find.byType(ListView),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();

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

  group('Backup & restore', () {
    Future<void> scrollToBackup(WidgetTester tester, Key key) async {
      await tester.dragUntilVisible(
        find.byKey(key),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows a titled section with labeled export and import actions',
        (tester) async {
      final entryRepository = _TestEntryRepository();
      addTearDown(entryRepository.dispose);
      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          entryRepository: entryRepository,
        ),
      );
      await tester.pumpAndSettle();

      await scrollToBackup(tester, backupSectionKey);

      expect(find.byKey(backupSectionKey), findsOneWidget);
      expect(find.text('Backup & restore'), findsOneWidget);
      expect(find.byKey(backupExportButtonKey), findsOneWidget);
      expect(find.byKey(backupImportButtonKey), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      expect(
        find.text(
          'Save all your entries to a CSV file, or add entries from one '
          'you exported before.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('export covers the whole library and shows destination feedback',
        (tester) async {
      final entryRepository = _TestEntryRepository()
        ..emitEntries([
          _entry(id: 2, createdAt: DateTime(2026, 6, 15, 9), type: EntryType.draft),
          _entry(id: 1, createdAt: DateTime(2026, 6, 14, 9)),
        ]);
      addTearDown(entryRepository.dispose);
      final exportFileWriter = _CapturingExportFileWriter();

      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          entryRepository: entryRepository,
          exportService: EntryExportService(
            fileWriter: exportFileWriter,
            now: () => DateTime.utc(2026, 6, 30, 12, 34, 56),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await scrollToBackup(tester, backupExportButtonKey);
      await tester.tap(find.byKey(backupExportButtonKey));
      await tester.pumpAndSettle();

      expect(
        find.text('Exported wrait-entries-20260630-123456.csv to Downloads/Wrait.'),
        findsOneWidget,
      );
      expect(
        exportFileWriter.lastContents,
        contains(
          'type,created_at,language,word_count,raw_transcript,cleaned_text,tags',
        ),
      );
      expect(exportFileWriter.lastContents, contains('draft,'));
      expect(exportFileWriter.lastContents, contains('entry 2'));
      expect(exportFileWriter.lastContents, contains('entry 1'));
    });

    testWidgets('export failure shows an error', (tester) async {
      final entryRepository = _TestEntryRepository()..emitEntries([_entry(id: 1)]);
      addTearDown(entryRepository.dispose);

      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          entryRepository: entryRepository,
          exportService: EntryExportService(
            fileWriter: const _ThrowingExportFileWriter(),
            now: () => DateTime.utc(2026, 6, 30, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await scrollToBackup(tester, backupExportButtonKey);
      await tester.tap(find.byKey(backupExportButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('Could not export entries.'), findsOneWidget);
    });

    testWidgets('export shows progress and prevents duplicate taps',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final entryRepository = _TestEntryRepository()..emitEntries([_entry(id: 1)]);
      addTearDown(entryRepository.dispose);
      final exportCompleter = Completer<EntryExportFileWriteResult>();
      final delayedWriter =
          _CapturingExportFileWriter(completer: exportCompleter);

      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          entryRepository: entryRepository,
          exportService: EntryExportService(
            fileWriter: delayedWriter,
            now: () => DateTime.utc(2026, 6, 30, 14),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await scrollToBackup(tester, backupExportButtonKey);
      await tester.tap(find.byKey(backupExportButtonKey));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Exporting entries')), findsWidgets);
      expect(delayedWriter.callCount, 1);

      await tester.tap(find.byKey(backupExportButtonKey));
      await tester.pump();
      expect(delayedWriter.callCount, 1);

      exportCompleter.complete(
        const EntryExportFileWriteResult(
          fileName: 'wrait-entries-20260630-140000.csv',
          pathLabel: 'Downloads/Wrait',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      semanticsHandle.dispose();
    });

    testWidgets('import success shows added-count feedback', (tester) async {
      final entryRepository = _TestEntryRepository();
      addTearDown(entryRepository.dispose);

      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          entryRepository: entryRepository,
          importService: EntryImportService(
            fileReader: _TestImportFileReader(
              result: EntryImportFileReadResult(
                fileName: 'import.csv',
                contents: _validImportCsv(),
              ),
            ),
            entryRepository: entryRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await scrollToBackup(tester, backupImportButtonKey);
      await tester.tap(find.byKey(backupImportButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('Imported 2 records from import.csv.'), findsOneWidget);
    });

    testWidgets('import unreadable file shows the unreadable error',
        (tester) async {
      final entryRepository = _TestEntryRepository();
      addTearDown(entryRepository.dispose);

      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          entryRepository: entryRepository,
          importService: EntryImportService(
            fileReader: const _ThrowingImportFileReader(),
            entryRepository: entryRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await scrollToBackup(tester, backupImportButtonKey);
      await tester.tap(find.byKey(backupImportButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('Could not read the selected CSV file.'), findsOneWidget);
    });

    testWidgets('import invalid format shows the invalid-format error',
        (tester) async {
      final entryRepository = _TestEntryRepository();
      addTearDown(entryRepository.dispose);

      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          entryRepository: entryRepository,
          importService: EntryImportService(
            fileReader: _TestImportFileReader(
              result: const EntryImportFileReadResult(
                fileName: 'bad.csv',
                contents: 'not,a,valid,wrait,header\n',
              ),
            ),
            entryRepository: entryRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await scrollToBackup(tester, backupImportButtonKey);
      await tester.tap(find.byKey(backupImportButtonKey));
      await tester.pumpAndSettle();

      expect(
        find.text('Selected CSV is not a valid Wrait export.'),
        findsOneWidget,
      );
    });

    testWidgets('import too large shows the too-large error', (tester) async {
      final entryRepository = _TestEntryRepository();
      addTearDown(entryRepository.dispose);

      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          entryRepository: entryRepository,
          importService: EntryImportService(
            fileReader: _TestImportFileReader(
              result: const EntryImportFileReadResult(
                fileName: 'big.csv',
                contents:
                    'type,created_at,language,word_count,raw_transcript,cleaned_text\n',
              ),
            ),
            entryRepository: entryRepository,
            maxImportBytes: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await scrollToBackup(tester, backupImportButtonKey);
      await tester.tap(find.byKey(backupImportButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('Selected CSV is too large to import.'), findsOneWidget);
    });

    testWidgets('import storage failure shows the storage error', (tester) async {
      final entryRepository = _TestEntryRepository()..throwsOnImport = true;
      addTearDown(entryRepository.dispose);

      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          entryRepository: entryRepository,
          importService: EntryImportService(
            fileReader: _TestImportFileReader(
              result: EntryImportFileReadResult(
                fileName: 'import.csv',
                contents: _validImportCsv(),
              ),
            ),
            entryRepository: entryRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await scrollToBackup(tester, backupImportButtonKey);
      await tester.tap(find.byKey(backupImportButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('Could not save imported entries.'), findsOneWidget);
    });

    testWidgets('import cancellation shows no snackbar', (tester) async {
      final entryRepository = _TestEntryRepository();
      addTearDown(entryRepository.dispose);

      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          entryRepository: entryRepository,
          importService: EntryImportService(
            fileReader: _TestImportFileReader(result: null),
            entryRepository: entryRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await scrollToBackup(tester, backupImportButtonKey);
      await tester.tap(find.byKey(backupImportButtonKey));
      await tester.pumpAndSettle();

      expect(find.textContaining('Imported '), findsNothing);
      expect(find.text('Could not read the selected CSV file.'), findsNothing);
    });

    testWidgets('import shows progress and prevents duplicate taps',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final entryRepository = _TestEntryRepository();
      addTearDown(entryRepository.dispose);
      final importCompleter = Completer<EntryImportFileReadResult?>();
      final delayedReader = _TestImportFileReader(completer: importCompleter);

      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          entryRepository: entryRepository,
          importService: EntryImportService(
            fileReader: delayedReader,
            entryRepository: entryRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await scrollToBackup(tester, backupImportButtonKey);
      await tester.tap(find.byKey(backupImportButtonKey));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Importing entries')), findsWidgets);
      expect(delayedReader.callCount, 1);

      await tester.tap(find.byKey(backupImportButtonKey));
      await tester.pump();
      expect(delayedReader.callCount, 1);

      importCompleter.complete(
        EntryImportFileReadResult(
          fileName: 'import.csv',
          contents: _validImportCsv(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      semanticsHandle.dispose();
    });

    testWidgets('export and import stay enabled while recording is active',
        (tester) async {
      final entryRepository = _TestEntryRepository();
      addTearDown(entryRepository.dispose);

      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          entryRepository: entryRepository,
          recordingController: _RecordingController.new,
        ),
      );
      await tester.pumpAndSettle();

      await scrollToBackup(tester, backupExportButtonKey);

      expect(
        tester.widget<OutlinedButton>(find.byKey(backupExportButtonKey)).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byKey(backupImportButtonKey)).onPressed,
        isNotNull,
      );
    });

    testWidgets('export is disabled while the library snapshot is unavailable',
        (tester) async {
      final entryRepository = _TestEntryRepository()..errorOnWatch = true;
      addTearDown(entryRepository.dispose);
      final exportFileWriter = _CapturingExportFileWriter();

      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          entryRepository: entryRepository,
          exportService: EntryExportService(
            fileWriter: exportFileWriter,
            now: () => DateTime.utc(2026, 6, 30, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await scrollToBackup(tester, backupExportButtonKey);

      // A cold/errored entries stream must not let the user produce a
      // (header-only) CSV with a success message: Export stays disabled.
      expect(
        tester.widget<OutlinedButton>(find.byKey(backupExportButtonKey)).onPressed,
        isNull,
      );
      await tester.tap(find.byKey(backupExportButtonKey));
      await tester.pumpAndSettle();
      expect(exportFileWriter.callCount, 0);
      expect(find.textContaining('Exported '), findsNothing);
    });

    testWidgets('export covers the whole library regardless of a search filter',
        (tester) async {
      final entryRepository = _TestEntryRepository()
        ..emitEntries([
          _entry(id: 2, rawTranscript: 'alpha record'),
          _entry(id: 1, rawTranscript: 'beta record'),
        ]);
      addTearDown(entryRepository.dispose);
      final exportFileWriter = _CapturingExportFileWriter();

      await tester.pumpWidget(
        _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
          entryRepository: entryRepository,
          exportService: EntryExportService(
            fileWriter: exportFileWriter,
            now: () => DateTime.utc(2026, 6, 30, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A search query that would hide one entry must not narrow the export —
      // the Backup section reads the full library, not the filtered view.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      container.read(entryListSearchQueryProvider.notifier).update('alpha');
      await tester.pumpAndSettle();

      await scrollToBackup(tester, backupExportButtonKey);
      await tester.tap(find.byKey(backupExportButtonKey));
      await tester.pumpAndSettle();

      expect(exportFileWriter.lastContents, contains('alpha record'));
      expect(exportFileWriter.lastContents, contains('beta record'));
    });
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
  _TestEntryRepository? entryRepository,
  EntryExportService? exportService,
  EntryImportService? importService,
}) {
  return ProviderScope(
    overrides: [
      preferencesRepositoryProvider.overrideWithValue(repository),
      appLockAuthenticatorProvider.overrideWithValue(authenticator),
      mainRecordingControllerProvider.overrideWith(
        recordingController ?? _IdleController.new,
      ),
      if (entryRepository != null)
        entryRepositoryProvider.overrideWithValue(entryRepository),
      if (exportService != null)
        entryExportServiceProvider.overrideWithValue(exportService),
      if (importService != null)
        entryImportServiceProvider.overrideWithValue(importService),
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

Entry _entry({
  required int id,
  DateTime? createdAt,
  EntryType type = EntryType.saved,
  String? rawTranscript,
  String? cleanedText,
}) {
  return Entry(
    id: id,
    rawTranscript: rawTranscript ?? 'entry $id',
    cleanedText: cleanedText ?? 'clean entry $id',
    type: type,
    language: 'en-US',
    createdAt: (createdAt ?? DateTime(2026, 6, 15, 9)).millisecondsSinceEpoch,
    wordCount: 3,
  );
}

class _TestEntryRepository implements EntryRepository {
  final StreamController<List<Entry>> _controller =
      StreamController<List<Entry>>.broadcast();
  List<Entry> _entries = const <Entry>[];
  bool throwsOnImport = false;
  bool errorOnWatch = false;

  void emitEntries(List<Entry> entries) {
    _entries = List<Entry>.from(entries);
    _controller.add(_entries);
  }

  Future<void> dispose() => _controller.close();

  @override
  Stream<List<Entry>> watchAllEntries() async* {
    if (errorOnWatch) {
      throw StateError('watch failed');
    }
    yield _entries;
    yield* _controller.stream;
  }

  @override
  Stream<Entry?> watchEntryById(int id) async* {
    yield null;
  }

  @override
  Future<Entry?> getEntryById(int id) async => null;

  @override
  Future<List<int>> importEntries(List<Entry> entries) async {
    if (throwsOnImport) {
      throw StateError('import storage failed');
    }
    final ids = <int>[];
    var nextId = _entries.fold<int>(
      0,
      (current, entry) => entry.id > current ? entry.id : current,
    );
    for (final entry in entries) {
      nextId += 1;
      ids.add(nextId);
      _entries = [..._entries, entry.copyWith(id: nextId)];
    }
    _controller.add(_entries);
    return ids;
  }

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

class _CapturingExportFileWriter implements EntryExportFileWriter {
  _CapturingExportFileWriter({this._completer});

  final Completer<EntryExportFileWriteResult>? _completer;
  int callCount = 0;
  String lastContents = '';

  @override
  Future<EntryExportFileWriteResult> writeCsvExport({
    required String fileName,
    required String contents,
  }) {
    callCount += 1;
    lastContents = contents;
    return _completer?.future ??
        Future<EntryExportFileWriteResult>.value(
          EntryExportFileWriteResult(
            fileName: fileName,
            pathLabel: 'Downloads/Wrait',
          ),
        );
  }
}

class _ThrowingExportFileWriter implements EntryExportFileWriter {
  const _ThrowingExportFileWriter();

  @override
  Future<EntryExportFileWriteResult> writeCsvExport({
    required String fileName,
    required String contents,
  }) async {
    throw StateError('export failed');
  }
}

class _TestImportFileReader implements EntryImportFileReader {
  _TestImportFileReader({this.result, this.completer});

  final EntryImportFileReadResult? result;
  final Completer<EntryImportFileReadResult?>? completer;
  int callCount = 0;

  @override
  Future<EntryImportFileReadResult?> pickCsvImport() async {
    callCount += 1;
    return completer?.future ?? result;
  }
}

class _ThrowingImportFileReader implements EntryImportFileReader {
  const _ThrowingImportFileReader();

  @override
  Future<EntryImportFileReadResult?> pickCsvImport() async {
    throw const EntryImportFileReaderException('import failed');
  }
}

String _validImportCsv() {
  final createdAtMs = DateTime.utc(2026, 6, 30, 12).millisecondsSinceEpoch;
  return [
    'type,created_at,language,word_count,raw_transcript,cleaned_text',
    'saved,$createdAtMs,en-US,3,imported saved entry,clean entry 21',
    'draft,$createdAtMs,fr-FR,3,imported draft entry,',
  ].join('\n');
}
