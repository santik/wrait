import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class PulseRing extends StatefulWidget {
  const PulseRing({
    required this.startDiameter,
    required this.endDiameter,
    required this.color,
    super.key,
  });

  final double startDiameter;
  final double endDiameter;
  final Color color;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: WraitAnimationTokens.pulse,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        final currentDiameter = lerpDouble(
          widget.startDiameter,
          widget.endDiameter < widget.startDiameter
              ? widget.startDiameter
              : widget.endDiameter,
          value,
        )!;
        final opacity = WraitButtonTokens.pulseAlphaStart * (1 - value);
        final strokeWidth = lerpDouble(
          WraitButtonTokens.pulseStrokeWidthStart,
          WraitButtonTokens.pulseStrokeWidthEnd,
          value,
        )!;
        final blurRadius = lerpDouble(
          WraitButtonTokens.pulseGlowBlurStart,
          WraitButtonTokens.pulseGlowBlurEnd,
          value,
        )!;
        final spreadRadius = lerpDouble(
          WraitButtonTokens.pulseGlowSpreadStart,
          WraitButtonTokens.pulseGlowSpreadEnd,
          value,
        )!;
        final visibleOpacity = opacity.clamp(0, 1).toDouble();
        final ringColor = widget.color.withValues(
          alpha: widget.color.a * visibleOpacity,
        );
        final glowColor = widget.color.withValues(alpha: visibleOpacity * 0.45);

        return SizedBox(
          width: currentDiameter + strokeWidth,
          height: currentDiameter + strokeWidth,
          child: CustomPaint(
            painter: _PulseRingPainter(
              baseDiameter: currentDiameter,
              strokeWidth: strokeWidth,
              ringColor: ringColor,
              glowColor: glowColor,
              blurRadius: blurRadius,
              spreadRadius: spreadRadius,
            ),
          ),
        );
      },
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  const _PulseRingPainter({
    required this.baseDiameter,
    required this.strokeWidth,
    required this.ringColor,
    required this.glowColor,
    required this.blurRadius,
    required this.spreadRadius,
  });

  final double baseDiameter;
  final double strokeWidth;
  final Color ringColor;
  final Color glowColor;
  final double blurRadius;
  final double spreadRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (baseDiameter / 2) + (strokeWidth / 2);

    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + (spreadRadius * 2)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius / 2);

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, glowPaint);
    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _PulseRingPainter oldDelegate) {
    return oldDelegate.baseDiameter != baseDiameter ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.blurRadius != blurRadius ||
        oldDelegate.spreadRadius != spreadRadius;
  }
}
