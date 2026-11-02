import 'dart:math' as math;

import 'package:flutter/material.dart';

class CountdownRing extends StatelessWidget {
  const CountdownRing({
    required this.size,
    required this.progress,
    required this.color,
    required this.strokeWidth,
    super.key,
  });

  final double size;
  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _CountdownRingPainter(
        progress: progress,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  const _CountdownRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final backgroundPaint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final foregroundPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * clampedProgress,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter other) {
    return other.progress != progress ||
        other.color != color ||
        other.strokeWidth != strokeWidth;
  }
}
