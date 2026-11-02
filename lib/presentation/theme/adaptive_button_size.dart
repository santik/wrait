import 'design_tokens.dart';

abstract final class AdaptiveButtonSize {
  static double forWidth(double widthDp) {
    final resolvedWidth = widthDp.isFinite
        ? widthDp
        : WraitButtonTokens.sizeMin;
    final computedSize = resolvedWidth * WraitButtonTokens.screenWidthRatio;

    return computedSize
        .clamp(WraitButtonTokens.sizeMin, WraitButtonTokens.sizeMax)
        .toDouble();
  }
}
