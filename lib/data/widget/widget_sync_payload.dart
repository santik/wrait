import '../api/record_quota_state.dart';

/// The aggregate, non-content values the app writes to the home-screen widget's
/// shared store. Never contains entry text, transcripts, tags, or per-entry
/// timestamps (spec 055 Security).
///
/// The quota group ([quotaUsed], [quotaLimit], [quotaResetAtEpochMs]) is either
/// fully present or fully absent. It is absent until the app has received a
/// [RecordQuotaState] from the backend; the widget omits the quota line in that
/// case (spec 055 Cross-platform / Reliability).
class WidgetSyncPayload {
  const WidgetSyncPayload({
    required this.entryCount,
    required this.activeDays,
    this.quotaUsed,
    this.quotaLimit,
    this.quotaResetAtEpochMs,
  });

  /// Total entries, derived from the local database.
  final int entryCount;

  /// Distinct local calendar days with at least one entry.
  final int activeDays;

  /// Recordings taken in the current quota period ([RecordQuotaState.count]).
  final int? quotaUsed;

  /// The daily recording limit ([RecordQuotaState.limit]).
  final int? quotaLimit;

  /// When the current quota period resets, as epoch milliseconds. Used by the
  /// native widget to apply the optimistic daily reset at render time.
  final int? quotaResetAtEpochMs;

  /// Whether a complete quota group is present and should be written/displayed.
  bool get hasQuota =>
      quotaUsed != null && quotaLimit != null && quotaResetAtEpochMs != null;

  /// Builds a payload from the entry stats and the (possibly null) session
  /// quota. A null [quota] yields an absent quota group — callers must not
  /// overwrite a previously cached quota with these nulls (see
  /// [WidgetSyncService]).
  factory WidgetSyncPayload.from({
    required int entryCount,
    required int activeDays,
    RecordQuotaState? quota,
  }) {
    return WidgetSyncPayload(
      entryCount: entryCount,
      activeDays: activeDays,
      quotaUsed: quota?.count,
      quotaLimit: quota?.limit,
      quotaResetAtEpochMs: quota?.resetAt.millisecondsSinceEpoch,
    );
  }
}
