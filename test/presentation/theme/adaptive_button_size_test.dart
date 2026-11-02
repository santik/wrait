import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/presentation/theme/adaptive_button_size.dart';

void main() {
  group('AdaptiveButtonSize', () {
    test('uses the approved ratio for a typical handset width', () {
      expect(AdaptiveButtonSize.forWidth(393), closeTo(220.08, 0.001));
    });

    test('clamps to the minimum for narrow widths', () {
      expect(AdaptiveButtonSize.forWidth(120), 160);
    });

    test('clamps to the maximum for wide widths', () {
      expect(AdaptiveButtonSize.forWidth(900), 280);
    });

    test('clamps zero and negative widths to the minimum', () {
      expect(AdaptiveButtonSize.forWidth(0), 160);
      expect(AdaptiveButtonSize.forWidth(-50), 160);
    });

    test('falls back to the minimum for non-finite widths', () {
      expect(AdaptiveButtonSize.forWidth(double.nan), 160);
      expect(AdaptiveButtonSize.forWidth(double.infinity), 160);
      expect(AdaptiveButtonSize.forWidth(double.negativeInfinity), 160);
    });
  });
}
