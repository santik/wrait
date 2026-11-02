import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/data/display/display_awake_service.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/presentation/app_lock/app_lock_controller.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../test/test_doubles/fake_display_awake_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('listening enables keep-awake and upload plus saved release it', (
    tester,
  ) async {
    final harness = await _createHarness();

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    harness.recordingController.setState(
      RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    harness.recordingController.setState(
      const RecordingControllerState(recordingState: RecordingUploading()),
    );
    await tester.pump();
    await tester.pump();

    harness.recordingController.setState(
      RecordingControllerState(
        recordingState: RecordingSaved(entryId: 7, detectedLanguage: 'en-US'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(harness.displayAwakeService.requests, <bool>[true, false]);
  });

  testWidgets('error flow releases keep-awake after listening', (tester) async {
    final harness = await _createHarness();

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    harness.recordingController.setState(
      RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    harness.recordingController.setState(
      const RecordingControllerState(
        recordingState: RecordingErrorState(RecordingError.apiFailed),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(harness.displayAwakeService.requests, <bool>[true, false]);
  });

  testWidgets(
    'failed keep-awake enable retries on later state changes without interrupting recording',
    (tester) async {
      final harness = await _createHarness();
      harness.displayAwakeService.enqueueResult(false);

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      harness.recordingController.setState(
        RecordingControllerState(
          recordingState: RecordingListening(
            hardCapDeadlineElapsedRealtime: 120000,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('stop'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      harness.recordingController.setState(
        const RecordingControllerState(recordingState: RecordingUploading()),
      );
      await tester.pump();
      await tester.pump();

      expect(harness.displayAwakeService.requests, <bool>[true, true, false]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('background and app lock release keep-awake while listening', (
    tester,
  ) async {
    final harness = await _createHarness(appLockEnabled: true);

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    harness.recordingController.setState(
      RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    harness.appLockController.lock();
    await tester.pump();
    await tester.pump();

    expect(harness.displayAwakeService.requests, <bool>[
      true,
      false,
      true,
      false,
    ]);
  });
}

class _Harness {
  _Harness({
    required this.app,
    required this.recordingController,
    required this.appLockController,
    required this.displayAwakeService,
  });

  final Widget app;
  final _TestMainRecordingController recordingController;
  final _TestAppLockController appLockController;
  final FakeDisplayAwakeService displayAwakeService;
}

Future<_Harness> _createHarness({bool appLockEnabled = false}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final sharedPreferences = await SharedPreferences.getInstance();
  final recordingController = _TestMainRecordingController();
  final appLockController = _TestAppLockController();
  final displayAwakeService = FakeDisplayAwakeService();

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
      appLockEnabledProvider.overrideWithValue(appLockEnabled),
      appLockControllerProvider.overrideWith(() => appLockController),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      preferencesRepositoryProvider.overrideWithValue(
        _TestPreferencesRepository(),
      ),
      entryRepositoryProvider.overrideWithValue(_TestEntryRepository()),
      mainRecordingControllerProvider.overrideWith(() => recordingController),
      displayAwakeServiceProvider.overrideWithValue(displayAwakeService),
    ],
    child: const WraitApp(),
  );

  return _Harness(
    app: app,
    recordingController: recordingController,
    appLockController: appLockController,
    displayAwakeService: displayAwakeService,
  );
}

class _TestMainRecordingController extends MainRecordingController {
  RecordingControllerState _currentState = const RecordingControllerState();

  @override
  RecordingControllerState build() => _currentState;

  @override
  Future<void> onMainButtonTapped() async {}

  @override
  Future<void> onAppResumed() async {}

  void setState(RecordingControllerState nextState) {
    _currentState = nextState;
    try {
      state = nextState;
    } catch (_) {}
  }
}

class _TestAppLockController extends AppLockController {
  AppLockState _currentState = const AppLockState.unlocked();

  @override
  AppLockState build() => _currentState;

  void lock() {
    _currentState = const AppLockState.locked();
    try {
      state = _currentState;
    } catch (_) {}
  }
}

class _TestPreferencesRepository implements PreferencesRepository {
  @override
  Future<bool> getHasEverRecorded() async => true;

  @override
  Future<void> setHasEverRecorded(bool value) async {}

  @override
  Future<String> getDeviceId() async => 'device-id';
}

class _TestEntryRepository implements EntryRepository {
  @override
  Stream<List<Entry>> watchAllEntries() => Stream<List<Entry>>.value(const []);

  @override
  Stream<Entry?> watchEntryById(int id) => Stream<Entry?>.value(null);

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
  Future<List<Entry>> getPendingDrafts() async => const [];

  @override
  Future<void> deleteEntry(int id) async {}

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}
}
