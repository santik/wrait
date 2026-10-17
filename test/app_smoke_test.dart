import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/main_screen_test_keys.dart';
import 'package:wrait/presentation/main/recording_state.dart';
import 'package:wrait/presentation/theme/design_tokens.dart';

void main() {
  testWidgets('renders the root main screen', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);
    expect(find.byKey(mainFeedbackButtonKey), findsOneWidget);
    expect(find.text('wrait'), findsWidgets);
  });

  testWidgets('preserves reserved status and quota space', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('statusLineSlot'))).height,
      WraitStatusLineTokens.reservedHeight,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('quotaLineSlot'))).height,
      WraitQuotaLineTokens.reservedHeight,
    );
  });
}

Widget _buildTestApp({String initialLocation = '/'}) {
  SharedPreferences.setMockInitialValues(const <String, Object>{});

  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          backendUrl: 'https://wrait-backend.vercel.app',
          proxySecret: '',
          recordingHardCapMs: 120000,
        ),
      ),
      appRouterProvider.overrideWithValue(
        buildAppRouter(initialLocation: initialLocation),
      ),
      appLockEnabledProvider.overrideWithValue(false),
      preferencesRepositoryProvider.overrideWithValue(
        const _SmokePreferencesRepository(),
      ),
      entryRepositoryProvider.overrideWithValue(const _SmokeEntryRepository()),
      mainRecordingControllerProvider.overrideWith(_SmokeController.new),
    ],
    child: const WraitApp(),
  );
}

class _SmokeController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();

  @override
  Future<void> onMainButtonTapped() async {}
}

class _SmokeEntryRepository implements EntryRepository {
  const _SmokeEntryRepository();

  @override
  Stream<List<Entry>> watchAllEntries() =>
      Stream<List<Entry>>.value(const <Entry>[]);

  @override
  Stream<Entry?> watchEntryById(int id) => const Stream<Entry?>.empty();

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
  Future<List<Entry>> getPendingDrafts() async => const <Entry>[];

  @override
  Future<void> deleteEntry(int id) async {}

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}
}

class _SmokePreferencesRepository implements PreferencesRepository {
  const _SmokePreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => true;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}
