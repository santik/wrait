import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android adaptive launcher resources exist for release and dev builds',
    () {
      const resourcePaths = <String>{
        'android/app/src/main/res/mipmap-anydpi/ic_launcher.xml',
        'android/app/src/main/res/mipmap-anydpi/ic_launcher_round.xml',
        'android/app/src/main/res/drawable/ic_launcher_background.xml',
        'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
        'android/app/src/debug/res/drawable/ic_launcher_background.xml',
        'android/app/src/debug/res/drawable/ic_launcher_foreground.xml',
        'android/app/src/profile/res/drawable/ic_launcher_background.xml',
        'android/app/src/profile/res/drawable/ic_launcher_foreground.xml',
      };

      for (final path in resourcePaths) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: path);
        expect(file.readAsStringSync(), isNotEmpty, reason: path);
      }
    },
  );

  test(
    'Android adaptive icon XML points to the expected background and wordmark resources',
    () {
      const iconPaths = <String>[
        'android/app/src/main/res/mipmap-anydpi/ic_launcher.xml',
        'android/app/src/main/res/mipmap-anydpi/ic_launcher_round.xml',
      ];

      for (final path in iconPaths) {
        final contents = File(path).readAsStringSync();
        expect(
          contents,
          contains(
            '<background android:drawable="@drawable/ic_launcher_background" />',
          ),
          reason: path,
        );
        expect(
          contents,
          contains(
            '<foreground android:drawable="@drawable/ic_launcher_foreground" />',
          ),
          reason: path,
        );
        expect(
          contents,
          contains(
            '<monochrome android:drawable="@drawable/ic_launcher_foreground" />',
          ),
          reason: path,
        );
      }
    },
  );

  test(
    'Android release and dev wordmark drawables use the expected colors',
    () {
      final releaseBackground = File(
        'android/app/src/main/res/drawable/ic_launcher_background.xml',
      ).readAsStringSync();
      final releaseForeground = File(
        'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
      ).readAsStringSync();
      final debugBackground = File(
        'android/app/src/debug/res/drawable/ic_launcher_background.xml',
      ).readAsStringSync();
      final debugForeground = File(
        'android/app/src/debug/res/drawable/ic_launcher_foreground.xml',
      ).readAsStringSync();
      final profileBackground = File(
        'android/app/src/profile/res/drawable/ic_launcher_background.xml',
      ).readAsStringSync();
      final profileForeground = File(
        'android/app/src/profile/res/drawable/ic_launcher_foreground.xml',
      ).readAsStringSync();

      expect(releaseBackground, contains('android:fillColor="#E8E4DD"'));
      expect(releaseForeground, contains('android:fillColor="#1A1917"'));
      expect(debugBackground, contains('android:fillColor="#C62828"'));
      expect(debugForeground, contains('android:fillColor="#FFFFFF"'));
      expect(profileBackground, equals(debugBackground));
      expect(profileForeground, equals(debugForeground));
      expect(debugForeground, isNot(equals(releaseForeground)));
    },
  );

  test(
    'iOS release and debug app icon catalogs are wired to distinct build configurations',
    () {
      final pbxproj = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();

      expect(_buildConfigurationIconName(pbxproj, 'Debug'), 'AppIconDebug');
      expect(_buildConfigurationIconName(pbxproj, 'Profile'), 'AppIconDebug');
      expect(_buildConfigurationIconName(pbxproj, 'Release'), 'AppIcon');
    },
  );

  test('iOS release and debug icon assets exist at all expected sizes', () {
    const iconPaths = <String, int>{
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png':
          120,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png':
          120,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png':
          180,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png':
          152,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png':
          167,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png':
          1024,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-20x20@1x.png':
          20,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-20x20@2x.png':
          40,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-20x20@3x.png':
          60,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-29x29@1x.png':
          29,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-29x29@2x.png':
          58,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-29x29@3x.png':
          87,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-40x40@1x.png':
          40,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-40x40@2x.png':
          80,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-40x40@3x.png':
          120,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-60x60@2x.png':
          120,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-60x60@3x.png':
          180,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-76x76@1x.png':
          76,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-76x76@2x.png':
          152,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-83.5x83.5@2x.png':
          167,
      'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-1024x1024@1x.png':
          1024,
    };

    for (final entry in iconPaths.entries) {
      final bytes = File(entry.key).readAsBytesSync();
      final dimensions = _readPngDimensions(bytes);

      expect(dimensions.width, entry.value, reason: entry.key);
      expect(dimensions.height, entry.value, reason: entry.key);
      expect(bytes.length, greaterThan(500), reason: entry.key);
    }
  });

  test(
    'iOS launch images are populated and no longer use the 1x1 placeholder',
    () {
      const launchPaths = <String, int>{
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png': 720,
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png':
            1440,
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png':
            2160,
      };

      for (final entry in launchPaths.entries) {
        final bytes = File(entry.key).readAsBytesSync();
        final dimensions = _readPngDimensions(bytes);

        expect(dimensions.width, entry.value, reason: entry.key);
        expect(dimensions.height, entry.value, reason: entry.key);
        expect(bytes.length, greaterThan(1000), reason: entry.key);
      }
    },
  );

  test('iOS debug icon catalog declares the expected asset list', () {
    final contents =
        jsonDecode(
              File(
                'ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Contents.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    final images = (contents['images'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final actualEntries = images
        .map(
          (image) =>
              '${image['idiom']}|${image['size']}|${image['scale']}|${image['filename']}',
        )
        .toSet();

    const expectedEntries = <String>{
      'iphone|20x20|2x|Icon-App-20x20@2x.png',
      'iphone|20x20|3x|Icon-App-20x20@3x.png',
      'iphone|29x29|1x|Icon-App-29x29@1x.png',
      'iphone|29x29|2x|Icon-App-29x29@2x.png',
      'iphone|29x29|3x|Icon-App-29x29@3x.png',
      'iphone|40x40|2x|Icon-App-40x40@2x.png',
      'iphone|40x40|3x|Icon-App-40x40@3x.png',
      'iphone|60x60|2x|Icon-App-60x60@2x.png',
      'iphone|60x60|3x|Icon-App-60x60@3x.png',
      'ipad|20x20|1x|Icon-App-20x20@1x.png',
      'ipad|20x20|2x|Icon-App-20x20@2x.png',
      'ipad|29x29|1x|Icon-App-29x29@1x.png',
      'ipad|29x29|2x|Icon-App-29x29@2x.png',
      'ipad|40x40|1x|Icon-App-40x40@1x.png',
      'ipad|40x40|2x|Icon-App-40x40@2x.png',
      'ipad|76x76|1x|Icon-App-76x76@1x.png',
      'ipad|76x76|2x|Icon-App-76x76@2x.png',
      'ipad|83.5x83.5|2x|Icon-App-83.5x83.5@2x.png',
      'ios-marketing|1024x1024|1x|Icon-App-1024x1024@1x.png',
    };

    expect(actualEntries, expectedEntries);
  });
}

({int width, int height}) _readPngDimensions(List<int> bytes) {
  if (bytes.length < 24) {
    throw StateError('PNG file is too short to contain an IHDR chunk.');
  }

  final signature = bytes.sublist(0, 8);
  const expectedSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (!_listEquals(signature, expectedSignature)) {
    throw StateError('PNG signature is invalid.');
  }

  final data = Uint8List.fromList(bytes);
  final byteData = ByteData.sublistView(data);
  final ihdrLength = byteData.getUint32(8, Endian.big);
  final ihdrType = ascii.decode(bytes.sublist(12, 16));

  if (ihdrLength != 13 || ihdrType != 'IHDR') {
    throw StateError('PNG IHDR chunk is missing or malformed.');
  }

  final width = byteData.getUint32(16, Endian.big);
  final height = byteData.getUint32(20, Endian.big);
  return (width: width, height: height);
}

String _buildConfigurationIconName(String pbxproj, String configurationName) {
  final blockPattern = RegExp(r'\b[A-F0-9]+ /\* .*? \*/ = \{[\s\S]*?\n\t\t};');

  for (final match in blockPattern.allMatches(pbxproj)) {
    final block = match.group(0)!;
    if (!block.contains('name = $configurationName;')) {
      continue;
    }
    if (!block.contains('ASSETCATALOG_COMPILER_APPICON_NAME = ')) {
      continue;
    }

    final iconMatch = RegExp(
      r'ASSETCATALOG_COMPILER_APPICON_NAME = ([A-Za-z0-9]+);',
    ).firstMatch(block);
    if (iconMatch != null) {
      return iconMatch.group(1)!;
    }
  }

  throw StateError('Missing target build configuration for $configurationName');
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }

  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) {
      return false;
    }
  }

  return true;
}
