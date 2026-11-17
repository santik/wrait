import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/main/main_screen_stats.dart';
import '../api/backend_providers.dart';
import '../api/record_quota_state.dart';
import 'widget_sync_payload.dart';
import 'widget_sync_service.dart';

/// The single [WidgetSyncService] used to push data to the home-screen widget.
final widgetSyncServiceProvider = Provider<WidgetSyncService>((ref) {
  return WidgetSyncService();
});

/// Wires the widget sync to the app's reactive sources (spec 055 plan D-4).
///
/// Pushes the current entry stats + daily quota to the shared widget store
/// whenever either source changes:
///
/// * [mainScreenStatsProvider] — emits on entry create/delete, so the widget's
///   entry count and active days stay current.
/// * [sessionRecordQuotaStateProvider] — emits when the backend returns a fresh
///   quota, so the widget's "used / total" stays current.
///
/// Fires immediately for stats so the widget is seeded at launch (quota may be
/// null until the first backend sync, in which case the quota group is left
/// untouched — see [WidgetSyncService.sync]).
void startWidgetSync(ProviderContainer container) {
  // Single-flight with trailing coalescing: only one sync runs at a time, and
  // changes that arrive mid-sync trigger exactly one more run afterwards. This
  // prevents the two listeners from interleaving writes (a transiently mixed
  // payload) and collapses bursts (e.g. a CSV import) into few updates.
  var syncing = false;
  var pending = false;

  Future<void> pushCurrent() async {
    if (syncing) {
      pending = true;
      return;
    }
    syncing = true;
    try {
      do {
        pending = false;
        final stats = container.read(mainScreenStatsProvider).value;
        if (stats == null) {
          break;
        }
        final quota = container.read(sessionRecordQuotaStateProvider);
        final payload = WidgetSyncPayload.from(
          entryCount: stats.entryCount,
          activeDays: stats.activeDays,
          quota: quota,
        );
        try {
          await container.read(widgetSyncServiceProvider).sync(payload);
        } catch (error, stackTrace) {
          developer.log(
            'Failed to sync home-screen widget.',
            name: 'WidgetSync',
            error: error,
            stackTrace: stackTrace,
          );
        }
      } while (pending);
    } finally {
      syncing = false;
    }
  }

  container.listen<AsyncValue<MainScreenStatsData>>(
    mainScreenStatsProvider,
    (previous, next) => unawaited(pushCurrent()),
    fireImmediately: true,
  );

  container.listen<RecordQuotaState?>(
    sessionRecordQuotaStateProvider,
    (previous, next) => unawaited(pushCurrent()),
  );
}
