import 'generated/backend_api_generated.dart';

class RecordQuotaState {
  const RecordQuotaState({
    required this.limit,
    required this.count,
    required this.remaining,
    required this.resetAt,
  });

  final int limit;
  final int count;
  final int remaining;
  final DateTime resetAt;
}

extension RecordQuotaValidation on RecordQuota {
  RecordQuotaState? toValidatedStateOrNull() {
    if (limit < 0) {
      return null;
    }
    if (count < 0) {
      return null;
    }
    if (remaining < 0) {
      return null;
    }
    if (count > limit) {
      return null;
    }
    if (remaining > limit) {
      return null;
    }

    return RecordQuotaState(
      limit: limit,
      count: count,
      remaining: remaining,
      resetAt: resetAt,
    );
  }
}
