import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/presentation/entries/entry_list_row.dart';
import 'package:wrait/presentation/theme/wrait_theme.dart';

import '../../test_doubles/l10n_test_helper.dart';

void main() {
  testWidgets('renders timestamp, preview, language, and draft marker', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        EntryListRow(
          entry: _entry(type: EntryType.draft),
          onTap: (_) {},
          onDeleteRequested: (_) async {},
        ),
      ),
    );

    expect(find.text('draft'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('clean line'), findsOneWidget);
  });

  testWidgets('row tap reports the selected entry id', (tester) async {
    var tappedId = 0;

    await tester.pumpWidget(
      _buildTestApp(
        EntryListRow(
          entry: _entry(),
          onTap: (entryId) => tappedId = entryId,
          onDeleteRequested: (_) async {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('entryCard-1')));
    await tester.pump();

    expect(tappedId, 1);
  });

  testWidgets('audio-only draft shows retry preview and does not navigate', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    var tapped = false;

    await tester.pumpWidget(
      _buildTestApp(
        EntryListRow(
          key: const ValueKey('entryRow-1'),
          entry: _audioDraftEntry(),
          onTap: (_) {
            tapped = true;
          },
          onDeleteRequested: (_) async {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('entryCard-1')));
    await tester.pump();

    expect(tapped, isFalse);
    expect(find.text(testL10n().entryListAudioDraftPreview), findsOneWidget);
    final semanticsData = tester
        .getSemantics(find.byKey(const ValueKey('entryRow-1')))
        .getSemanticsData();
    final customActions =
        semanticsData.customSemanticsActionIds
            ?.map(CustomSemanticsAction.getAction)
            .whereType<CustomSemanticsAction>()
            .toList() ??
        const <CustomSemanticsAction>[];

    expect(semanticsData.label, contains('English'));
    expect(semanticsData.hint, 'Swipe right to delete.');
    expect(semanticsData.value, 'draft, ${testL10n().entryListAudioDraftStateDescription}');
    expect(semanticsData.flagsCollection.isButton, isTrue);
    expect(semanticsData.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(
      customActions,
      contains(CustomSemanticsAction(label: testL10n().entryListDeleteActionLabel)),
    );

    semanticsHandle.dispose();
  });

  testWidgets('short swipe snaps back closed without opening delete flow', (
    tester,
  ) async {
    var revealCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        EntryListRow(
          entry: _entry(),
          onTap: (_) {},
          onDeleteRequested: (_) async {
            revealCount += 1;
          },
        ),
      ),
    );

    final cardFinder = find.byKey(const ValueKey('entryCard-1'));
    final initialLeft = tester.getTopLeft(cardFinder).dx;

    await tester.drag(cardFinder, const Offset(20, 0));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(cardFinder).dx, initialLeft);
    expect(revealCount, 0);
  });

  testWidgets('full swipe reveals delete area, triggers haptic, and resets', (
    tester,
  ) async {
    final deleteCompleter = Completer<void>();
    var revealCount = 0;
    var hapticCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        EntryListRow(
          entry: _entry(),
          onTap: (_) {},
          onDeleteRequested: (_) async {
            revealCount += 1;
            await deleteCompleter.future;
          },
          onRevealHaptic: () async {
            hapticCount += 1;
          },
        ),
      ),
    );

    final cardFinder = find.byKey(const ValueKey('entryCard-1'));
    final initialLeft = tester.getTopLeft(cardFinder).dx;

    await tester.drag(cardFinder, const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(revealCount, 1);
    expect(hapticCount, 1);
    expect(tester.getTopLeft(cardFinder).dx, initialLeft + 80);

    deleteCompleter.complete();
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(cardFinder).dx, initialLeft);
  });

  testWidgets('full swipe can open a confirmation dialog and cancel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(const _DeleteDialogHarness(deleteOnConfirm: false)),
    );

    final cardFinder = find.byKey(const ValueKey('entryCard-1'));
    final initialLeft = tester.getTopLeft(cardFinder).dx;

    await tester.drag(cardFinder, const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete entry?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entryDeleteCancelButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryCard-1')), findsOneWidget);
    expect(tester.getTopLeft(cardFinder).dx, initialLeft);
  });

  testWidgets('full swipe can confirm deletion through the dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(const _DeleteDialogHarness(deleteOnConfirm: true)),
    );

    await tester.drag(
      find.byKey(const ValueKey('entryCard-1')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entryDeleteConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryCard-1')), findsNothing);
  });

  testWidgets('custom delete semantics action opens the delete flow', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    var deleteCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        EntryListRow(
          key: const ValueKey('entryRow-1'),
          entry: _entry(),
          onTap: (_) {},
          onDeleteRequested: (_) async {
            deleteCount += 1;
          },
        ),
      ),
    );

    final semanticsLabel = tester
        .getSemantics(find.byKey(const ValueKey('entryRow-1')))
        .getSemanticsData()
        .label;

    tester.semantics.customAction(
      find.semantics.byLabel(semanticsLabel),
      CustomSemanticsAction(label: testL10n().entryListDeleteActionLabel),
    );
    await tester.pumpAndSettle();

    expect(deleteCount, 1);

    semanticsHandle.dispose();
  });

  testWidgets('repeated delete actions while active trigger only one flow', (
    tester,
  ) async {
    final deleteCompleter = Completer<void>();
    var deleteCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        EntryListRow(
          key: const ValueKey('entryRow-1'),
          entry: _entry(),
          onTap: (_) {},
          onDeleteRequested: (_) async {
            deleteCount += 1;
            await deleteCompleter.future;
          },
        ),
      ),
    );

    final cardFinder = find.byKey(const ValueKey('entryCard-1'));
    await tester.drag(cardFinder, const Offset(120, 0));
    await tester.pump();
    await tester.drag(cardFinder, const Offset(120, 0));
    await tester.pump();

    expect(deleteCount, 1);

    deleteCompleter.complete();
    await tester.pumpAndSettle();
  });
}

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en', 'US'),
    theme: wraitLightTheme,
    localizationsDelegates: testLocalizationsDelegates,
    supportedLocales: testSupportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

