import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/core/time/system_clock.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/audio/audio_recording_providers.dart';
import 'package:wrait/data/audio/microphone_permission_service.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/transcription/transcription_providers.dart';
import 'package:wrait/data/transcription/transcription_service.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/pulse_ring.dart';
import 'package:wrait/presentation/main/main_screen_test_keys.dart';
import 'package:wrait/presentation/main/recording_state.dart';
import 'package:wrait/presentation/theme/design_tokens.dart';

import '../test/test_doubles/fake_monotonic_clock.dart';
import '../test/test_doubles/fake_secure_storage.dart';

import 'support/microphone_test_overrides.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets(
    'first-time status tap starts listening and successful save auto-clears',
    (tester) async {
      final harness = await _createHarness(
        feedbackDelays: const RecordingFeedbackDelays(
          savedDisplayWindow: Duration(seconds: 5),
        ),
      );
      addTearDown(harness.dispose);

      harness.transcriptionService.nextStopResult = const TranscriptionSuccess(
        transcript: 'raw transcript',
        detectedLanguage: 'fr-FR',
      );
      harness.cleanupCallbackHolder.callback =
          ({required transcript, required language}) async =>
              const backend.CleanupSuccess(cleanedText: 'Cleaned transcript.');

      final savedState = Completer<void>();
      final savedStateSubscription = harness.container
          .listen<RecordingControllerState>(mainRecordingControllerProvider, (
            previous,
            next,
          ) {
            if (next.recordingState is RecordingSaved &&
                !savedState.isCompleted) {
              savedState.complete();
            }
          });
      addTearDown(savedStateSubscription.close);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('tap button to write'), findsOneWidget);

      await tester.tap(_statusLineButtonFinder());
      await _pumpUntilFound(
        tester,
        find.text('listening...'),
        timeout: const Duration(seconds: 5),
      );
      expect(find.text('listening...'), findsOneWidget);

      harness.monotonicClock.advance(const Duration(seconds: 6));
      await tester.tap(find.byKey(mainActionButtonKey));
      await savedState.future.timeout(const Duration(seconds: 5));
      await _pumpUntilFound(
        tester,
        find.text('saved, tap to read'),
        timeout: const Duration(seconds: 5),
      );
      expect(find.text('saved, tap to read'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(find.text('wrait'), findsWidgets);
    },
  );

  testWidgets('saved status tap navigates to the saved detail route', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    harness.transcriptionService.nextStopResult = const TranscriptionSuccess(
      transcript: 'raw transcript',
      detectedLanguage: 'en-US',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_statusLineButtonFinder());
    await _pumpUntilFound(
      tester,
      find.text('listening...'),
      timeout: const Duration(seconds: 5),
    );
    harness.monotonicClock.advance(const Duration(seconds: 6));
    await tester.tap(find.byKey(mainActionButtonKey));
    await _pumpUntilFound(
      tester,
      find.text('saved, tap to read'),
      timeout: const Duration(seconds: 5),
    );

    await tester.tap(_statusLineButtonFinder());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(find.text('Cleaned transcript.'), findsOneWidget);
  });

  testWidgets(
    'stats show drafts and finalized entries and navigate to entries',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      final repository = harness.container.read(entryRepositoryProvider);
      await repository.saveEntry('final entry', 'en-US');
      harness.entryClock.advance(const Duration(days: 1));
      await repository.saveDraft('draft entry', 'en-US');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 entries - 2 days'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('statsLineButton')));
      await tester.tap(find.byKey(const ValueKey('statsLineButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    },
  );

  testWidgets('quota stays visible while idle and listening', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    harness.container
        .read(sessionRecordQuotaStateProvider.notifier)
        .setQuota(
          RecordQuotaState(
            limit: 9,
            count: 3,
            remaining: 6,
            resetAt: DateTime.utc(2026, 6, 13),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('9 total / 6 left'), findsOneWidget);

    await tester.tap(_statusLineButtonFinder());
    await _pumpUntilFound(
      tester,
      find.text('listening...'),
      timeout: const Duration(seconds: 5),
    );
    expect(find.text('listening...'), findsOneWidget);
    expect(find.text('9 total / 6 left'), findsOneWidget);
  });

  testWidgets(
    'listening pulse grows beyond the viewport while controls stay visible',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      harness.container
          .read(sessionRecordQuotaStateProvider.notifier)
          .setQuota(
            RecordQuotaState(
              limit: 9,
              count: 3,
              remaining: 6,
              resetAt: DateTime.utc(2026, 6, 13),
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_statusLineButtonFinder());
      await _pumpUntilFound(
        tester,
        find.text('listening...'),
        timeout: const Duration(seconds: 5),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('pulseRing')),
        timeout: const Duration(seconds: 5),
      );

      final pulseRing = tester.widget<PulseRing>(
        find.byKey(const ValueKey('pulseRing')),
      );
      final scaffoldRect = tester.getRect(find.byType(Scaffold));
      final scaffoldSize = scaffoldRect.size;
      final buttonCenter = tester.getCenter(find.byKey(mainActionButtonKey));
      final furthestCornerDistance = max(
        max(
          (buttonCenter - scaffoldRect.topLeft).distance,
          (buttonCenter - scaffoldRect.topRight).distance,
        ),
        max(
          (buttonCenter - scaffoldRect.bottomLeft).distance,
          (buttonCenter - scaffoldRect.bottomRight).distance,
        ),
      );

      expect(pulseRing.endDiameter, greaterThan(scaffoldSize.width));
      expect(pulseRing.endDiameter, greaterThan(scaffoldSize.height));
      expect(
        pulseRing.endDiameter,
        greaterThan(
          (furthestCornerDistance * 2) +
              WraitButtonTokens.pulseViewportOverscan,
        ),
      );
      expect(find.byKey(mainActionButtonKey), findsOneWidget);
      expect(find.text('9 total / 6 left'), findsOneWidget);
      expect(find.byKey(mainStatusLineSlotKey), findsOneWidget);
    },
  );

  testWidgets(
    'listening pulse still reaches the furthest corner in a landscape viewport',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 720);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final harness = await _createHarness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_statusLineButtonFinder());
      await _pumpUntilFound(
        tester,
        find.text('listening...'),
        timeout: const Duration(seconds: 5),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('pulseRing')),
        timeout: const Duration(seconds: 5),
      );

      final pulseRing = tester.widget<PulseRing>(
        find.byKey(const ValueKey('pulseRing')),
      );
      final scaffoldRect = tester.getRect(find.byType(Scaffold));
      final buttonCenter = tester.getCenter(find.byKey(mainActionButtonKey));
      final furthestCornerDistance = max(
        max(
          (buttonCenter - scaffoldRect.topLeft).distance,
          (buttonCenter - scaffoldRect.topRight).distance,
        ),
        max(
          (buttonCenter - scaffoldRect.bottomLeft).distance,
          (buttonCenter - scaffoldRect.bottomRight).distance,
        ),
      );

      expect(pulseRing.endDiameter, greaterThan(scaffoldRect.width));
      expect(pulseRing.endDiameter, greaterThan(scaffoldRect.height));
      expect(
        pulseRing.endDiameter,
        greaterThan(
          (furthestCornerDistance * 2) +
              WraitButtonTokens.pulseViewportOverscan,
        ),
      );
    },
  );

  testWidgets('microphone-blocked start failure shows mic blocked status', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);
    harness.transcriptionService.startFailure =
        const MicBlockedTranscriptionServiceFailure(
          MicrophoneAccessState.permanentlyDenied,
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_statusLineButtonFinder());
    await tester.pumpAndSettle();

    expect(find.text('mic blocked · tap settings'), findsOneWidget);
  });

  testWidgets(
    'draft-preserved network feedback is shown and auto-clears back to idle',
    (tester) async {
      final harness = await _createHarness(
        feedbackDelays: const RecordingFeedbackDelays(
          errorAndDeletedAutoClear: Duration(milliseconds: 50),
        ),
      );
      addTearDown(harness.dispose);
      final appTempDirectory = await getTemporaryDirectory();
      final audioDraftFile = File(
        '${appTempDirectory.path}/main-screen-retry-audio.m4a',
      );
      addTearDown(() async {
        if (await audioDraftFile.exists()) {
          await audioDraftFile.delete();
        }
      });
      await audioDraftFile.writeAsBytes(const <int>[1, 2, 3]);
      harness.transcriptionService.nextStopResult = TranscriptionFailure(
        reason: TranscriptionFailureReason.network,
        audioDraftPath: audioDraftFile.path,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_statusLineButtonFinder());
      await _pumpUntilFound(
        tester,
        find.text('listening...'),
        timeout: const Duration(seconds: 5),
      );
      harness.monotonicClock.advance(const Duration(seconds: 6));
      await tester.tap(find.byKey(mainActionButtonKey));
      await _pumpUntilFound(
        tester,
        find.text('no connection · saved as draft'),
        timeout: const Duration(milliseconds: 120),
      );

      expect(find.text('no connection · saved as draft'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
      expect(find.text('wrait'), findsWidgets);
    },
  );

  testWidgets(
    'microphone-blocked feedback auto-clears and can be shown again by tapping',
    (tester) async {
      final harness = await _createHarness(
        feedbackDelays: const RecordingFeedbackDelays(
          errorAndDeletedAutoClear: Duration(milliseconds: 50),
        ),
      );
      addTearDown(harness.dispose);
      harness.transcriptionService.startFailure =
          const MicBlockedTranscriptionServiceFailure(
            MicrophoneAccessState.permanentlyDenied,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_statusLineButtonFinder());
      await _pumpUntilFound(
        tester,
        find.text('mic blocked · tap settings'),
        timeout: const Duration(milliseconds: 40),
      );

      expect(find.text('mic blocked · tap settings'), findsOneWidget);

      await _pumpUntilGone(tester, find.text('mic blocked · tap settings'));
      expect(find.text('mic blocked · tap settings'), findsNothing);
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(_statusLineButtonFinder());
      await _pumpUntilFound(
        tester,
        find.text('mic blocked · tap settings'),
        timeout: const Duration(milliseconds: 40),
      );
      expect(find.text('mic blocked · tap settings'), findsOneWidget);
    },
  );
}

Finder _statusLineButtonFinder() =>
    find.byKey(const ValueKey('statusLineButton')).last;

class _CleanupCallbackHolder {
  Future<backend.CleanupResult> Function({
    required String transcript,
    required String language,
  })
  callback = ({required String transcript, required String language}) async =>
      const backend.CleanupSuccess(cleanedText: 'Cleaned transcript.');
}

class _Harness {
  _Harness({
    required this.container,
    required this.database,
    required this.tempDirectory,
    required this.monotonicClock,
    required this.entryClock,
    required this.transcriptionService,
    required this.sharedPreferences,
    required this.cleanupCallbackHolder,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory tempDirectory;
  final FakeMonotonicClock monotonicClock;
  final _MutableClock entryClock;
  final _FakeTranscriptionService transcriptionService;
  final SharedPreferences sharedPreferences;
  final _CleanupCallbackHolder cleanupCallbackHolder;

  Future<void> dispose() async {
    container.dispose();
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 5),
  Duration timeout = const Duration(milliseconds: 100),
}) async {
  final iterations = timeout.inMicroseconds ~/ step.inMicroseconds;
  for (var index = 0; index < iterations; index += 1) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  throw TestFailure('Did not find $finder within $timeout.');
}

Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 5),
  Duration timeout = const Duration(milliseconds: 500),
}) async {
  final iterations = timeout.inMicroseconds ~/ step.inMicroseconds;
  for (var index = 0; index < iterations; index += 1) {
    await tester.pump(step);
    if (finder.evaluate().isEmpty) {
      return;
    }
  }
}

