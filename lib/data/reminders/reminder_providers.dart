import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/backend_providers.dart';
import '../api/record_quota_state.dart';
import '../entries/entry_providers.dart';
import '../preferences/reminders_enabled_controller.dart';
import 'entry_date_checker.dart';
import 'notification_scheduler.dart';
import 'reminder_scheduler.dart';

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => throw UnimplementedError(
    'NotificationScheduler must be provided at app startup.',
  ),
);

final entryDateCheckerProvider = Provider<EntryDateChecker>(
  (ref) => DaoEntryDateChecker(
    ref.watch(localEntryDatabaseProvider).entryDao,
  ),
);

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return ReminderScheduler(
    notificationScheduler: ref.watch(notificationSchedulerProvider),
    entryDateChecker: ref.watch(entryDateCheckerProvider),
  );
});

/// Call after a new entry is created to cancel today's morning reminder.
/// Accepts a [Ref] (from a Notifier) or a [ProviderContainer].
void notifyEntryCreatedFromRef(Ref ref) {
  final remindersState = ref.read(remindersEnabledControllerProvider);
  if (!remindersState.isReady || !remindersState.enabled) {
    return;
  }

  unawaited(
    ref.read(reminderSchedulerProvider).onEntryCreated().catchError((
      error,
      stackTrace,
    ) {
      developer.log(
        'Failed to cancel morning reminder after entry creation.',
        name: 'ReminderSync',
        error: error,
        stackTrace: stackTrace,
      );
    }),
  );
}

/// Listens to quota state changes and cancels the evening reminder
/// when remaining quota hits 0.
void startQuotaReminderSync(ProviderContainer container) {
  container.listen<RecordQuotaState?>(
    sessionRecordQuotaStateProvider,
    (previous, next) {
      final remindersState = container.read(remindersEnabledControllerProvider);
      if (!remindersState.isReady || !remindersState.enabled) {
        return;
      }

      unawaited(
        container
            .read(reminderSchedulerProvider)
            .onQuotaChanged(next)
            .catchError((error, stackTrace) {
              developer.log(
                'Failed to update evening reminder after quota change.',
                name: 'ReminderSync',
                error: error,
                stackTrace: stackTrace,
              );
            }),
      );
    },
  );
}