Entry _entry({EntryType type = EntryType.saved}) {
  return Entry(
    id: 1,
    rawTranscript: 'raw line\nraw second line',
    cleanedText: 'clean line\nclean second line',
    type: type,
    language: 'en-US',
    createdAt: DateTime(2026, 6, 15, 21, 5).millisecondsSinceEpoch,
    wordCount: 4,
  );
}

Entry _audioDraftEntry() {
  return Entry(
    id: 1,
    rawTranscript: '',
    cleanedText: null,
    type: EntryType.draft,
    language: 'en-US',
    createdAt: DateTime(2026, 6, 15, 21, 5).millisecondsSinceEpoch,
    wordCount: 0,
    audioPath: '/tmp/audio.m4a',
  );
}

class _DeleteDialogHarness extends StatefulWidget {
  const _DeleteDialogHarness({required this.deleteOnConfirm});

  final bool deleteOnConfirm;

  @override
  State<_DeleteDialogHarness> createState() => _DeleteDialogHarnessState();
}

class _DeleteDialogHarnessState extends State<_DeleteDialogHarness> {
  bool _deleted = false;

  @override
  Widget build(BuildContext context) {
    if (_deleted) {
      return const SizedBox.shrink();
    }

    return EntryListRow(
      entry: _entry(),
      onTap: (_) {},
      onDeleteRequested: (_) async {
        final shouldDelete = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete entry?'),
              content: const Text('This entry will be permanently removed.'),
              actions: [
                TextButton(
                  key: const ValueKey('entryDeleteCancelButton'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  key: const ValueKey('entryDeleteConfirmButton'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );

        if (shouldDelete == true && widget.deleteOnConfirm) {
          setState(() {
            _deleted = true;
          });
        }
      },
    );
  }
}
