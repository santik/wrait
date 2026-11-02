import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot:
        (
          String screenshotName,
          List<int> screenshotBytes, [
          Map<String, Object?>? _,
        ]) async {
          final output = File(
            'specs/045-feedback-form-submit/evidence/$screenshotName.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(screenshotBytes, flush: true);
          return true;
        },
  );
}