Future<_Harness> _createHarness({
  RecordingFeedbackDelays feedbackDelays = const RecordingFeedbackDelays(
    errorAndDeletedAutoClear: Duration(minutes: 1),
  ),
}) async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'wrait-main-screen-int',
  );
  final database = await LocalEntryDatabase.open(
    keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(7)),
    databaseFile: File(
      '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
    ),
  );
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final sharedPreferences = await SharedPreferences.getInstance();
  final monotonicClock = FakeMonotonicClock(0);
  final entryClock = _MutableClock(DateTime(2026, 6, 13, 9));
  final transcriptionService = _FakeTranscriptionService();
  final cleanupCallbackHolder = _CleanupCallbackHolder();

  final container = ProviderContainer(
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
      localEntryDatabaseProvider.overrideWithValue(database),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      monotonicClockProvider.overrideWithValue(monotonicClock),
      clockProvider.overrideWithValue(entryClock),
      transcriptionServiceProvider.overrideWithValue(transcriptionService),
      cleanupTranscriptCallbackProvider.overrideWithValue(({
        required transcript,
        required language,
      }) {
        return cleanupCallbackHolder.callback(
          transcript: transcript,
          language: language,
        );
      }),
      recordingFeedbackDelaysProvider.overrideWithValue(feedbackDelays),
    ],
  );

  return _Harness(
    container: container,
    database: database,
    tempDirectory: tempDirectory,
    monotonicClock: monotonicClock,
    entryClock: entryClock,
    transcriptionService: transcriptionService,
    sharedPreferences: sharedPreferences,
    cleanupCallbackHolder: cleanupCallbackHolder,
  );
}

