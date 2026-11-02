import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android main manifest includes production internet permission',
    () async {
      final mainManifest = File('android/app/src/main/AndroidManifest.xml');
      final debugManifest = File('android/app/src/debug/AndroidManifest.xml');
      final profileManifest = File(
        'android/app/src/profile/AndroidManifest.xml',
      );

      final mainContents = await mainManifest.readAsString();
      final debugContents = await debugManifest.readAsString();
      final profileContents = await profileManifest.readAsString();

      expect(
        mainContents,
        contains('android.permission.INTERNET'),
        reason: 'Release and production app builds need backend access.',
      );
      expect(
        debugContents,
        isNot(contains('android.permission.INTERNET')),
        reason: 'Keep the shared permission source in the main manifest.',
      );
      expect(
        profileContents,
        isNot(contains('android.permission.INTERNET')),
        reason: 'Keep the shared permission source in the main manifest.',
      );
    },
  );

  test('Android manifest disables app backup restore', () async {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    final contents = await manifest.readAsString();

    expect(contents, contains('android:allowBackup="false"'));
    expect(contents, isNot(contains('android:allowBackup="true"')));
  });

  test(
    'Android activity does not resize the Flutter window for the keyboard',
    () async {
      final manifest = File('android/app/src/main/AndroidManifest.xml');
      final contents = await manifest.readAsString();

      expect(contents, contains('android:windowSoftInputMode="adjustNothing"'));
      expect(
        contents,
        isNot(contains('android:windowSoftInputMode="adjustResize"')),
      );
    },
  );
}
