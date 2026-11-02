import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../integration_test/app_lock_flow_test.dart' as app_lock;
import '../integration_test/backend_api_client_flow_test.dart'
    as backend_api_client;
import '../integration_test/bootstrap_retry_flow_test.dart' as bootstrap_retry;
import '../integration_test/branding_surfaces_flow_test.dart'
    as branding_surfaces;
import '../integration_test/capture_prevention_flow_test.dart'
    as capture_prevention;
import '../integration_test/cleanup_transcript_use_case_flow_test.dart'
    as cleanup_transcript_use_case;
import '../integration_test/cloud_transcription_service_flow_test.dart'
    as cloud_transcription_service;
import '../integration_test/device_registration_launch_flow_test.dart'
    as device_registration_launch;
import '../integration_test/draft_retry_launch_flow_test.dart'
    as draft_retry_launch;
import '../integration_test/entry_detail_flow_test.dart' as entry_detail;
import '../integration_test/entry_list_flow_test.dart' as entry_list;
import '../integration_test/local_data_lifecycle_flow_test.dart'
    as local_data_lifecycle;
import '../integration_test/main_feedback_flow_test.dart' as main_feedback;
import '../integration_test/main_recording_controller_flow_test.dart'
    as main_recording_controller;
import '../integration_test/main_screen_display_awake_flow_test.dart'
    as main_screen_display_awake;
import '../integration_test/main_screen_permission_flow_test.dart'
    as main_screen_permission;
import '../integration_test/orientation_lock_flow_test.dart'
    as orientation_lock;

// Native suite runner; kept outside integration_test to avoid duplicate discovery.
// Main-screen pulse and audio-service suites run separately to isolate their
// timing/native-recording diagnostics. Named groups prefix test failures with
// the suite name; Flutter's integration driver reports failures and a nonzero
// exit status. No errors are caught or converted into successful results here.
// Diagnose a failing group by rerunning its imported file with the selected SDK:
// flutter drive --no-pub --driver=test_driver/integration_test.dart \
//   --target=integration_test/<suite>_flow_test.dart -d <emulator-id>
// Initialize the shared binding before registering groups so completion is
// reported for the entire inventory rather than at the first group's teardown.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('app_lock', app_lock.main);
  group('backend_api_client', backend_api_client.main);
  group('bootstrap_retry', bootstrap_retry.main);
  group('branding_surfaces', branding_surfaces.main);
  group('capture_prevention', capture_prevention.main);
  group('cleanup_transcript_use_case', cleanup_transcript_use_case.main);
  group('cloud_transcription_service', cloud_transcription_service.main);
  group('device_registration_launch', device_registration_launch.main);
  group('draft_retry_launch', draft_retry_launch.main);
  group('entry_detail', entry_detail.main);
  group('entry_list', entry_list.main);
  group('local_data_lifecycle', local_data_lifecycle.main);
  group('main_feedback', main_feedback.main);
  group('main_recording_controller', main_recording_controller.main);
  group('main_screen_display_awake', main_screen_display_awake.main);
  group('main_screen_permission', main_screen_permission.main);
  group('orientation_lock', orientation_lock.main);
}
