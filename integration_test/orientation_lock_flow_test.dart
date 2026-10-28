import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/presentation/feedback/feedback_preparation_sheet.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/main_screen_test_keys.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import 'support/microphone_test_overrides.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('portrait presentation survives routes, resume, and dialogs', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    _expectPortrait(tester);
    expect(find.byKey(mainActionButtonKey), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('statsLineButton')));
    await tester.pumpAndSettle();

    _expectPortrait(tester);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryRow-1')), findsOneWidget);

    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    _expectPortrait(tester);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entryRow-1')));
    await tester.pumpAndSettle();

    _expectPortrait(tester);
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entryDetailDeleteButton')));
    await tester.pumpAndSettle();

    _expectPortrait(tester);
    expect(
      find.byKey(const ValueKey('entryDeleteCancelButton')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('entryDeleteCancelButton')));
    await tester.pumpAndSettle();

    _expectPortrait(tester);
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entryDetailBackButton')));
    await tester.pumpAndSettle();

    _expectPortrait(tester);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entryListBackButton')));
    await tester.pumpAndSettle();

    _expectPortrait(tester);
    expect(find.byKey(mainActionButtonKey), findsOneWidget);

    await tester.tap(find.byKey(mainFeedbackButtonKey));
    await tester.pumpAndSettle();

    _expectPortrait(tester);
    expect(find.byKey(feedbackPreparationPanelKey), findsOneWidget);

    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();

    _expectPortrait(tester);
    expect(find.byKey(mainActionButtonKey), findsOneWidget);
  });
}

void _expectPortrait(WidgetTester tester) {
  final size = tester.view.physicalSize;
  expect(
    size.height,
    greaterThanOrEqualTo(size.width),
    reason: 'Wrait should render in portrait orientation: $size.',
  );
}

Widget _buildTestApp() {
  SharedPreferences.setMockInitialValues(const <String, Object>{});

  return ProviderScope(
    overrides: [
      ...grantedMicrophoneOverrides,
      appConfigProvider.overrideWithValue(
        const AppConfig(
          backendUrl: 'https://wrait-backend.vercel.app',
          proxySecret: '',
          recordingHardCapMs: 120000,
        ),
      ),
      appRouterProvider.overrideWithValue(buildAppRouter()),
      appLockEnabledProvider.overrideWithValue(false),
      preferencesRepositoryProvider.overrideWithValue(
        const _OrientationPreferencesRepository(),
      ),
      entryRepositoryProvider.overrideWithValue(
        const _OrientationEntryRepository(),
      ),
      mainRecordingControllerProvider.overrideWith(
        _OrientationRecordingController.new,
      ),
    ],
    child: const WraitApp(),
  );
}

class _OrientationRecordingController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();

  @override
  Future<void> onMainButtonTapped() async {}
}

class _OrientationEntryRepository implements EntryRepository {
  const _OrientationEntryRepository();

  static const _sampleEntry = Entry(
    id: 1,
    rawTranscript: 'A sample orientation entry.',
    cleanedText: 'A sample orientation entry.',
    type: EntryType.saved,
    language: 'en-US',
    createdAt: 1704067200000,
    wordCount: 4,
  );

  @override
  Stream<List<Entry>> watchAllEntries() =>
      Stream<List<Entry>>.value(const <Entry>[_sampleEntry]);

  @override
  Stream<Entry?> watchEntryById(int id) =>
      Stream<Entry?>.value(id == _sampleEntry.id ? _sampleEntry : null);

  @override
  Future<Entry?> getEntryById(int id) async =>
      id == _sampleEntry.id ? _sampleEntry : null;

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

class _OrientationPreferencesRepository implements PreferencesRepository {
  const _OrientationPreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => true;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}
