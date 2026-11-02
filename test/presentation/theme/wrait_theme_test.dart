import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/presentation/shell/shell_placeholder_screen.dart';
import 'package:wrait/presentation/theme/wrait_colors.dart';
import 'package:wrait/presentation/theme/wrait_theme.dart';

void main() {
  group('Wrait themes', () {
    test('exposes the planned light theme surface and text roles', () {
      expect(wraitLightTheme.colorScheme.brightness, Brightness.light);
      expect(wraitLightTheme.scaffoldBackgroundColor, wraitLightBackground);
      expect(wraitLightTheme.textTheme.bodyLarge?.fontSize, 16);
      expect(wraitLightTheme.textTheme.labelLarge?.fontSize, 13);
      expect(wraitLightTheme.textTheme.labelSmall?.fontSize, 11);
      expect(wraitLightTheme.textTheme.bodySmall?.fontSize, 10);
      expect(wraitLightTheme.textTheme.titleMedium?.fontSize, 20);
      expect(
        wraitLightTheme.extension<WraitSemanticColors>()?.warning,
        wraitSemanticWarning,
      );
      expect(wraitLightTheme.colorScheme.primaryContainer, wraitWarm300);
      expect(wraitLightTheme.colorScheme.outline, wraitCharcoalLight);
    });

    test('exposes the planned dark theme surface and text roles', () {
      expect(wraitDarkTheme.colorScheme.brightness, Brightness.dark);
      expect(wraitDarkTheme.scaffoldBackgroundColor, wraitDarkBackground);
      expect(wraitDarkTheme.textTheme.bodyLarge?.fontSize, 16);
      expect(wraitDarkTheme.textTheme.labelLarge?.fontSize, 13);
      expect(wraitDarkTheme.textTheme.labelSmall?.fontSize, 11);
      expect(wraitDarkTheme.textTheme.bodySmall?.fontSize, 10);
      expect(wraitDarkTheme.textTheme.titleMedium?.fontSize, 20);
      expect(
        wraitDarkTheme.extension<WraitSemanticColors>()?.infoContainer,
        wraitDarkInfoContainer,
      );
      expect(wraitDarkTheme.colorScheme.primaryContainer, wraitDark300);
      expect(wraitDarkTheme.colorScheme.outline, wraitCreamLight);
    });

    testWidgets('renders the shell with the dark theme surface colors', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: wraitLightTheme,
          darkTheme: wraitDarkTheme,
          themeMode: ThemeMode.dark,
          home: const ShellPlaceholderScreen(
            title: 'Capture',
            description: 'Dark mode preview',
          ),
        ),
      );

      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      final text = tester.widget<Text>(find.text('Capture'));

      expect(scaffold.backgroundColor, isNull);
      expect(text.style?.color, wraitCreamText);
      expect(find.text('Dark mode preview'), findsOneWidget);
    });
  });
}
