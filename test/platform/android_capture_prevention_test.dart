import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const mainActivityPath =
      'android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt';

  // These source tests intentionally guard specific native contracts that are
  // hard to exercise directly from Flutter tests: ordering before first render
  // and the explicit secure-flag reassertions we rely on after startup.
  test('Android enables secure window before Flutter content renders', () {
    final contents = File(mainActivityPath).readAsStringSync();

    final onCreateIndex = contents.indexOf('override fun onCreate');
    final firstProtectionCallIndex = contents.indexOf(
      'enableCaptureProtection()',
      onCreateIndex,
    );
    final superOnCreateIndex = contents.indexOf(
      'super.onCreate(savedInstanceState)',
    );
    final secureFlagIndex = contents.indexOf(
      'window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)',
    );

    expect(onCreateIndex, isNot(-1));
    expect(firstProtectionCallIndex, isNot(-1));
    expect(secureFlagIndex, isNot(-1));
    expect(superOnCreateIndex, isNot(-1));
    expect(firstProtectionCallIndex, greaterThan(onCreateIndex));
    expect(
      firstProtectionCallIndex,
      lessThan(superOnCreateIndex),
      reason:
          'FLAG_SECURE must be applied before Flutter attaches and renders.',
    );
  });

  test('Android reapplies secure window after Flutter activity setup', () {
    final contents = File(mainActivityPath).readAsStringSync();

    final superOnCreateIndex = contents.indexOf(
      'super.onCreate(savedInstanceState)',
    );
    final postSuperProtectionCallIndex = contents.indexOf(
      'enableCaptureProtection()',
      superOnCreateIndex,
    );

    expect(superOnCreateIndex, isNot(-1));
    expect(postSuperProtectionCallIndex, greaterThan(superOnCreateIndex));
  });

  test('Android secure window is not limited to debug automation mode', () {
    final contents = File(mainActivityPath).readAsStringSync();

    final onCreateIndex = contents.indexOf('override fun onCreate');
    final firstProtectionCallIndex = contents.indexOf(
      'enableCaptureProtection()',
      onCreateIndex,
    );
    final automationCheckIndex = contents.indexOf(
      'if (shouldEnableAutomationLockscreenMode())',
    );

    expect(firstProtectionCallIndex, isNot(-1));
    expect(automationCheckIndex, isNot(-1));
    expect(
      firstProtectionCallIndex,
      lessThan(automationCheckIndex),
      reason: 'Capture prevention must be always-on, not only for automation.',
    );
  });
}
