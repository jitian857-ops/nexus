import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 96,
    this.stroke = 8,
    this.colors,
    this.child,
    this.animate = true,
  });

  final double progress;
  final double size;
  final double stroke;
  final List<Color>? colors;
  final Widget? child;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final target = progress.clamp(0.0, 1.0);
    final ringColors = colors ?? [NexusColors.cyan, NexusColors.purple, NexusColors.cyan];
    Widget ring(double value) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(progress: value, stroke: stroke, colors: ringColors),
          child: Center(child: child),
        ),
      );
    }

    if (!animate) return ring(target);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: Duration(milliseconds: target >= 0.999 ? 720 : 480),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => ring(value),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.stroke, required this.colors});

  final double progress;
  final double stroke;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - stroke / 2;

    final track = Paint()
      ..color = NexusColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: colors,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, progress * math.pi * 2, false, sweep);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.stroke != stroke ||
        oldDelegate.colors != colors;
  }
}
