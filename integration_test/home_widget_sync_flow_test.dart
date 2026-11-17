import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/widget/widget_sync_payload.dart';
import 'package:wrait/data/widget/widget_sync_provider.dart';
import 'package:wrait/data/widget/widget_sync_service.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/main.dart';
import 'package:wrait/presentation/app_lock/app_lock_gate.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'widget sync pushes stats through the real provider wiring; app opens '
    'record-ready and stays behind the app-lock gate',
    (tester) async {
      final service = _RecordingWidgetSyncService();
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
          entryRepositoryProvider.overrideWithValue(
            _StubEntryRepository(_seededEntries),
          ),
          widgetSyncServiceProvider.overrideWithValue(service),
        ],
      );

      // Mirror the real bootstrap wiring.
      startWidgetSync(container);

      await tester.pumpWidget(
        BootstrapApp(
          appConfig: _appConfig,
          bootstrapRuntime: (_) async => AppBootstrapRuntime(
            container: container,
            dispose: () async => container.dispose(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The app opens to the record-ready main screen, behind the lock gate.
      expect(find.byType(AppLockGate), findsOneWidget);
      expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);

      // Entry stats flowed to the widget sync; quota omitted (never synced).
      expect(service.payloads, isNotEmpty);
      final statsOnly = service.payloads.last;
      expect(statsOnly.entryCount, _seededEntries.length);
      expect(statsOnly.hasQuota, isFalse);

      // When the backend quota arrives, it is pushed to the widget.
      container.read(sessionRecordQuotaStateProvider.notifier).setQuota(
        RecordQuotaState(
          limit: 10,
          count: 3,
          remaining: 7,
          resetAt: DateTime.now().add(const Duration(hours: 6)),
        ),
      );
      await tester.pumpAndSettle();

      final withQuota = service.payloads.last;
      expect(withQuota.hasQuota, isTrue);
      expect(withQuota.quotaUsed, 3);
      expect(withQuota.quotaLimit, 10);
    },
  );
}

const _appConfig = AppConfig(
  backendUrl: 'https://wrait-backend.vercel.app',
  proxySecret: '',
  recordingHardCapMs: 120000,
);

final List<Entry> _seededEntries = <Entry>[
  Entry(
    id: 1,
    rawTranscript: 'first',
    type: EntryType.saved,
    language: 'en',
    createdAt: DateTime(2026, 11, 15).millisecondsSinceEpoch,
    wordCount: 1,
  ),
  Entry(
    id: 2,
    rawTranscript: 'second',
    type: EntryType.saved,
    language: 'en',
    createdAt: DateTime(2026, 11, 16).millisecondsSinceEpoch,
    wordCount: 1,
  ),
];

class _RecordingWidgetSyncService extends WidgetSyncService {
  _RecordingWidgetSyncService()
    : super(
        saveWidgetData: (_, _) async => true,
        updateWidget: () async => true,
        setAppGroupId: (_) async => true,
      );

  final List<WidgetSyncPayload> payloads = <WidgetSyncPayload>[];

  @override
  Future<void> sync(WidgetSyncPayload payload) async {
    payloads.add(payload);
    await super.sync(payload);
  }
}

class _StubEntryRepository implements EntryRepository {
  _StubEntryRepository(this._entries);

  final List<Entry> _entries;

  @override
  Stream<List<Entry>> watchAllEntries() => Stream<List<Entry>>.value(_entries);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
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
