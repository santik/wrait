import 'package:flutter/material.dart';

abstract final class WraitAnimationTokens {
  static const Duration fade = Duration(milliseconds: 300);
  // Keep the pulse slower than the countdown refresh so it reads as a broad
  // ambient sweep instead of a tight flicker at the button edge.
  static const Duration pulse = Duration(milliseconds: 2400);
  static const Duration buttonAlpha = Duration(milliseconds: 200);
  static const Duration buttonShake = Duration(milliseconds: 420);
  static const Duration countdownRefresh = Duration(milliseconds: 250);
  static const Duration deleteFade = Duration(milliseconds: 200);
  static const Duration swipeDeleteFling = Duration(milliseconds: 250);
}

abstract final class WraitSpacingTokens {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xxl = 48;
}

abstract final class WraitRadiusTokens {
  static const double small = 4;
  static const double card = 12;
}

abstract final class WraitGestureTokens {
  static const double swipeBackThreshold = 80;
  static const double swipeNavThreshold = 80;
  static const double swipeDeleteReveal = 80;
}

abstract final class WraitButtonTokens {
  static const double screenWidthRatio = 0.56;
  static const double sizeMin = 160;
  static const double sizeMax = 280;
  static const double pulseScaleMax = 1.6;
  static const double pulseViewportOverscan = 48;
  // These starting values keep the first frame legible around the button
  // before the ring expands out to the viewport edges.
  static const double pulseAlphaStart = 0.6;
  static const double pulseStrokeWidthStart = 6;
  static const double pulseStrokeWidthEnd = 2;
  static const double pulseGlowBlurStart = 20;
  static const double pulseGlowBlurEnd = 6;
  static const double pulseGlowSpreadStart = 3;
  static const double pulseGlowSpreadEnd = 0;
  static const double pulseDiameterMax = 2400;
  static const double alphaDisabled = 0.3;
  static const double alphaReduced = 0.5;
  static const double alphaFull = 1.0;
  static const double countdownStrokeWidth = 3;
  static const double countdownSizeOffset = 18;
  static const double shakeAmplitude = 10;
  static const double shakeOscillations = 5;
}

abstract final class WraitAppLockTokens {
  static const double scrimAlpha = 0.18;
}

abstract final class WraitStatusLineTokens {
  static const Duration clearDelay = Duration(milliseconds: 4000);
  static const double gapAbove = 12;
  static const double reservedHeight = 48;
}

abstract final class WraitQuotaLineTokens {
  static const double gapBelow = 16;
  static const double reservedHeight = 48;
}

abstract final class WraitStatsLineTokens {
  static const double gapAbove = 16;
  static const double reservedHeight = 48;
}

abstract final class WraitDesignTokens {
  static const EdgeInsets screenPadding = EdgeInsets.all(WraitSpacingTokens.lg);
  static const EdgeInsets sectionPadding = EdgeInsets.all(
    WraitSpacingTokens.md,
  );
}
