import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/widget/widget_sync_payload.dart';
import 'package:wrait/data/widget/widget_sync_service.dart';

void main() {
  late Map<String, Object?> saved;
  late int updateCount;
  late List<String> appGroupIds;
  late WidgetSyncService service;

  setUp(() {
    saved = <String, Object?>{};
    updateCount = 0;
    appGroupIds = <String>[];
    service = WidgetSyncService(
      saveWidgetData: (id, data) async {
        saved[id] = data;
        return true;
      },
      updateWidget: () async {
        updateCount++;
        return true;
      },
      setAppGroupId: (id) async {
        appGroupIds.add(id);
        return true;
      },
    );
  });

  test('writes entry stats, sets the app group, and triggers an update', () async {
    await service.sync(
      const WidgetSyncPayload(entryCount: 12, activeDays: 5),
    );

    expect(saved[WidgetSyncKeys.entryCount], 12);
    expect(saved[WidgetSyncKeys.activeDays], 5);
    expect(updateCount, 1);
    expect(appGroupIds, <String>[kWidgetAppGroupId]);
  });

  test('writes the full quota group when present', () async {
    await service.sync(
      const WidgetSyncPayload(
        entryCount: 3,
        activeDays: 2,
        quotaUsed: 3,
        quotaLimit: 10,
        quotaResetAtEpochMs: 1763337600000,
      ),
    );

    expect(saved[WidgetSyncKeys.quotaUsed], 3);
    expect(saved[WidgetSyncKeys.quotaLimit], 10);
    expect(saved[WidgetSyncKeys.quotaResetAtEpochMs], 1763337600000);
    expect(updateCount, 1);
  });

  test('skips quota keys when quota is absent (keeps the last cached values)', () async {
    await service.sync(
      const WidgetSyncPayload(entryCount: 1, activeDays: 1),
    );

    expect(saved.containsKey(WidgetSyncKeys.quotaUsed), isFalse);
    expect(saved.containsKey(WidgetSyncKeys.quotaLimit), isFalse);
    expect(saved.containsKey(WidgetSyncKeys.quotaResetAtEpochMs), isFalse);
    expect(updateCount, 1);
  });

  test('sets the app group id once across multiple syncs', () async {
    await service.sync(const WidgetSyncPayload(entryCount: 1, activeDays: 1));
    await service.sync(const WidgetSyncPayload(entryCount: 2, activeDays: 1));

    expect(appGroupIds, <String>[kWidgetAppGroupId]);
  });

  // Contract: these literal values are hardcoded independently in the native
  // Android (WraitWidgetProvider.kt) and iOS (WraitWidget.swift) widgets. A
  // rename here must be mirrored there, so pin the literals.
  test('shared-store key literals match the native contract', () {
    expect(WidgetSyncKeys.entryCount, 'entryCount');
    expect(WidgetSyncKeys.activeDays, 'activeDays');
    expect(WidgetSyncKeys.quotaUsed, 'quotaUsed');
    expect(WidgetSyncKeys.quotaLimit, 'quotaLimit');
    expect(WidgetSyncKeys.quotaResetAtEpochMs, 'quotaResetAtEpochMs');
    expect(kWidgetAppGroupId, 'group.com.wrait.flutter');
    expect(kWidgetAndroidName, 'WraitWidgetProvider');
    expect(kWidgetAndroidQualifiedName, 'com.wrait.flutter.WraitWidgetProvider');
    expect(kWidgetIOSName, 'WraitWidget');
  });
}
