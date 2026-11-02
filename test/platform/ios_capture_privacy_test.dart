import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const sceneDelegatePath = 'ios/Runner/SceneDelegate.swift';

  // These source tests pin the required native hooks and privacy-cover
  // contracts. Runtime simulator evidence remains the stronger validation.
  test('iOS scene observes screen-capture changes', () {
    final contents = File(sceneDelegatePath).readAsStringSync();

    expect(contents, contains('UIScreen.capturedDidChangeNotification'));
    expect(contents, contains('UIScreen.main.isCaptured'));
    expect(contents, contains('updatePrivacyCoverVisibility()'));
  });

  test('iOS scene protects app-switcher snapshots', () {
    final contents = File(sceneDelegatePath).readAsStringSync();

    expect(contents, contains('sceneWillResignActive'));
    expect(contents, contains('sceneDidEnterBackground'));
    expect(contents, contains('sceneDidBecomeActive'));
    expect(contents, contains('isSceneSnapshotProtected = true'));
    expect(contents, contains('isSceneSnapshotProtected = false'));
  });

  test('iOS scene removes capture observer during teardown', () {
    final contents = File(sceneDelegatePath).readAsStringSync();

    expect(contents, contains('sceneDidDisconnect'));
    expect(contents, contains('removeObserver'));
    expect(contents, contains('captureObserver'));
  });

  test('iOS scene uses generic privacy-cover copy and accessibility state', () {
    final contents = File(sceneDelegatePath).readAsStringSync();

    expect(contents, contains('private let privacyCoverText = "Private"'));
    expect(contents, contains('accessibilityElementsHidden = true'));
    expect(contents, isNot(contains('FlutterLogo')));
    expect(contents, isNot(contains('Flutter logo')));
    expect(
      contents,
      contains('isAccessibilityElement = shouldShowPrivacyCover'),
    );
  });
}
