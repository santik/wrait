import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/presentation/app_lock/app_lock_controller.dart';
import 'package:wrait/presentation/main/recording_display_awake_coordinator.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../../test_doubles/fake_display_awake_service.dart';

void main() {
  test('enables keep-awake while resumed, unlocked, and listening', () async {
    final service = FakeDisplayAwakeService();
    RecordingDisplayAwakeCoordinator(
      service: service,
      recordingState: RecordingListening(hardCapDeadlineElapsedRealtime: 1),
      lifecycleState: AppLifecycleState.resumed,
      appLockState: const AppLockState.unlocked(),
    );

    await service.flush();
    expect(service.requests, <bool>[true]);
  });

  test('releases keep-awake when listening transitions to uploading', () async {
    final service = FakeDisplayAwakeService();
    final coordinator = RecordingDisplayAwakeCoordinator(
      service: service,
      recordingState: RecordingListening(hardCapDeadlineElapsedRealtime: 1),
      lifecycleState: AppLifecycleState.resumed,
      appLockState: const AppLockState.unlocked(),
    );

    await service.flush();
    coordinator.updateRecordingState(const RecordingUploading());

    await service.flush();
    expect(service.requests, <bool>[true, false]);
  });

  test('keeps non-listening states released', () async {
    final service = FakeDisplayAwakeService();
    final coordinator = RecordingDisplayAwakeCoordinator(
      service: service,
      recordingState: const RecordingIdle(),
      lifecycleState: AppLifecycleState.resumed,
      appLockState: const AppLockState.unlocked(),
    );

    coordinator.updateRecordingState(const RecordingProcessing());
    coordinator.updateRecordingState(
      RecordingSaved(entryId: 7, detectedLanguage: 'en-US'),
    );
    coordinator.updateRecordingState(
      const RecordingErrorState(RecordingError.apiFailed),
    );
    coordinator.updateRecordingState(const RecordingDeleted(1));

    await service.flush();
    expect(service.requests, isEmpty);
  });

  test(
    'starts released when initialized outside the resumed lifecycle',
    () async {
      final service = FakeDisplayAwakeService();
      RecordingDisplayAwakeCoordinator(
        service: service,
        recordingState: RecordingListening(hardCapDeadlineElapsedRealtime: 1),
        lifecycleState: AppLifecycleState.inactive,
        appLockState: const AppLockState.unlocked(),
      );

      await service.flush();
      expect(service.requests, isEmpty);
    },
  );

  test(
    'releases on lifecycle exit and reacquires on resume if still listening',
    () async {
      final service = FakeDisplayAwakeService();
      final coordinator = RecordingDisplayAwakeCoordinator(
        service: service,
        recordingState: RecordingListening(hardCapDeadlineElapsedRealtime: 1),
        lifecycleState: AppLifecycleState.resumed,
        appLockState: const AppLockState.unlocked(),
      );

      await service.flush();
      coordinator.updateLifecycleState(AppLifecycleState.inactive);
      await service.flush();
      coordinator.updateLifecycleState(AppLifecycleState.resumed);

      await service.flush();
      expect(service.requests, <bool>[true, false, true]);
    },
  );

  test(
    'releases on app lock and reacquires after unlock if still listening',
    () async {
      final service = FakeDisplayAwakeService();
      final coordinator = RecordingDisplayAwakeCoordinator(
        service: service,
        recordingState: RecordingListening(hardCapDeadlineElapsedRealtime: 1),
        lifecycleState: AppLifecycleState.resumed,
        appLockState: const AppLockState.unlocked(),
      );

      await service.flush();
      coordinator.updateAppLockState(const AppLockState.locked());
      await service.flush();
      coordinator.updateAppLockState(const AppLockState.unlocked());

      await service.flush();
      expect(service.requests, <bool>[true, false, true]);
    },
  );

  test('duplicate active and inactive transitions are idempotent', () async {
    final service = FakeDisplayAwakeService();
    final coordinator = RecordingDisplayAwakeCoordinator(
      service: service,
      recordingState: const RecordingIdle(),
      lifecycleState: AppLifecycleState.resumed,
      appLockState: const AppLockState.unlocked(),
    );

    coordinator.updateRecordingState(
      RecordingListening(hardCapDeadlineElapsedRealtime: 1),
    );
    await service.flush();
    coordinator.updateRecordingState(
      RecordingListening(hardCapDeadlineElapsedRealtime: 1),
    );
    coordinator.updateLifecycleState(AppLifecycleState.inactive);
    await service.flush();
    coordinator.updateLifecycleState(AppLifecycleState.inactive);

    await service.flush();
    expect(service.requests, <bool>[true, false]);
  });

  test('coalesces rapid transitions to the final inactive state before any platform call starts', () async {
    final service = FakeDisplayAwakeService(autoComplete: false);
    final coordinator = RecordingDisplayAwakeCoordinator(
      service: service,
      recordingState: const RecordingIdle(),
      lifecycleState: AppLifecycleState.resumed,
      appLockState: const AppLockState.unlocked(),
    );

    coordinator.updateRecordingState(
      RecordingListening(hardCapDeadlineElapsedRealtime: 1),
    );
    coordinator.updateLifecycleState(AppLifecycleState.inactive);
    coordinator.updateLifecycleState(AppLifecycleState.resumed);
    coordinator.updateRecordingState(const RecordingUploading());

    await service.flush();
    expect(service.requests, isEmpty);
  });

  test('dispose releases keep-awake only once', () async {
    final service = FakeDisplayAwakeService();
    final coordinator = RecordingDisplayAwakeCoordinator(
      service: service,
      recordingState: RecordingListening(hardCapDeadlineElapsedRealtime: 1),
      lifecycleState: AppLifecycleState.resumed,
      appLockState: const AppLockState.unlocked(),
    );

    await service.flush();
    coordinator.dispose();
    coordinator.dispose();

    await service.flush();
    expect(service.requests, <bool>[true, false]);
  });

  test('dispose releases after an in-flight enable completes', () async {
    final service = FakeDisplayAwakeService(autoComplete: false);
    final coordinator = RecordingDisplayAwakeCoordinator(
      service: service,
      recordingState: RecordingListening(hardCapDeadlineElapsedRealtime: 1),
      lifecycleState: AppLifecycleState.resumed,
      appLockState: const AppLockState.unlocked(),
    );

    await service.flush();
    expect(service.requests, <bool>[true]);
    expect(service.pendingRequestCount, 1);

    coordinator.dispose();
    await service.flush();
    expect(service.requests, <bool>[true]);

    service.completeNext(true);
    await service.flush();
    expect(service.requests, <bool>[true, false]);

    service.completeNext(true);
    await service.flush();
    expect(service.pendingRequestCount, 0);
  });

  test('retries a failed enable on a repeated listening update', () async {
    final service = FakeDisplayAwakeService();
    service.enqueueResult(false);
    final coordinator = RecordingDisplayAwakeCoordinator(
      service: service,
      recordingState: RecordingListening(hardCapDeadlineElapsedRealtime: 1),
      lifecycleState: AppLifecycleState.resumed,
      appLockState: const AppLockState.unlocked(),
    );

    await service.flush();
    expect(service.requests, <bool>[true]);

    coordinator.updateRecordingState(
      RecordingListening(hardCapDeadlineElapsedRealtime: 1),
    );

    await service.flush();
    expect(service.requests, <bool>[true, true]);
  });

  test('updates are ignored after disposal', () async {
    final service = FakeDisplayAwakeService();
    final coordinator = RecordingDisplayAwakeCoordinator(
      service: service,
      recordingState: RecordingListening(hardCapDeadlineElapsedRealtime: 1),
      lifecycleState: AppLifecycleState.resumed,
      appLockState: const AppLockState.unlocked(),
    );

    await service.flush();
    coordinator.dispose();
    await service.flush();
    expect(service.requests, <bool>[true, false]);

    coordinator.updateRecordingState(
      RecordingListening(hardCapDeadlineElapsedRealtime: 2),
    );
    coordinator.updateLifecycleState(AppLifecycleState.resumed);
    coordinator.updateAppLockState(const AppLockState.unlocked());

    await service.flush();
    expect(service.requests, <bool>[true, false]);
  });
}
