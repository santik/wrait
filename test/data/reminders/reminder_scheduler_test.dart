import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_core;
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/reminders/entry_date_checker.dart';
import 'package:wrait/data/reminders/notification_scheduler.dart';
import 'package:wrait/data/reminders/reminder_scheduler.dart';

void main() {
  late _FakeNotificationScheduler fakeNotifications;
  late _FakeEntryDateChecker fakeEntryDateChecker;
  late ReminderScheduler scheduler;

  setUpAll(() {
    tz.initializeTimeZones();
    tz_core.setLocalLocation(tz_core.getLocation('America/New_York'));
  });

  setUp(() {
    fakeNotifications = _FakeNotificationScheduler();
    fakeEntryDateChecker = _FakeEntryDateChecker();
    scheduler = ReminderScheduler(
      notificationScheduler: fakeNotifications,
      entryDateChecker: fakeEntryDateChecker,
    );
  });

  group('updateSchedule', () {
    test('cancels all when disabled', () async {
      await scheduler.updateSchedule(enabled: false);

      expect(fakeNotifications.cancelAllCallCount, 1);
      expect(fakeNotifications.scheduledNotifications, isEmpty);
    });

    test('schedules both reminders when enabled and no entry today', () async {
      fakeEntryDateChecker.hasEntryResult = false;

      await scheduler.updateSchedule(enabled: true);

      expect(fakeNotifications.scheduledNotifications, hasLength(2));
      final ids =
          fakeNotifications.scheduledNotifications.map((n) => n.id).toSet();
      expect(ids, {
        ReminderScheduler.morningNotificationId,
        ReminderScheduler.eveningNotificationId,
      });
    });

    test('cancels morning reminder when entry exists today', () async {
      fakeEntryDateChecker.hasEntryResult = true;

      await scheduler.updateSchedule(enabled: true);

      final cancelledIds = fakeNotifications.cancelledIds;
      expect(cancelledIds, contains(ReminderScheduler.morningNotificationId));

      final scheduledIds =
          fakeNotifications.scheduledNotifications.map((n) => n.id).toSet();
      expect(
        scheduledIds,
        contains(ReminderScheduler.eveningNotificationId),
      );
      expect(
        scheduledIds,
        isNot(contains(ReminderScheduler.morningNotificationId)),
      );
    });

    test('cancels evening reminder when quota exhausted', () async {
      fakeEntryDateChecker.hasEntryResult = false;
      final quota = RecordQuotaState(
        limit: 10,
        count: 10,
        remaining: 0,
        resetAt: DateTime.now().add(const Duration(days: 1)),
      );

      await scheduler.updateSchedule(enabled: true, quotaState: quota);

      final cancelledIds = fakeNotifications.cancelledIds;
      expect(cancelledIds, contains(ReminderScheduler.eveningNotificationId));

      final scheduledIds =
          fakeNotifications.scheduledNotifications.map((n) => n.id).toSet();
      expect(scheduledIds, contains(ReminderScheduler.morningNotificationId));
      expect(
        scheduledIds,
        isNot(contains(ReminderScheduler.eveningNotificationId)),
      );
    });

    test('schedules evening reminder when quota is null (fail-open)', () async {
      fakeEntryDateChecker.hasEntryResult = false;

      await scheduler.updateSchedule(enabled: true, quotaState: null);

      final scheduledIds =
          fakeNotifications.scheduledNotifications.map((n) => n.id).toSet();
      expect(scheduledIds, contains(ReminderScheduler.eveningNotificationId));
    });

    test('schedules evening reminder when quota has remaining', () async {
      fakeEntryDateChecker.hasEntryResult = false;
      final quota = RecordQuotaState(
        limit: 10,
        count: 5,
        remaining: 5,
        resetAt: DateTime.now().add(const Duration(days: 1)),
      );

      await scheduler.updateSchedule(enabled: true, quotaState: quota);

      final scheduledIds =
          fakeNotifications.scheduledNotifications.map((n) => n.id).toSet();
      expect(scheduledIds, contains(ReminderScheduler.eveningNotificationId));
    });
  });

  group('onEntryCreated', () {
    test('cancels morning notification', () async {
      await scheduler.onEntryCreated();

      expect(fakeNotifications.cancelledIds, [
        ReminderScheduler.morningNotificationId,
      ]);
    });
  });

  group('onQuotaChanged', () {
    test('cancels evening notification when remaining is 0', () async {
      final quota = RecordQuotaState(
        limit: 10,
        count: 10,
        remaining: 0,
        resetAt: DateTime.now().add(const Duration(days: 1)),
      );

      await scheduler.onQuotaChanged(quota);

      expect(fakeNotifications.cancelledIds, [
        ReminderScheduler.eveningNotificationId,
      ]);
    });

    test('does nothing when quota is null', () async {
      await scheduler.onQuotaChanged(null);

      expect(fakeNotifications.cancelledIds, isEmpty);
    });

    test('does nothing when remaining is positive', () async {
      final quota = RecordQuotaState(
        limit: 10,
        count: 5,
        remaining: 5,
        resetAt: DateTime.now().add(const Duration(days: 1)),
      );

      await scheduler.onQuotaChanged(quota);

      expect(fakeNotifications.cancelledIds, isEmpty);
    });
  });

  group('scheduling details', () {
    test('uses inexact scheduling mode', () async {
      fakeEntryDateChecker.hasEntryResult = false;

      await scheduler.updateSchedule(enabled: true);

      for (final notification in fakeNotifications.scheduledNotifications) {
        expect(
          notification.androidScheduleMode,
          AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    });

    test('uses daily time component matching', () async {
      fakeEntryDateChecker.hasEntryResult = false;

      await scheduler.updateSchedule(enabled: true);

      for (final notification in fakeNotifications.scheduledNotifications) {
        expect(
          notification.matchDateTimeComponents,
          DateTimeComponents.time,
        );
      }
    });

    test('morning notification scheduled at 09:00', () async {
      fakeEntryDateChecker.hasEntryResult = false;

      await scheduler.updateSchedule(enabled: true);

      final morning = fakeNotifications.scheduledNotifications.firstWhere(
        (n) => n.id == ReminderScheduler.morningNotificationId,
      );
      expect(morning.scheduledDate.hour, ReminderScheduler.morningHour);
      expect(morning.scheduledDate.minute, 0);
    });

    test('evening notification scheduled at 20:00', () async {
      fakeEntryDateChecker.hasEntryResult = false;

      await scheduler.updateSchedule(enabled: true);

      final evening = fakeNotifications.scheduledNotifications.firstWhere(
        (n) => n.id == ReminderScheduler.eveningNotificationId,
      );
      expect(evening.scheduledDate.hour, ReminderScheduler.eveningHour);
      expect(evening.scheduledDate.minute, 0);
    });
  });
}

class _ScheduledNotification {
  _ScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    required this.androidScheduleMode,
    this.matchDateTimeComponents,
  });

  final int id;
  final String title;
  final String body;
  final tz_core.TZDateTime scheduledDate;
  final AndroidScheduleMode androidScheduleMode;
  final DateTimeComponents? matchDateTimeComponents;
}

class _FakeNotificationScheduler implements NotificationScheduler {
  final List<_ScheduledNotification> scheduledNotifications = [];
  final List<int> cancelledIds = [];
  int cancelAllCallCount = 0;

  @override
  Future<void> zonedSchedule(
    int id,
    String title,
    String body,
    tz_core.TZDateTime scheduledDate,
    NotificationDetails details, {
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduledNotifications.add(
      _ScheduledNotification(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        androidScheduleMode: androidScheduleMode,
        matchDateTimeComponents: matchDateTimeComponents,
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCallCount++;
  }
}

class _FakeEntryDateChecker implements EntryDateChecker {
  bool hasEntryResult = false;

  @override
  Future<bool> hasEntryOnDate(int startOfDayMs, int endOfDayMs) async {
    return hasEntryResult;
  }
}
