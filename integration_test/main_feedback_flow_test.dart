import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/display/display_awake_service.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/presentation/feedback/feedback_providers.dart';
import 'package:wrait/presentation/feedback/feedback_model.dart';
import 'package:wrait/presentation/feedback/feedback_preparation_sheet.dart';
import 'package:wrait/presentation/feedback/feedback_service.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/main_screen_test_keys.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../test/test_doubles/fake_display_awake_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('submits feedback through the main-screen flow', (tester) async {
    final messageFlow = _FakeMessageFlow();
    final preferences = await _createPreferences();
    final feedbackService = WiredashFeedbackService(
      isConfigured: true,
      launchFlow: messageFlow.open,
    );

    await tester.pumpWidget(_buildApp(feedbackService, preferences));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(mainFeedbackButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('send feedback'), findsOneWidget);
    expect(find.byKey(feedbackPrivacyCopyKey), findsOneWidget);

    await tester.tap(find.text('Idea'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(feedbackContactFieldKey));
    await tester.tap(find.byKey(feedbackContactFieldKey));
    await tester.pumpAndSettle();
    _expectFeedbackFieldFocused(tester, find.byKey(feedbackContactFieldKey));
    await _enterFeedbackText(
      tester,
      find.byKey(feedbackContactFieldKey),
      'Signal: wrait-test',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(feedbackContactFieldKey))
          .controller!
          .text,
      'Signal: wrait-test',
    );
    await tester.ensureVisible(find.byKey(feedbackMessageFieldKey));
    await tester.tap(find.byKey(feedbackMessageFieldKey));
    await tester.pumpAndSettle();
    _expectFeedbackFieldFocused(tester, find.byKey(feedbackMessageFieldKey));
    await _enterFeedbackText(
      tester,
      find.byKey(feedbackMessageFieldKey),
      'The recording flow is clear.',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(feedbackSubmitButtonKey));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
    }
    final screenshot = await binding.takeScreenshot(
      'feedback_form_${defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios'}',
    );
    expect(screenshot, isNotEmpty);
    await tester.tap(find.byKey(feedbackSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(messageFlow.lastDraft?.category.name, 'idea');
    expect(messageFlow.lastDraft?.replyContact, 'Signal: wrait-test');
    expect(messageFlow.lastDraft?.message, 'The recording flow is clear.');
    expect(find.text('feedback sent'), findsOneWidget);
    expect(find.byKey(mainFeedbackButtonKey), findsOneWidget);
  });

  testWidgets('cancels and retries with failed draft preserved', (
    tester,
  ) async {
    final messageFlow = _FakeMessageFlow()..failNext = true;
    final preferences = await _createPreferences();
    final feedbackService = WiredashFeedbackService(
      isConfigured: true,
      launchFlow: messageFlow.open,
    );

    await tester.pumpWidget(_buildApp(feedbackService, preferences));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(mainFeedbackButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Praise'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(feedbackContactFieldKey));
    await tester.tap(find.byKey(feedbackContactFieldKey));
    await tester.pumpAndSettle();
    _expectFeedbackFieldFocused(tester, find.byKey(feedbackContactFieldKey));
    await _enterFeedbackText(
      tester,
      find.byKey(feedbackContactFieldKey),
      'not-an-email',
    );
    await tester.pump();
    if (tester.testTextInput.isRegistered) {
      tester.testTextInput.hide();
    }
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('cancel'));
    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();
    expect(find.text('send feedback'), findsNothing);
    expect(messageFlow.openCount, 0);

    await tester.tap(find.byKey(mainFeedbackButtonKey));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Praise'))
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(feedbackContactFieldKey))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(feedbackSubmitButtonKey))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Praise'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(feedbackContactFieldKey));
    await tester.tap(find.byKey(feedbackContactFieldKey));
    await tester.pumpAndSettle();
    await _enterFeedbackText(
      tester,
      find.byKey(feedbackContactFieldKey),
      'not-an-email',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(feedbackContactFieldKey))
          .controller!
          .text,
      'not-an-email',
    );
    await tester.ensureVisible(find.byKey(feedbackMessageFieldKey));
    await tester.tap(find.byKey(feedbackMessageFieldKey));
    await tester.pumpAndSettle();
    _expectFeedbackFieldFocused(tester, find.byKey(feedbackMessageFieldKey));
    await _enterFeedbackText(
      tester,
      find.byKey(feedbackMessageFieldKey),
      'First attempt.',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(feedbackContactFieldKey))
          .controller!
          .text,
      'not-an-email',
    );
    await tester.ensureVisible(find.byKey(feedbackSubmitButtonKey));
    await tester.tap(find.byKey(feedbackSubmitButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('feedback could not be sent. try again'), findsOneWidget);
    expect(messageFlow.lastDraft?.replyContact, 'not-an-email');
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(mainFeedbackButtonKey));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(feedbackContactFieldKey))
          .controller!
          .text,
      'not-an-email',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(feedbackMessageFieldKey))
          .controller!
          .text,
      'First attempt.',
    );
    await tester.ensureVisible(find.byKey(feedbackMessageFieldKey));
    await tester.tap(find.byKey(feedbackMessageFieldKey));
    await tester.pumpAndSettle();
    _expectFeedbackFieldFocused(tester, find.byKey(feedbackMessageFieldKey));
    await _enterFeedbackText(
      tester,
      find.byKey(feedbackMessageFieldKey),
      'Retry attempt.',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(feedbackSubmitButtonKey));
    await tester.tap(find.byKey(feedbackSubmitButtonKey));
    await tester.pumpAndSettle();

    expect(messageFlow.openCount, 2);
    expect(find.text('feedback sent'), findsOneWidget);
  });
}

