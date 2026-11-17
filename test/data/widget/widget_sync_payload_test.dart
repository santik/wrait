import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/widget/widget_sync_payload.dart';

void main() {
  group('WidgetSyncPayload.from', () {
    test('maps entry stats', () {
      final payload = WidgetSyncPayload.from(
        entryCount: 12,
        activeDays: 5,
        quota: null,
      );

      expect(payload.entryCount, 12);
      expect(payload.activeDays, 5);
    });

    test('omits the quota group when quota is null', () {
      final payload = WidgetSyncPayload.from(
        entryCount: 0,
        activeDays: 0,
        quota: null,
      );

      expect(payload.hasQuota, isFalse);
      expect(payload.quotaUsed, isNull);
      expect(payload.quotaLimit, isNull);
      expect(payload.quotaResetAtEpochMs, isNull);
    });

    test('maps the full quota group, with resetAt as epoch ms', () {
      final resetAt = DateTime.utc(2026, 11, 17);
      final payload = WidgetSyncPayload.from(
        entryCount: 3,
        activeDays: 2,
        quota: RecordQuotaState(
          limit: 10,
          count: 3,
          remaining: 7,
          resetAt: resetAt,
        ),
      );

      expect(payload.hasQuota, isTrue);
      expect(payload.quotaUsed, 3);
      expect(payload.quotaLimit, 10);
      expect(payload.quotaResetAtEpochMs, resetAt.millisecondsSinceEpoch);
    });
  });
}
