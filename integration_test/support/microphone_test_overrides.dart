import 'package:wrait/data/audio/audio_recording_providers.dart';
import 'package:wrait/data/audio/microphone_permission_service.dart';

/// A microphone permission service that reports access as already granted.
///
/// Integration tests that drive the real recording path cannot rely on a native
/// permission grant: the iOS Simulator cannot surface the OS permission dialog
/// to the test harness, and the `simctl` grant is not reliable across the app
/// reinstalls `flutter test` performs between files (and re-granting mid-run
/// restarts the app). Injecting this keeps those tests off the native dialog and
/// fully deterministic across platforms.
class GrantedMicrophonePermissionService
    implements MicrophonePermissionService {
  const GrantedMicrophonePermissionService();

  @override
  Future<MicrophoneAccessState> getMicrophoneAccess() async =>
      MicrophoneAccessState.granted;

  @override
  Future<MicrophoneAccessState> requestMicrophoneAccess() async =>
      MicrophoneAccessState.granted;

  @override
  Future<bool> openMicrophonePermissionSettings() async => true;
}

/// Provider overrides that grant microphone access. Spread into a test's
/// `overrides` list: `...grantedMicrophoneOverrides`.
final grantedMicrophoneOverrides = [
  microphonePermissionServiceProvider.overrideWithValue(
    const GrantedMicrophonePermissionService(),
  ),
];
