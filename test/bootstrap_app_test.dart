import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/main.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

void main() {
  testWidgets('shows a visible loading screen before bootstrap completes', (
    tester,
  ) async {
    final runtimeCompleter = Completer<AppBootstrapRuntime>();

    await tester.pumpWidget(
      BootstrapApp(
        appConfig: _appConfig,
        bootstrapRuntime: (_) => runtimeCompleter.future,
      ),
    );

    expect(find.text('opening wrait'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(FlutterLogo), findsNothing);

    runtimeCompleter.complete(await _createRuntime());
    await tester.pumpAndSettle();
  });

  testWidgets('renders the real app after bootstrap succeeds', (tester) async {
    final runtime = await _createRuntime();

    await tester.pumpWidget(
      BootstrapApp(
        appConfig: _appConfig,
        bootstrapRuntime: (_) async => runtime,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);
    expect(find.text('wrait'), findsWidgets);
    expect(find.byType(FlutterLogo), findsNothing);
  });

  testWidgets('shows a retry screen when bootstrap fails', (tester) async {
    await tester.pumpWidget(
      BootstrapApp(
        appConfig: _appConfig,
        bootstrapRuntime: (_) =>
            Future<AppBootstrapRuntime>.error(StateError('boom')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('could not open wrait'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'retry'), findsOneWidget);
    expect(find.byType(FlutterLogo), findsNothing);
  });

  testWidgets('rapid retry taps do not start overlapping bootstrap runs', (
    tester,
  ) async {
    var callCount = 0;
    final retryCompleter = Completer<AppBootstrapRuntime>();

    await tester.pumpWidget(
      BootstrapApp(
        appConfig: _appConfig,
        bootstrapRuntime: (_) {
          callCount += 1;
          if (callCount == 1) {
            return Future<AppBootstrapRuntime>.error(StateError('boom'));
          }
          return retryCompleter.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    final retryButton = find.widgetWithText(FilledButton, 'retry');
    expect(retryButton, findsOneWidget);

    await tester.tap(retryButton);
    await tester.tap(retryButton);
    await tester.pump();

    expect(callCount, 2);

    retryCompleter.complete(await _createRuntime());
    await tester.pumpAndSettle();
  });
}

const _appConfig = AppConfig(
  backendUrl: 'https://wrait-backend.vercel.app',
  proxySecret: '',
  recordingHardCapMs: 120000,
);

Future<AppBootstrapRuntime> _createRuntime() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final sharedPreferences = await SharedPreferences.getInstance();
  final container = createAppContainer(
    appConfig: _appConfig,
    sharedPreferences: sharedPreferences,
    overrides: [
      preferencesRepositoryProvider.overrideWithValue(
        const _TestPreferencesRepository(),
      ),
      appLockEnabledProvider.overrideWithValue(false),
      entryRepositoryProvider.overrideWithValue(const _TestEntryRepository()),
      mainRecordingControllerProvider.overrideWith(_SmokeController.new),
    ],
  );

  return AppBootstrapRuntime(
    container: container,
    dispose: () async {
      container.dispose();
    },
  );
}

class _SmokeController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();

  @override
  Future<void> onMainButtonTapped() async {}
}

class _TestPreferencesRepository implements PreferencesRepository {
  const _TestPreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => false;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}

class _TestEntryRepository implements EntryRepository {
  const _TestEntryRepository();

  @override
  Future<void> deleteEntry(int id) async {}

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}

  @override
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<Entry?> getEntryById(int id) async => null;

  @override
  Future<List<int>> importEntries(List<Entry> entries) async => const [];

  @override
  Future<List<Entry>> getPendingDrafts() async => const <Entry>[];

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async => 1;

  @override
  Future<int> saveDraft(String transcript, String language) async => 1;

  @override
  Future<int> saveEntry(String transcript, String language) async => 1;

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {}

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
  Future<void> updateEntryLanguage(int id, String language) async {}

  @override
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Stream<List<Entry>> watchAllEntries() =>
      Stream<List<Entry>>.value(const <Entry>[]);

  @override
  Stream<Entry?> watchEntryById(int id) => const Stream<Entry?>.empty();
}
