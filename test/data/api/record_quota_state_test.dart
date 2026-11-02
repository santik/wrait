import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/api/generated/backend_api_generated.dart';
import 'package:wrait/data/api/record_quota_state.dart';

void main() {
  group('RecordQuotaValidation', () {
    test('accepts internally consistent quota values', () {
      final quota = RecordQuota(
        limit: 10,
        count: 3,
        remaining: 7,
        resetAt: DateTime.utc(2026, 6, 10),
      );

      final result = quota.toValidatedStateOrNull();

      expect(result, isNotNull);
      expect(result?.limit, 10);
      expect(result?.count, 3);
      expect(result?.remaining, 7);
      expect(result?.resetAt, DateTime.utc(2026, 6, 10));
    });

    test('rejects negative limit', () {
      final quota = RecordQuota(
        limit: -1,
        count: 0,
        remaining: 0,
        resetAt: DateTime.utc(2026, 6, 10),
      );

      expect(quota.toValidatedStateOrNull(), isNull);
    });

    test('rejects negative count', () {
      final quota = RecordQuota(
        limit: 5,
        count: -1,
        remaining: 0,
        resetAt: DateTime.utc(2026, 6, 10),
      );

      expect(quota.toValidatedStateOrNull(), isNull);
    });

    test('rejects negative remaining', () {
      final quota = RecordQuota(
        limit: 5,
        count: 1,
        remaining: -1,
        resetAt: DateTime.utc(2026, 6, 10),
      );

      expect(quota.toValidatedStateOrNull(), isNull);
    });

    test('rejects count greater than limit', () {
      final quota = RecordQuota(
        limit: 2,
        count: 3,
        remaining: 0,
        resetAt: DateTime.utc(2026, 6, 10),
      );

      expect(quota.toValidatedStateOrNull(), isNull);
    });

    test('rejects remaining greater than limit', () {
      final quota = RecordQuota(
        limit: 2,
        count: 1,
        remaining: 3,
        resetAt: DateTime.utc(2026, 6, 10),
      );

      expect(quota.toValidatedStateOrNull(), isNull);
    });
  });
}