void _expectFeedbackFieldFocused(WidgetTester tester, Finder finder) {
  expect(tester.widget<TextField>(finder).focusNode?.hasFocus, isTrue);
}

Future<void> _enterFeedbackText(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.enterText(finder, text);
  await tester.pump();
  if (tester.widget<TextField>(finder).controller!.text == text) {
    return;
  }

  // The real IME connection can replace the first test-input update on a
  // device. The field is already focused, so retry through that connection.
  await tester.tap(finder);
  await tester.pump();
  tester.testTextInput.enterText(text);
  await tester.pump();
}

Widget _buildApp(
  FeedbackService feedbackService,
  SharedPreferences preferences,
) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          backendUrl: 'https://wrait-backend.vercel.app',
          proxySecret: '',
          recordingHardCapMs: 120000,
        ),
      ),
      appRouterProvider.overrideWithValue(buildAppRouter()),
      appLockEnabledProvider.overrideWithValue(false),
      sharedPreferencesProvider.overrideWithValue(preferences),
      preferencesRepositoryProvider.overrideWithValue(
        const _TestPreferencesRepository(),
      ),
      entryRepositoryProvider.overrideWithValue(const _TestEntryRepository()),
      mainRecordingControllerProvider.overrideWith(_SmokeController.new),
      displayAwakeServiceProvider.overrideWithValue(FakeDisplayAwakeService()),
      feedbackServiceProvider.overrideWithValue(feedbackService),
    ],
    child: const WraitApp(),
  );
}

Future<SharedPreferences> _createPreferences() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SharedPreferences.getInstance();
}

class _FakeMessageFlow {
  bool failNext = false;
  int openCount = 0;
  FeedbackDraft? lastDraft;

  Future<bool> open({
    required BuildContext context,
    required FeedbackDraft draft,
    required String appArea,
  }) async {
    openCount += 1;
    lastDraft = draft;
    if (failNext) {
      failNext = false;
      throw StateError('network failure');
    }
    return true;
  }
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
  Future<String> getDeviceId() async => 'integration-device';

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
