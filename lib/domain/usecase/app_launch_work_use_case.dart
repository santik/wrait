import 'register_device_on_launch_use_case.dart';

typedef RetryPendingDraftsCallback = Future<void> Function();
typedef AppLaunchWorkWarningLogger = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

class AppLaunchWorkUseCase {
  AppLaunchWorkUseCase({
    required this.registerDeviceOnLaunch,
    required this.retryPendingDrafts,
    required this.logWarning,
  });

  final RegisterDeviceOnLaunchUseCase registerDeviceOnLaunch;
  final RetryPendingDraftsCallback retryPendingDrafts;
  final AppLaunchWorkWarningLogger logWarning;

  Future<void>? _inFlight;

  Future<void> call() {
    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _run();
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
    return future;
  }

  Future<void> _run() async {
    final registrationResult = await registerDeviceOnLaunch();
    if (registrationResult != LaunchDeviceRegistrationResult.success) {
      return;
    }

    try {
      await retryPendingDrafts();
    } catch (error, stackTrace) {
      logWarning(
        'Draft retry crashed during app launch.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
