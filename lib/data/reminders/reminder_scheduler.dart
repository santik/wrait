import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../api/record_quota_state.dart';
import 'entry_date_checker.dart';
import 'notification_scheduler.dart';

class ReminderScheduler {
  ReminderScheduler({
    required this._notificationScheduler,
    required this._entryDateChecker,
  });

  final NotificationScheduler _notificationScheduler;
  final EntryDateChecker _entryDateChecker;

  static const morningNotificationId = 1;
  static const eveningNotificationId = 2;
  static const morningHour = 9;
  static const eveningHour = 20;

  Future<void> updateSchedule({
    required bool enabled,
    RecordQuotaState? quotaState,
  }) async {
    if (!enabled) {
      await _notificationScheduler.cancelAll();
      return;
    }

    await _scheduleMorningReminder();
    await _scheduleEveningReminder(quotaState);
  }

  Future<void> onEntryCreated() async {
    await _notificationScheduler.cancel(morningNotificationId);
  }

  Future<void> onQuotaChanged(RecordQuotaState? quotaState) async {
    if (quotaState != null && quotaState.remaining <= 0) {
      await _notificationScheduler.cancel(eveningNotificationId);
    }
  }

  Future<void> _scheduleMorningReminder() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day + 1);
    final hasEntry = await _entryDateChecker.hasEntryOnDate(
      startOfDay.millisecondsSinceEpoch,
      endOfDay.millisecondsSinceEpoch,
    );

    if (hasEntry) {
      await _notificationScheduler.cancel(morningNotificationId);
      return;
    }

    await _scheduleDaily(
      id: morningNotificationId,
      hour: morningHour,
      minute: 0,
      title: 'wrait',
      body: 'Start your day with a reflection',
    );
  }

  Future<void> _scheduleEveningReminder(RecordQuotaState? quotaState) async {
    if (quotaState != null && quotaState.remaining <= 0) {
      await _notificationScheduler.cancel(eveningNotificationId);
      return;
    }

    await _scheduleDaily(
      id: eveningNotificationId,
      hour: eveningHour,
      minute: 0,
      title: 'wrait',
      body: 'You still have recordings left today',
    );
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_reminders',
      'Daily Reminders',
      channelDescription: 'Reminders to journal',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const darwinDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationScheduler.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
