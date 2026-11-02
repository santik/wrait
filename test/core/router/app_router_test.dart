import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:wrait/presentation/main/recording_state.dart';
import 'package:wrait/presentation/settings/settings_test_keys.dart';

void main() {
  testWidgets('renders the entries route directly', (tester) async {
    await tester.pumpWidget(_buildTestApp(initialLocation: '/entries'));

    await tester.pumpAndSettle();

    expect(find.text('no entries yet'), findsOneWidget);
  });

  testWidgets('renders Settings directly and returns to main', (tester) async {
    final router = buildAppRouter(initialLocation: '/settings');
    await tester.pumpWidget(_buildTestApp(router: router));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('App lock'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settingsBackButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);
  });

  testWidgets('focused Settings route focuses the language dropdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        initialLocation: '/settings?section=transcription-language',
      ),
    );
    await tester.pumpAndSettle();

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
  });

  testWidgets('renders the entry-detail route for a non-empty id', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(initialLocation: '/entry/1'));

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(find.text('router entry'), findsOneWidget);
  });

  testWidgets('redirects an empty entry id route back to entries', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(initialLocation: '/entry/%20%20'));

    await tester.pumpAndSettle();

    expect(find.text('no entries yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsNothing);
  });

  testWidgets('redirects a non-positive entry id route back to entries', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(initialLocation: '/entry/0'));

    await tester.pumpAndSettle();

    expect(find.text('no entries yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsNothing);
  });

  testWidgets('supports the approved route user flow', (tester) async {
    final router = buildAppRouter();

    await tester.pumpWidget(_buildTestApp(router: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);

    router.go('/entries');
    await tester.pumpAndSettle();
    expect(find.text('no entries yet'), findsOneWidget);

    router.go('/entry/1');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(find.text('router entry'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);
  });
}

Widget _buildTestApp({String initialLocation = '/', GoRouter? router}) {
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
        router ?? buildAppRouter(initialLocation: initialLocation),
      ),
      appLockEnabledProvider.overrideWithValue(false),
      preferencesRepositoryProvider.overrideWithValue(
        const _RouterPreferencesRepository(),
      ),
      entryRepositoryProvider.overrideWithValue(const _RouterEntryRepository()),
      mainRecordingControllerProvider.overrideWith(_RouterController.new),
    ],
    child: const Directionality(
      textDirection: TextDirection.ltr,
      child: WraitApp(),
    ),
  );
}

class _RouterController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();

  @override
  Future<void> onMainButtonTapped() async {}
}

class _RouterEntryRepository implements EntryRepository {
  const _RouterEntryRepository();

  @override
  Stream<List<Entry>> watchAllEntries() =>
      Stream<List<Entry>>.value(const <Entry>[]);

  @override
  Stream<Entry?> watchEntryById(int id) =>
      Stream<Entry?>.value(id == 1 ? _routerEntry(id) : null);

  @override
  Future<Entry?> getEntryById(int id) async =>
      id == 1 ? _routerEntry(id) : null;

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

Entry _routerEntry(int id) {
  return Entry(
    id: id,
    rawTranscript: 'router entry',
    cleanedText: null,
    type: EntryType.saved,
    language: 'en-US',
    createdAt: DateTime(2026, 6, 16, 9).millisecondsSinceEpoch,
    wordCount: 2,
  );
}

class _RouterPreferencesRepository implements PreferencesRepository {
  const _RouterPreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => true;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}