class _FakeTranscriptionService implements TranscriptionService {
  @override
  int? hardCapDeadlineElapsedRealtime = 120000;

  @override
  bool isRecording = false;

  @override
  bool isTranscribing = false;

  TranscriptionServiceFailure? startFailure;
  TranscriptionResult nextStopResult = const TranscriptionSuccess(
    transcript: 'raw transcript',
    detectedLanguage: 'en-US',
  );

  @override
  Future<void> startLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    if (startFailure case final failure?) {
      throw failure;
    }

    isRecording = true;
    onStatus(RecordingStarted(hardCapDeadlineElapsedRealtime!));
  }

  @override
  Future<TranscriptionResult> stopLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    isRecording = false;
    if (nextStopResult case TranscriptionFailure(reason: final reason)
        when reason == TranscriptionFailureReason.tooShort) {
      return nextStopResult;
    }

    isTranscribing = true;
    onStatus(const Uploading());
    isTranscribing = false;
    return nextStopResult;
  }

  @override
  Future<void> cancelLiveTranscription() async {
    isRecording = false;
    isTranscribing = false;
    hardCapDeadlineElapsedRealtime = null;
  }

  @override
  Future<TranscriptionResult> transcribeAudioDraft(String audioPath) async {
    return nextStopResult;
  }
}

class _MutableClock implements Clock {
  _MutableClock(this.current);

  DateTime current;

  @override
  int now() => current.millisecondsSinceEpoch;

  void advance(Duration duration) {
    current = current.add(duration);
  }
}
