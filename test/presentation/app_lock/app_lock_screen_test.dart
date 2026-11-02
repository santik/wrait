import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/presentation/app_lock/app_lock_controller.dart';
import 'package:wrait/presentation/app_lock/app_lock_screen.dart';

import '../../test_doubles/l10n_test_helper.dart';

void main() {
  testWidgets('locked screen shows Wrait copy and no Flutter logo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: AppLockScreen(
          state: const AppLockState.locked(),
          onUnlock: () {},
          onOpenSettings: () {},
          onContinueWithoutLock: () {},
        ),
      ),
    );

    expect(find.text('wrait is locked'), findsOneWidget);
    expect(find.text('Unlock Wrait to continue.'), findsOneWidget);
    expect(find.byType(FlutterLogo), findsNothing);
  });

  testWidgets('no-security state stays neutral and exposes settings actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: AppLockScreen(
          state: const AppLockState.locked(status: AppLockStatus.noSecurity),
          onUnlock: () {},
          onOpenSettings: () {},
          onContinueWithoutLock: () {},
        ),
      ),
    );

    expect(
      find.text('set up device security to protect Wrait'),
      findsOneWidget,
    );
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('Continue without lock'), findsOneWidget);
    expect(find.byType(FlutterLogo), findsNothing);
  });
}
