import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/data/display/display_awake_service.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/domain/repository/transcription_language_preferences_repository.dart';
import 'package:wrait/presentation/app_lock/app_lock_controller.dart';
import 'package:wrait/presentation/feedback/feedback_providers.dart';
import 'package:wrait/presentation/feedback/feedback_service.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/main_screen_test_keys.dart';
import 'package:wrait/presentation/main/recording_state.dart';
import 'package:wrait/presentation/settings/settings_test_keys.dart';
import 'package:wrait/presentation/theme/design_tokens.dart';

import '../../test_doubles/fake_display_awake_service.dart';

void main() {
  late _TestMainRecordingController controller;
  late _TestEntryRepository entryRepository;
  late _TestPreferencesRepository preferencesRepository;
  late _TestQuotaNotifier quotaNotifier;
  late FakeDisplayAwakeService displayAwakeService;
  late _TestAppLockController appLockController;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    controller = _TestMainRecordingController();
    entryRepository = _TestEntryRepository();
    preferencesRepository = _TestPreferencesRepository(hasEverRecorded: true);
    quotaNotifier = _TestQuotaNotifier();
    displayAwakeService = FakeDisplayAwakeService();
    appLockController = _TestAppLockController();
  });

  testWidgets(
    'renders the approved layout with reserved status and quota space',
    (tester) async {
      await _pumpTestApp(
        tester,
        controller: controller,
        entryRepository: entryRepository,
        preferencesRepository: preferencesRepository,
        quotaNotifier: quotaNotifier,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);
      expect(find.byKey(mainSettingsButtonKey), findsOneWidget);
      expect(find.byKey(mainFeedbackButtonKey), findsOneWidget);
      expect(find.byKey(mainTranscriptionLanguageKey), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('statusLineSlot'))).height,
        WraitStatusLineTokens.reservedHeight,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('quotaLineSlot'))).height,
        WraitQuotaLineTokens.reservedHeight,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('statsLineSlot'))).height,
        WraitStatsLineTokens.reservedHeight,
      );
    },
  );

  testWidgets('explicit transcription language opens its focused setting', (
    tester,
  ) async {
    preferencesRepository = _TestPreferencesRepository(
      hasEverRecorded: true,
      language: 'de-CH',
    );
    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
    );

    expect(find.byKey(mainTranscriptionLanguageKey), findsOneWidget);
    expect(find.text('Language: Deutsch (Schweiz)'), findsOneWidget);

    await tester.tap(find.byKey(mainTranscriptionLanguageKey));
    await tester.pumpAndSettle();

    expect(find.byKey(transcriptionLanguageDropdownKey), findsOneWidget);
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

  testWidgets('active recording keeps the language visible but disabled', (
    tester,
  ) async {
    preferencesRepository = _TestPreferencesRepository(
      hasEverRecorded: true,
      language: 'fr',
    );
    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
    );
    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      settle: false,
    );
    await tester.pump();

    expect(find.text('Language: Français'), findsOneWidget);
    expect(
      tester.widget<InkWell>(find.byKey(mainTranscriptionLanguageKey)).onTap,
      isNull,
    );
  });

  testWidgets('first-time status tap starts recording through the controller', (
    tester,
  ) async {
    preferencesRepository = _TestPreferencesRepository(hasEverRecorded: false);

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
    );

    await tester.tap(find.byKey(const ValueKey('statusLineButton')));
    await tester.pump();

    expect(controller.tapCount, 1);
  });

  testWidgets('saved status tap navigates to entry detail', (tester) async {
    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingSaved(entryId: 42, detectedLanguage: 'en-US'),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
    );

    await tester.tap(find.byKey(const ValueKey('statusLineButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(find.text('entry 42'), findsOneWidget);
  });

  testWidgets('stats tap navigates to entries', (tester) async {
    entryRepository.emitEntries([
      _entry(id: 1, createdAt: DateTime(2026, 6, 13, 9)),
      _entry(id: 2, createdAt: DateTime(2026, 6, 14, 9), type: EntryType.draft),
    ]);

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('statsLineButton')));
    await tester.tap(find.byKey(const ValueKey('statsLineButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
  });

  testWidgets('top-right feedback button launches the feedback service', (
    tester,
  ) async {
    final feedbackService = _FakeFeedbackService();
    final semanticsHandle = tester.ensureSemantics();

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      feedbackService: feedbackService,
    );

    final feedbackButton = find.byKey(mainFeedbackButtonKey);
    expect(feedbackButton, findsOneWidget);
    expect(tester.widget<IconButton>(feedbackButton).tooltip, 'Send feedback');
    final feedbackSemanticsFinder = find.bySemanticsLabel('Send feedback');
    expect(feedbackSemanticsFinder, findsOneWidget);
    final feedbackSemantics = tester.getSemantics(feedbackSemanticsFinder);
    expect(feedbackSemantics.label, 'Send feedback');
    expect(
      feedbackSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    await tester.tap(feedbackButton);
    await tester.pumpAndSettle();

    expect(feedbackService.appArea, 'main');
    semanticsHandle.dispose();
  });

  testWidgets('ignores rapid successive feedback button taps', (tester) async {
    final feedbackService = _BlockingFeedbackService();

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      feedbackService: feedbackService,
    );

    await tester.tap(find.byKey(mainFeedbackButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(mainFeedbackButtonKey));
    await tester.pump();

    expect(feedbackService.openCount, 1);

    feedbackService.complete(
      const FeedbackLaunchResult(FeedbackLaunchStatus.cancelled),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('shows a sanitized message when feedback is unavailable', (
    tester,
  ) async {
    final feedbackService = _FakeFeedbackService(
      status: FeedbackLaunchStatus.unavailable,
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      feedbackService: feedbackService,
    );

    await tester.tap(find.byKey(mainFeedbackButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('feedback is unavailable right now'), findsOneWidget);
    expect(find.textContaining('WIREDASH'), findsNothing);
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets('saved feedback auto-clears after the saved display window', (
    tester,
  ) async {
    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      feedbackDelays: const RecordingFeedbackDelays(
        savedDisplayWindow: Duration(milliseconds: 1),
      ),
    );

    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingSaved(entryId: 7, detectedLanguage: 'en-US'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5));

    expect(controller.clearSavedCount, 1);
    expect(find.text('wrait'), findsWidgets);
  });

  testWidgets('saved feedback timer resets for a newer saved state', (
    tester,
  ) async {
    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      feedbackDelays: const RecordingFeedbackDelays(
        savedDisplayWindow: Duration(milliseconds: 20),
      ),
    );

    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingSaved(entryId: 7, detectedLanguage: 'en-US'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingSaved(entryId: 8, detectedLanguage: 'en-US'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 15));

    expect(controller.clearSavedCount, 0);

    await tester.pump(const Duration(milliseconds: 10));
    expect(controller.clearSavedCount, 1);
  });

  testWidgets('quota is visible with valid quota and hidden without it', (
    tester,
  ) async {
    quotaNotifier.setQuota(
      RecordQuotaState(
        limit: 8,
        count: 3,
        remaining: 5,
        resetAt: DateTime.utc(2026, 6, 13),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
    );
    expect(find.text('8 total / 5 left'), findsOneWidget);

    quotaNotifier.clear();
    await tester.pump();
    expect(find.text('8 total / 5 left'), findsNothing);
  });

  testWidgets('quota remains visible while listening', (tester) async {
    quotaNotifier.setQuota(
      RecordQuotaState(
        limit: 10,
        count: 1,
        remaining: 9,
        resetAt: DateTime.utc(2026, 6, 13),
      ),
    );
    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      settle: false,
    );

    expect(find.text('10 total / 9 left'), findsOneWidget);
    expect(find.text('stop'), findsOneWidget);
  });

  testWidgets('hides countdown ring when recording hard cap is non-positive', (
    tester,
  ) async {
    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      appConfig: const AppConfig(
        backendUrl: 'https://wrait-backend.vercel.app',
        proxySecret: '',
        recordingHardCapMs: 0,
      ),
      settle: false,
    );

    expect(find.byKey(const ValueKey('countdownRing')), findsNothing);
    expect(find.text('stop'), findsOneWidget);
  });

  testWidgets(
    'falls back to first-time idle copy when preference loading fails',
    (tester) async {
      preferencesRepository = _TestPreferencesRepository(
        hasEverRecorded: true,
        throwsOnGetHasEverRecorded: true,
      );

      await _pumpTestApp(
        tester,
        controller: controller,
        entryRepository: entryRepository,
        preferencesRepository: preferencesRepository,
        quotaNotifier: quotaNotifier,
      );

      expect(find.text('tap button to write'), findsOneWidget);
      expect(find.byKey(const ValueKey('statusLineButton')), findsOneWidget);
    },
  );

  testWidgets('disposing while listening cancels countdown updates cleanly', (
    tester,
  ) async {
    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      settle: false,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows microphone-blocked status text', (tester) async {
    controller.setTestState(
      const RecordingControllerState(
        recordingState: RecordingErrorState(RecordingError.microphoneBlocked),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
    );

    expect(find.text('mic blocked · tap settings'), findsOneWidget);
    expect(find.byKey(const ValueKey('statusLineButton')), findsOneWidget);
  });

  testWidgets('blocked status tap routes to microphone settings action', (
    tester,
  ) async {
    controller.setTestState(
      const RecordingControllerState(
        recordingState: RecordingErrorState(RecordingError.microphoneBlocked),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
    );

    await tester.tap(find.byKey(const ValueKey('statusLineButton')));
    await tester.pump();

    expect(controller.openSettingsCount, 1);
  });

  testWidgets(
    'permission statuses expose specific semantics for assistive tech',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      controller.setTestState(
        const RecordingControllerState(
          recordingState: RecordingErrorState(RecordingError.microphoneDenied),
        ),
      );
      await _pumpTestApp(
        tester,
        controller: controller,
        entryRepository: entryRepository,
        preferencesRepository: preferencesRepository,
        quotaNotifier: quotaNotifier,
      );
      await tester.pumpAndSettle();

      final deniedNode = tester.getSemantics(
        find.byKey(const ValueKey('statusLineButton')),
      );
      expect(
        deniedNode.label,
        'Microphone access is required to start recording.',
      );
      expect(deniedNode.hint, 'Double tap to request microphone access again.');
      expect(
        deniedNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      controller.setTestState(
        const RecordingControllerState(
          recordingState: RecordingErrorState(RecordingError.microphoneBlocked),
        ),
      );
      await tester.pumpAndSettle();

      final blockedNode = tester.getSemantics(
        find.byKey(const ValueKey('statusLineButton')),
      );
      expect(blockedNode.label, 'Microphone access is blocked for Wrait.');
      expect(blockedNode.hint, 'Double tap to open app settings.');
      expect(
        blockedNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      semanticsHandle.dispose();
    },
  );

  testWidgets('app resume notifies the controller', (tester) async {
    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(controller.resumeCount, 1);
  });

  testWidgets('listening enables keep-awake and uploading releases it', (
    tester,
  ) async {
    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      displayAwakeService: displayAwakeService,
      settle: false,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    controller.setTestState(
      const RecordingControllerState(recordingState: RecordingUploading()),
    );
    await tester.pump();
    await tester.pump();

    expect(displayAwakeService.requests, <bool>[true, false]);
  });

  testWidgets('lifecycle exit releases keep-awake and resume reacquires it', (
    tester,
  ) async {
    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      displayAwakeService: displayAwakeService,
      settle: false,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(displayAwakeService.requests, <bool>[true, false, true]);
  });

  testWidgets(
    'startup while inactive does not enable keep-awake until resume',
    (tester) async {
      controller.setTestState(
        RecordingControllerState(
          recordingState: RecordingListening(
            hardCapDeadlineElapsedRealtime: 120000,
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

      await _pumpTestApp(
        tester,
        controller: controller,
        entryRepository: entryRepository,
        preferencesRepository: preferencesRepository,
        quotaNotifier: quotaNotifier,
        displayAwakeService: displayAwakeService,
        settle: false,
      );

      expect(displayAwakeService.requests, isEmpty);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(displayAwakeService.requests, <bool>[true]);
    },
  );

  testWidgets('disposing while listening releases keep-awake cleanly', (
    tester,
  ) async {
    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      displayAwakeService: displayAwakeService,
      settle: false,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();

    expect(displayAwakeService.requests, <bool>[true, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app lock release keep-awake while listening', (tester) async {
    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      displayAwakeService: displayAwakeService,
      appLockEnabled: true,
      appLockController: appLockController,
      settle: false,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    appLockController.lock();
    await tester.pump();
    await tester.pump();

    expect(displayAwakeService.requests, <bool>[true, false]);
  });

  testWidgets(
    'failed enable retries on later state changes without breaking UI',
    (tester) async {
      displayAwakeService.enqueueResult(false);

      await _pumpTestApp(
        tester,
        controller: controller,
        entryRepository: entryRepository,
        preferencesRepository: preferencesRepository,
        quotaNotifier: quotaNotifier,
        displayAwakeService: displayAwakeService,
        settle: false,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      controller.setTestState(
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

      controller.setTestState(
        const RecordingControllerState(recordingState: RecordingUploading()),
      );
      await tester.pump();
      await tester.pump();

      expect(displayAwakeService.requests, <bool>[true, true, false]);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required _TestMainRecordingController controller,
  required _TestEntryRepository entryRepository,
  required _TestPreferencesRepository preferencesRepository,
  required _TestQuotaNotifier quotaNotifier,
  FakeDisplayAwakeService? displayAwakeService,
  AppConfig appConfig = const AppConfig(
    backendUrl: 'https://wrait-backend.vercel.app',
    proxySecret: '',
    recordingHardCapMs: 120000,
  ),
  RecordingFeedbackDelays feedbackDelays = const RecordingFeedbackDelays(),
  bool appLockEnabled = false,
  _TestAppLockController? appLockController,
  FeedbackService? feedbackService,
  bool settle = true,
}) async {
  final router = buildAppRouter();
  final sharedPreferences = await SharedPreferences.getInstance();
  final resolvedDisplayAwakeService =
      displayAwakeService ?? FakeDisplayAwakeService();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(appConfig),
        appRouterProvider.overrideWithValue(router),
        appLockEnabledProvider.overrideWithValue(appLockEnabled),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        preferencesRepositoryProvider.overrideWithValue(preferencesRepository),
        entryRepositoryProvider.overrideWithValue(entryRepository),
        mainRecordingControllerProvider.overrideWith(() => controller),
        sessionRecordQuotaStateProvider.overrideWith(() => quotaNotifier),
        recordingFeedbackDelaysProvider.overrideWithValue(feedbackDelays),
        displayAwakeServiceProvider.overrideWithValue(
          resolvedDisplayAwakeService,
        ),
        if (feedbackService != null)
          feedbackServiceProvider.overrideWithValue(feedbackService),
        if (appLockController != null)
          appLockControllerProvider.overrideWith(() => appLockController),
      ],
      child: const WraitApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
    return;
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

class _FakeFeedbackService implements FeedbackService {
  _FakeFeedbackService({this.status = FeedbackLaunchStatus.cancelled});

  final FeedbackLaunchStatus status;
  String? appArea;

  @override
  Future<FeedbackLaunchResult> open(
    BuildContext context, {
    required String appArea,
  }) async {
    this.appArea = appArea;
    return FeedbackLaunchResult(status);
  }
}

class _BlockingFeedbackService implements FeedbackService {
  int openCount = 0;
  final _completion = Completer<FeedbackLaunchResult>();

  @override
  Future<FeedbackLaunchResult> open(
    BuildContext context, {
    required String appArea,
  }) {
    openCount += 1;
    return _completion.future;
  }

  void complete(FeedbackLaunchResult result) {
    _completion.complete(result);
  }
}

class _TestMainRecordingController extends MainRecordingController {
  RecordingControllerState _initialState = const RecordingControllerState();
  int tapCount = 0;
  int clearSavedCount = 0;
  int openSettingsCount = 0;
  int resumeCount = 0;

  @override
  RecordingControllerState build() => _initialState;

  @override
  Future<void> onMainButtonTapped() async {
    tapCount += 1;
  }

  @override
  void clearSaved() {
    clearSavedCount += 1;
    try {
      state = const RecordingControllerState();
    } catch (_) {
      _initialState = const RecordingControllerState();
    }
  }

  @override
  Future<void> onAppResumed() async {
    resumeCount += 1;
  }

  @override
  Future<void> openMicrophoneSettings() async {
    openSettingsCount += 1;
  }

  void setTestState(RecordingControllerState nextState) {
    _initialState = nextState;
    try {
      state = nextState;
    } catch (_) {}
  }
}

class _TestQuotaNotifier extends SessionRecordQuotaStateNotifier {
  _TestQuotaNotifier([RecordQuotaState? initialQuota])
    : _currentQuota = initialQuota;

  RecordQuotaState? _currentQuota;

  @override
  RecordQuotaState? build() => _currentQuota;

  @override
  void setQuota(RecordQuotaState quota) {
    _currentQuota = quota;
    try {
      state = quota;
    } catch (_) {}
  }

  void clear() {
    _currentQuota = null;
    try {
      state = null;
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

class _TestEntryRepository implements EntryRepository {
  final StreamController<List<Entry>> _controller =
      StreamController<List<Entry>>.broadcast();
  List<Entry> _entries = const <Entry>[];

  _TestEntryRepository() {
    _controller.add(_entries);
  }

  void emitEntries(List<Entry> entries) {
    _entries = List<Entry>.from(entries);
    _controller.add(_entries);
  }

  @override
  Stream<List<Entry>> watchAllEntries() async* {
    yield _entries;
    yield* _controller.stream;
  }

  @override
  Stream<Entry?> watchEntryById(int id) =>
      Stream<Entry?>.value(_entry(id: id, createdAt: DateTime(2026, 6, 16, 9)));

  @override
  Future<Entry?> getEntryById(int id) async =>
      _entry(id: id, createdAt: DateTime(2026, 6, 16, 9));

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

class _TestPreferencesRepository
    implements
        PreferencesRepository,
        TranscriptionLanguagePreferencesRepository {
  _TestPreferencesRepository({
    required this.hasEverRecorded,
    this.language,
    this.throwsOnGetHasEverRecorded = false,
  });

  final bool hasEverRecorded;
  String? language;
  final bool throwsOnGetHasEverRecorded;

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async {
    if (throwsOnGetHasEverRecorded) {
      throw StateError('preferences unavailable');
    }
    return hasEverRecorded;
  }

  @override
  Future<void> setHasEverRecorded(bool value) async {}

  @override
  Future<String?> getTranscriptionLanguage() async => language;

  @override
  Future<void> setTranscriptionLanguage(String? value) async {
    language = value;
  }
}

Entry _entry({
  required int id,
  required DateTime createdAt,
  EntryType type = EntryType.saved,
}) {
  return Entry(
    id: id,
    rawTranscript: 'entry $id',
    type: type,
    language: 'en-US',
    createdAt: createdAt.millisecondsSinceEpoch,
    wordCount: 2,
  );
}
