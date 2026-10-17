import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/entries/entry_export_file_writer.dart';
import 'package:wrait/data/entries/entry_export_providers.dart';
import 'package:wrait/data/entries/entry_import_file_reader.dart';
import 'package:wrait/data/entries/entry_import_providers.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/domain/service/entry_export_service.dart';
import 'package:wrait/domain/service/entry_import_service.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../../test_doubles/l10n_test_helper.dart';

void main() {
  late _TestEntryRepository entryRepository;
  late _CapturingExportFileWriter exportFileWriter;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    entryRepository = _TestEntryRepository();
    exportFileWriter = _CapturingExportFileWriter();
  });

  tearDown(() async {
    await entryRepository.dispose();
  });

  testWidgets('shows the centered empty state when no entries exist', (
    tester,
  ) async {
    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    expect(find.text('no entries yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('entryListView')), findsNothing);
    expect(find.byKey(const ValueKey('entryListExportButton')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryListImportButton')), findsOneWidget);
  });

  testWidgets('uses a compact single-row entry-list header', (tester) async {
    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    final backRect = tester.getRect(
      find.byKey(const ValueKey('entryListBackButton')),
    );
    final searchRect = tester.getRect(
      find.byKey(const ValueKey('entryListSearchField')),
    );
    final importRect = tester.getRect(
      find.byKey(const ValueKey('entryListImportButton')),
    );
    final exportRect = tester.getRect(
      find.byKey(const ValueKey('entryListExportButton')),
    );
    final screenWidth = tester.getSize(find.byType(Scaffold)).width;

    expect(backRect.left, lessThanOrEqualTo(4));
    expect(searchRect.left, greaterThan(backRect.right));
    expect(searchRect.right, lessThan(importRect.left));
    expect(searchRect.center.dy, closeTo(backRect.center.dy, 0.01));
    expect(importRect.right, closeTo(exportRect.left, 0.01));
    expect(exportRect.right, greaterThan(screenWidth - 8));
  });

  testWidgets('renders populated entries newest first with language labels', (
    tester,
  ) async {
    entryRepository.emitEntries([
      _entry(id: 1, createdAt: DateTime(2026, 6, 14, 9)),
      _entry(id: 2, createdAt: DateTime(2026, 6, 15, 9), type: EntryType.draft),
    ]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    final firstRowTop = tester
        .getTopLeft(find.byKey(const ValueKey('entryRow-2')))
        .dy;
    final secondRowTop = tester
        .getTopLeft(find.byKey(const ValueKey('entryRow-1')))
        .dy;

    expect(firstRowTop, lessThan(secondRowTop));
    expect(find.text('draft'), findsOneWidget);
    expect(find.text('English'), findsNWidgets(2));
  });

  testWidgets(
    'renders a non-autofocused accessible search field and filters all terms',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      entryRepository.emitEntries([
        _entry(
          id: 3,
          rawTranscript: 'Monday morning reflection',
          cleanedText: 'Project planning notes',
        ),
        _entry(
          id: 2,
          rawTranscript: 'Project update',
          cleanedText: 'Tuesday work',
        ),
        _entry(
          id: 1,
          rawTranscript: 'Monday walk',
          cleanedText: 'Personal reflection',
        ),
      ]);

      await _pumpEntryListApp(tester, entryRepository: entryRepository);

      final searchField = find.byKey(const ValueKey('entryListSearchField'));
      final textField = tester.widget<TextField>(searchField);
      expect(textField.autofocus, isFalse);
      expect(find.bySemanticsLabel('Search entries'), findsOneWidget);

      await tester.enterText(searchField, ' PROJECT\n monday ');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('entryRow-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('entryRow-2')), findsNothing);
      expect(find.byKey(const ValueKey('entryRow-1')), findsNothing);
      expect(find.bySemanticsLabel('Clear search'), findsOneWidget);

      semanticsHandle.dispose();
    },
  );

  testWidgets('search action dismisses the keyboard and preserves results', (
    tester,
  ) async {
    entryRepository.emitEntries([
      _entry(id: 1, rawTranscript: 'target entry'),
      _entry(id: 2, rawTranscript: 'other entry'),
    ]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);
    final searchField = find.byKey(const ValueKey('entryListSearchField'));

    await tester.enterText(searchField, 'target');
    await tester.pumpAndSettle();

    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.focusNode.hasFocus, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(editableText.focusNode.hasFocus, isFalse);
    expect(find.byKey(const ValueKey('entryRow-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryRow-2')), findsNothing);
    expect(tester.widget<TextField>(searchField).controller?.text, 'target');
  });

  testWidgets('shows clearable no results and updates from entry changes', (
    tester,
  ) async {
    entryRepository.emitEntries([
      _entry(id: 1, rawTranscript: 'existing record'),
    ]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);
    final searchField = find.byKey(const ValueKey('entryListSearchField'));

    await tester.enterText(searchField, 'target');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('entryListNoSearchResults')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('entryListNoResultsClearButton')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('entryListEmptyState')), findsNothing);

    entryRepository.emitEntries([
      _entry(id: 1, rawTranscript: 'target record'),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryRow-1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('entryListNoSearchResults')),
      findsNothing,
    );

    entryRepository.emitEntries([
      _entry(id: 1, rawTranscript: 'updated record'),
    ]);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('entryListNoSearchResults')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('entryListNoResultsClearButton')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryRow-1')), findsOneWidget);
    expect(tester.widget<TextField>(searchField).controller?.text, isEmpty);
  });

  testWidgets('preserves search after navigating to detail and back', (
    tester,
  ) async {
    entryRepository.emitEntries([
      _entry(id: 2, rawTranscript: 'target entry'),
      _entry(id: 1, rawTranscript: 'other entry'),
    ]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);
    final searchField = find.byKey(const ValueKey('entryListSearchField'));
    await tester.enterText(searchField, 'target');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entryCard-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entryDetailBackButton')));
    await tester.pumpAndSettle();

    final reopenedSearchField = find.byKey(
      const ValueKey('entryListSearchField'),
    );
    expect(
      tester.widget<TextField>(reopenedSearchField).controller?.text,
      'target',
    );
    expect(find.byKey(const ValueKey('entryRow-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryRow-1')), findsNothing);
  });

  testWidgets('row tap navigates to entry detail', (tester) async {
    entryRepository.emitEntries([_entry(id: 7)]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);
    await tester.tap(find.byKey(const ValueKey('entryCard-7')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(find.text('clean entry 7'), findsOneWidget);
  });

  testWidgets('audio-only draft shows retry preview and does not navigate', (
    tester,
  ) async {
    entryRepository.emitEntries([_audioDraftEntry(id: 9)]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    expect(find.text(testL10n().entryListAudioDraftPreview), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entryCard-9')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsNothing);
  });

  testWidgets('back button returns to the main screen', (tester) async {
    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    await tester.tap(find.byKey(const ValueKey('entryListBackButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);
  });

  testWidgets('system back returns to the main screen', (tester) async {
    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);
  });

  testWidgets(
    'system back dismisses the delete dialog before leaving the list',
    (tester) async {
      entryRepository.emitEntries([_entry(id: 8)]);

      await _pumpEntryListApp(tester, entryRepository: entryRepository);

      await tester.drag(
        find.byKey(const ValueKey('entryCard-8')),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('entryDeleteConfirmButton')),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('entryDeleteConfirmButton')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
      expect(find.byKey(const ValueKey('actionButton')), findsNothing);
    },
  );

  testWidgets('exposes back, row, and delete semantics actions', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    entryRepository.emitEntries([_entry(id: 1)]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    expect(find.bySemanticsLabel('Back to main screen'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Entry ')), findsWidgets);
    final semanticsData = tester
        .getSemantics(find.byKey(const ValueKey('entryRow-1')))
        .getSemanticsData();
    final customActions =
        semanticsData.customSemanticsActionIds
            ?.map(CustomSemanticsAction.getAction)
            .whereType<CustomSemanticsAction>()
            .toList() ??
        const <CustomSemanticsAction>[];

    expect(
      customActions,
      contains(CustomSemanticsAction(label: testL10n().entryListDeleteActionLabel)),
    );

    semanticsHandle.dispose();
  });

  testWidgets('delete failure keeps the row visible and stays on the list', (
    tester,
  ) async {
    entryRepository
      ..throwsOnDelete = true
      ..emitEntries([_entry(id: 5)]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    await tester.drag(
      find.byKey(const ValueKey('entryCard-5')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entryDeleteConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryRow-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
  });

  testWidgets('deleting a matching row refreshes the active search results', (
    tester,
  ) async {
    entryRepository.emitEntries([
      _entry(id: 2, rawTranscript: 'target entry'),
      _entry(id: 1, rawTranscript: 'other entry'),
    ]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);
    await tester.enterText(
      find.byKey(const ValueKey('entryListSearchField')),
      'target',
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('entryCard-2')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entryDeleteConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryRow-2')), findsNothing);
    expect(
      find.byKey(const ValueKey('entryListNoSearchResults')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('entryListNoResultsClearButton')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryRow-1')), findsOneWidget);
  });

  testWidgets('delete dialog exposes destructive semantics labels', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    entryRepository.emitEntries([_entry(id: 3)]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    await tester.drag(
      find.byKey(const ValueKey('entryCard-3')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();

    final confirmSemantics = tester
        .getSemantics(find.bySemanticsLabel('Delete entry permanently'))
        .getSemanticsData();
    final cancelSemantics = tester
        .getSemantics(find.bySemanticsLabel('Cancel deletion'))
        .getSemanticsData();

    expect(confirmSemantics.label, 'Delete entry permanently');
    expect(confirmSemantics.hint, 'Removes this entry from the list.');
    expect(cancelSemantics.label, 'Cancel deletion');
    expect(cancelSemantics.hint, 'Keeps this entry in the list.');

    semanticsHandle.dispose();
  });

  testWidgets('export success shows destination feedback and CSV content', (
    tester,
  ) async {
    entryRepository.emitEntries([
      _entry(id: 2, createdAt: DateTime(2026, 6, 15, 9), type: EntryType.draft),
      _entry(id: 1, createdAt: DateTime(2026, 6, 14, 9)),
    ]);

    await _pumpEntryListApp(
      tester,
      entryRepository: entryRepository,
      exportService: EntryExportService(
        fileWriter: exportFileWriter,
        now: () => DateTime.utc(2026, 6, 30, 12, 34, 56),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('entryListExportButton')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Exported wrait-entries-20260630-123456.csv to Downloads/Wrait.',
      ),
      findsOneWidget,
    );
    expect(
      exportFileWriter.lastContents,
      contains(
        'type,created_at,language,word_count,raw_transcript,cleaned_text,tags',
      ),
    );
    expect(exportFileWriter.lastContents, contains('draft,'));
    expect(exportFileWriter.lastContents, isNot(contains('audioPath')));
  });

  testWidgets('export includes nonmatching entries while search is active', (
    tester,
  ) async {
    entryRepository.emitEntries([
      _entry(id: 2, rawTranscript: 'matching record'),
      _entry(id: 1, rawTranscript: 'outside record'),
    ]);

    await _pumpEntryListApp(
      tester,
      entryRepository: entryRepository,
      exportService: EntryExportService(
        fileWriter: exportFileWriter,
        now: () => DateTime.utc(2026, 6, 30, 12),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('entryListSearchField')),
      'matching',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryRow-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryRow-1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('entryListExportButton')));
    await tester.pumpAndSettle();

    expect(exportFileWriter.lastContents, contains('matching record'));
    expect(exportFileWriter.lastContents, contains('outside record'));
  });

  testWidgets('export failure shows an error and keeps the list visible', (
    tester,
  ) async {
    entryRepository.emitEntries([_entry(id: 4)]);

    await _pumpEntryListApp(
      tester,
      entryRepository: entryRepository,
      exportService: EntryExportService(
        fileWriter: const _ThrowingExportFileWriter(),
        now: () => DateTime.utc(2026, 6, 30, 12),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('entryListExportButton')));
    await tester.pumpAndSettle();

    expect(find.text('Could not export entries.'), findsOneWidget);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryRow-4')), findsOneWidget);
  });

  testWidgets('export works from the empty state', (tester) async {
    await _pumpEntryListApp(
      tester,
      entryRepository: entryRepository,
      exportService: EntryExportService(
        fileWriter: exportFileWriter,
        now: () => DateTime.utc(2026, 6, 30, 13),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('entryListExportButton')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Exported wrait-entries-20260630-130000.csv to Downloads/Wrait.',
      ),
      findsOneWidget,
    );
    expect(
      exportFileWriter.lastContents,
      'type,created_at,language,word_count,raw_transcript,cleaned_text,tags\n',
    );
  });

  testWidgets('export button shows progress and prevents duplicate taps', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    entryRepository.emitEntries([_entry(id: 6)]);
    final exportCompleter = Completer<EntryExportFileWriteResult>();
    final delayedWriter = _CapturingExportFileWriter(
      completer: exportCompleter,
    );

    await _pumpEntryListApp(
      tester,
      entryRepository: entryRepository,
      exportService: EntryExportService(
        fileWriter: delayedWriter,
        now: () => DateTime.utc(2026, 6, 30, 14),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('entryListExportButton')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Exporting entries'), findsWidgets);
    expect(delayedWriter.callCount, 1);

    await tester.tap(find.byKey(const ValueKey('entryListExportButton')));
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

  testWidgets(
    'import success shows added-count feedback and renders new rows',
    (tester) async {
      await _pumpEntryListApp(
        tester,
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
      );

      await tester.tap(find.byKey(const ValueKey('entryListImportButton')));
      await tester.pumpAndSettle();

      expect(find.text('Imported 2 records from import.csv.'), findsOneWidget);
      expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
      expect(find.text('clean entry 21'), findsOneWidget);
      expect(find.text('imported draft entry'), findsOneWidget);
    },
  );

  testWidgets('import refreshes matching results while a query is active', (
    tester,
  ) async {
    entryRepository.emitEntries([
      _entry(id: 1, rawTranscript: 'existing entry'),
    ]);

    await _pumpEntryListApp(
      tester,
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
    );

    await tester.enterText(
      find.byKey(const ValueKey('entryListSearchField')),
      'imported',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('entryListNoSearchResults')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('entryListImportButton')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('entryListNoSearchResults')),
      findsNothing,
    );
    expect(find.text('clean entry 21'), findsOneWidget);
    expect(find.text('imported draft entry'), findsOneWidget);
    expect(find.text('existing entry'), findsNothing);
  });

  testWidgets(
    'import cancellation shows no snackbar and keeps the list unchanged',
    (tester) async {
      entryRepository.emitEntries([_entry(id: 8)]);

      await _pumpEntryListApp(
        tester,
        entryRepository: entryRepository,
        importService: EntryImportService(
          fileReader: _TestImportFileReader(result: null),
          entryRepository: entryRepository,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('entryListImportButton')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Imported '), findsNothing);
      expect(find.text('Could not read the selected CSV file.'), findsNothing);
      expect(find.byKey(const ValueKey('entryRow-8')), findsOneWidget);
    },
  );

  testWidgets('import failure shows an error and keeps the list visible', (
    tester,
  ) async {
    entryRepository.emitEntries([_entry(id: 4)]);

    await _pumpEntryListApp(
      tester,
      entryRepository: entryRepository,
      importService: EntryImportService(
        fileReader: const _ThrowingImportFileReader(),
        entryRepository: entryRepository,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('entryListImportButton')));
    await tester.pumpAndSettle();

    expect(find.text('Could not read the selected CSV file.'), findsOneWidget);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryRow-4')), findsOneWidget);
  });

  testWidgets('import works from a valid header-only csv', (tester) async {
    await _pumpEntryListApp(
      tester,
      entryRepository: entryRepository,
      importService: EntryImportService(
        fileReader: _TestImportFileReader(
          result: EntryImportFileReadResult(
            fileName: 'empty.csv',
            contents:
                'type,created_at,language,word_count,raw_transcript,cleaned_text\n',
          ),
        ),
        entryRepository: entryRepository,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('entryListImportButton')));
    await tester.pumpAndSettle();

    expect(find.text('Imported 0 records from empty.csv.'), findsOneWidget);
    expect(find.text('no entries yet'), findsOneWidget);
  });

  testWidgets('import button shows progress and prevents duplicate taps', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final importCompleter = Completer<EntryImportFileReadResult?>();
    final delayedReader = _TestImportFileReader(completer: importCompleter);

    await _pumpEntryListApp(
      tester,
      entryRepository: entryRepository,
      importService: EntryImportService(
        fileReader: delayedReader,
        entryRepository: entryRepository,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('entryListImportButton')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Importing entries'), findsWidgets);
    expect(delayedReader.callCount, 1);

    await tester.tap(find.byKey(const ValueKey('entryListImportButton')));
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
}

Future<void> _pumpEntryListApp(
  WidgetTester tester, {
  required _TestEntryRepository entryRepository,
  EntryExportService? exportService,
  EntryImportService? importService,
}) async {
  final sharedPreferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            backendUrl: 'https://wrait-backend.vercel.app',
            proxySecret: '',
            recordingHardCapMs: 120000,
          ),
        ),
        appRouterProvider.overrideWithValue(
          buildAppRouter(initialLocation: '/entries'),
        ),
        appLockEnabledProvider.overrideWithValue(false),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        preferencesRepositoryProvider.overrideWithValue(
          const _TestPreferencesRepository(),
        ),
        entryRepositoryProvider.overrideWithValue(entryRepository),
        if (exportService != null)
          entryExportServiceProvider.overrideWithValue(exportService),
        if (importService != null)
          entryImportServiceProvider.overrideWithValue(importService),
        mainRecordingControllerProvider.overrideWith(
          _TestMainRecordingController.new,
        ),
        sessionRecordQuotaStateProvider.overrideWith(_TestQuotaNotifier.new),
      ],
      child: const WraitApp(),
    ),
  );

  await tester.pumpAndSettle();
}

class _TestMainRecordingController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();

  @override
  Future<void> onMainButtonTapped() async {}
}

class _TestQuotaNotifier extends SessionRecordQuotaStateNotifier {
  @override
  RecordQuotaState? build() => null;
}

class _TestEntryRepository implements EntryRepository {
  final StreamController<List<Entry>> _controller =
      StreamController<List<Entry>>.broadcast();
  List<Entry> _entries = const <Entry>[];
  bool throwsOnDelete = false;

  void emitEntries(List<Entry> entries) {
    _entries = List<Entry>.from(entries);
    _controller.add(_entries);
  }

  Future<void> dispose() => _controller.close();

  @override
  Stream<List<Entry>> watchAllEntries() async* {
    yield _entries;
    yield* _controller.stream;
  }

  @override
  Stream<Entry?> watchEntryById(int id) async* {
    yield _findEntry(id);
    yield* _controller.stream.map((entries) {
      return _findEntry(id, entries: entries);
    });
  }

  @override
  Future<Entry?> getEntryById(int id) async => _findEntry(id);

  @override
  Future<List<int>> importEntries(List<Entry> entries) async {
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
  Future<void> deleteEntry(int id) async {
    if (throwsOnDelete) {
      throw StateError('delete failed');
    }

    _entries = _entries.where((entry) => entry.id != id).toList();
    _controller.add(_entries);
  }

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}

  Entry? _findEntry(int id, {List<Entry>? entries}) {
    final source = entries ?? _entries;
    for (final entry in source) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }
}

class _TestPreferencesRepository implements PreferencesRepository {
  const _TestPreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => true;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
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

Entry _audioDraftEntry({required int id}) {
  return Entry(
    id: id,
    rawTranscript: '',
    cleanedText: null,
    type: EntryType.draft,
    language: 'en-US',
    createdAt: DateTime(2026, 6, 15, 9).millisecondsSinceEpoch,
    wordCount: 0,
    audioPath: '/tmp/pending.m4a',
  );
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
