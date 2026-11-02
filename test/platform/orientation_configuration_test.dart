import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android main activity requests sensor-based portrait orientation',
    () async {
      final manifest = File('android/app/src/main/AndroidManifest.xml');
      final contents = await manifest.readAsString();
      final activityMatch = RegExp(
        r'<activity\b([\s\S]*?)>',
      ).firstMatch(contents);

      expect(
        activityMatch,
        isNotNull,
        reason: 'The Android manifest must declare MainActivity.',
      );
      final activity = activityMatch!.group(1)!;
      expect(
        activity,
        contains('android:name=".MainActivity"'),
        reason: 'The orientation policy must apply to Flutter MainActivity.',
      );
      // sensorPortrait keeps the activity in portrait orientations while
      // allowing reverse portrait where the device supports it.
      expect(
        activity,
        contains('android:screenOrientation="sensorPortrait"'),
        reason:
            'MainActivity must request sensor-based portrait orientation so '
            'landscape is excluded.',
      );
      expect(
        activity,
        isNot(contains('android:screenOrientation="landscape"')),
        reason: 'MainActivity must not request a landscape orientation.',
      );
    },
  );

  test('iOS orientation allowlists contain portrait values only', () async {
    final infoPlist = File('ios/Runner/Info.plist');
    final contents = await infoPlist.readAsString();

    final iphoneOrientations = _arrayForKey(
      contents,
      'UISupportedInterfaceOrientations',
    );
    final ipadOrientations = _arrayForKey(
      contents,
      'UISupportedInterfaceOrientations~ipad',
    );

    expect(
      iphoneOrientations,
      contains('UIInterfaceOrientationPortrait'),
      reason: 'The iPhone orientation allowlist must retain portrait.',
    );
    expect(
      ipadOrientations,
      contains('UIInterfaceOrientationPortrait'),
      reason: 'The iPad orientation allowlist must retain portrait.',
    );
    expect(
      ipadOrientations,
      contains('UIInterfaceOrientationPortraitUpsideDown'),
      reason: 'The iPad allowlist must retain reverse portrait support.',
    );
    expect(
      contents,
      isNot(contains('UIInterfaceOrientationLandscape')),
      reason: 'Neither iOS orientation allowlist may advertise landscape.',
    );
  });
}

String _arrayForKey(String contents, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<array>([\\s\\S]*?)</array>',
  ).firstMatch(contents);

  expect(
    match,
    isNotNull,
    reason: 'Missing orientation array for $key in ios/Runner/Info.plist.',
  );
  return match!.group(1)!;
}
