import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/backend_providers.dart';
import '../reminders/reminder_providers.dart';
import 'preferences_providers.dart';

class RemindersEnabledState {
  const RemindersEnabledState({
    this.isReady = false,
    this.enabled = false,
    this.isSaving = false,
    this.saveFailed = false,
  });

  final bool isReady;
  final bool enabled;
  final bool isSaving;
  final bool saveFailed;
}

final remindersEnabledControllerProvider =
    NotifierProvider<RemindersEnabledController, RemindersEnabledState>(
      RemindersEnabledController.new,
    );

class RemindersEnabledController extends Notifier<RemindersEnabledState> {
  @override
  RemindersEnabledState build() => const RemindersEnabledState();

  Future<void> load() async {
    try {
      final enabled = await ref
          .read(remindersPreferencesRepositoryProvider)
          .getRemindersEnabled();
      if (!ref.mounted) {
        return;
      }
      state = RemindersEnabledState(isReady: true, enabled: enabled);
    } catch (_) {
      if (!ref.mounted) {
        return;
      }
      // Default to disabled if reading fails.
      state = const RemindersEnabledState(isReady: true);
    }
  }

  Future<void> setEnabled(bool value) async {
    if (state.isSaving) {
      return;
    }

    final previous = state.enabled;
    state = RemindersEnabledState(
      isReady: true,
      enabled: value,
      isSaving: true,
    );

    try {
      await ref
          .read(remindersPreferencesRepositoryProvider)
          .setRemindersEnabled(value);
    } catch (_) {
      if (ref.mounted) {
        state = RemindersEnabledState(
          isReady: true,
          enabled: previous,
          saveFailed: true,
        );
      }
      return;
    }

    try {
      await ref
          .read(reminderSchedulerProvider)
          .updateSchedule(
            enabled: value,
            quotaState: ref.read(sessionRecordQuotaStateProvider),
          );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to update reminder schedule.',
        name: 'Reminders',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (!ref.mounted) {
      return;
    }
    state = RemindersEnabledState(isReady: true, enabled: value);
  }
}
