import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/preferences/preferences_repository_impl.dart';
import 'package:wrait/data/reminders/notification_scheduler.dart';
import 'package:wrait/data/reminders/reminder_providers.dart';
import 'package:wrait/data/transcription/transcription_providers.dart';
import 'package:wrait/data/transcription/transcription_service.dart';
import 'package:wrait/presentation/main/main_screen_test_keys.dart';
import 'package:wrait/presentation/settings/settings_test_keys.dart';

import '../test/test_doubles/fake_secure_storage.dart';

const _permissionsChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reminders toggle persists state through settings', (
    tester,
  ) async {
    final harness = await _RemindersHarness.create();
    addTearDown(harness.dispose);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionsChannel, (call) async {
      if (call.method == 'checkPermissionStatus') {
        return 1; // PermissionStatus.granted
      }
      if (call.method == 'requestPermissions') {
        final permissions = call.arguments as List<Object?>;
        return <int, int>{for (final p in permissions) (p! as int): 1};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permissionsChannel, null);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(mainSettingsButtonKey));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(remindersToggleKey),
      find.byType(ListView),
      const Offset(0, -200),
    );

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(remindersToggleKey),
    );
    expect(toggle.value, isFalse);

    await tester.tap(find.byKey(remindersToggleKey));
    // The toggle handler is async (permission check + preference save).
    // Pump extra frames to let the async work complete before settling.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final afterEnable = tester.widget<SwitchListTile>(
      find.byKey(remindersToggleKey),
    );
    expect(afterEnable.value, isTrue);

    expect(
      harness.sharedPreferences.getBool(
        PreferencesRepositoryImpl.remindersEnabledKey,
      ),
      isTrue,
    );
    expect(
      harness.fakeNotifications.scheduledNotifications,
      isNotEmpty,
    );

    await tester.tap(find.byKey(remindersToggleKey));
    await tester.pumpAndSettle();

    final afterDisable = tester.widget<SwitchListTile>(
      find.byKey(remindersToggleKey),
    );
    expect(afterDisable.value, isFalse);

    expect(
      harness.sharedPreferences.getBool(
        PreferencesRepositoryImpl.remindersEnabledKey,
      ),
      isFalse,
    );
    expect(harness.fakeNotifications.cancelAllCallCount, greaterThan(0));
  });
}

class _RemindersHarness {
  _RemindersHarness({
    required this.container,
    required this.database,
    required this.tempDirectory,
    required this.sharedPreferences,
    required this.fakeNotifications,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory tempDirectory;
  final SharedPreferences sharedPreferences;
  final _FakeNotificationScheduler fakeNotifications;

  static Future<_RemindersHarness> create() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));

    final tempDirectory = await Directory.systemTemp.createTemp(
      'wrait-reminders-int',
    );
    final database = await LocalEntryDatabase.open(
      keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(49)),
      databaseFile: File(
        '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
      ),
    );
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final fakeNotifications = _FakeNotificationScheduler();
    final container = ProviderContainer(
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
        localEntryDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        notificationSchedulerProvider.overrideWithValue(fakeNotifications),
        transcriptionServiceProvider.overrideWithValue(
          const _IdleTranscriptionService(),
        ),
      ],
    );

    return _RemindersHarness(
      container: container,
      database: database,
      tempDirectory: tempDirectory,
      sharedPreferences: sharedPreferences,
      fakeNotifications: fakeNotifications,
    );
  }

  Future<void> dispose() async {
    container.dispose();
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

class _ScheduledNotification {
  _ScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
  });

  final int id;
  final String title;
  final String body;
}

class _FakeNotificationScheduler implements NotificationScheduler {
  final List<_ScheduledNotification> scheduledNotifications = [];
  int cancelAllCallCount = 0;

  @override
  Future<void> zonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDate,
    NotificationDetails details, {
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduledNotifications.add(
      _ScheduledNotification(id: id, title: title, body: body),
    );
  }

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {
    cancelAllCallCount++;
  }
}

class _IdleTranscriptionService implements TranscriptionService {
  const _IdleTranscriptionService();

  @override
  int? get hardCapDeadlineElapsedRealtime => null;

  @override
  bool get isRecording => false;

  @override
  bool get isTranscribing => false;

  @override
  Future<void> cancelLiveTranscription() async {}

  @override
  Future<void> startLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {}

  @override
  Future<TranscriptionResult> stopLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    return const TranscriptionFailure(
      reason: TranscriptionFailureReason.apiError,
    );
  }

  @override
  Future<TranscriptionResult> transcribeAudioDraft(String audioPath) async {
    return const TranscriptionFailure(
      reason: TranscriptionFailureReason.apiError,
    );
  }
}
