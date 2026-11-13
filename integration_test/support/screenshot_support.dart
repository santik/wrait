import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Prepares the Flutter surface so `binding.takeScreenshot` can capture it.
///
/// `convertFlutterSurfaceToImage()` is implemented only on Android and throws
/// on the iOS Simulator, so it is guarded here in one place (shared by the
/// screenshot-taking flow tests) rather than duplicated per test file.
Future<void> prepareScreenshots(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
  }
}
