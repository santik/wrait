import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/app.dart';
import 'package:wrait/presentation/settings/settings_test_keys.dart';

/// Shared helpers for driving the Settings "Backup & restore" actions from
/// integration tests (Import/Export moved to Settings in feature 058).

Future<void> openSettings(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.read(appRouterProvider).push('/settings');
  await tester.pumpAndSettle();
}

/// Scrolls the Backup action ([backupExportButtonKey] / [backupImportButtonKey])
/// fully into view — they are the last items in the Settings list, so a bare
/// `dragUntilVisible` can leave them clipped at the bottom edge and the tap
/// misses — then taps it.
///
/// First clears any outstanding snackbar: feedback is shown on the app-level
/// ScaffoldMessenger and survives navigation, so a previous action's snackbar
/// can otherwise sit over the bottom-of-list buttons and swallow the tap.
Future<void> tapBackup(WidgetTester tester, Key key) async {
  final messengerFinder = find.byType(ScaffoldMessenger);
  if (messengerFinder.evaluate().isNotEmpty) {
    tester.state<ScaffoldMessengerState>(messengerFinder.first).clearSnackBars();
    await tester.pumpAndSettle();
  }
  await tester.dragUntilVisible(
    find.byKey(key),
    find.byType(ListView),
    const Offset(0, -200),
  );
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> returnToEntries(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.read(appRouterProvider).pop();
  await tester.pumpAndSettle();
}
