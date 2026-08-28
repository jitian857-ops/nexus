import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/theme.dart';

class NexusLogo extends StatelessWidget {
  const NexusLogo({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.24;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: NexusColors.isLight
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: size * 0.18,
                    offset: Offset(0, size * 0.06),
                  ),
                ]
              : [
                  BoxShadow(
                    color: NexusColors.cyan.withValues(alpha: 0.22),
                    blurRadius: size * 0.42,
                    offset: Offset(0, size * 0.04),
                  ),
                  BoxShadow(
                    color: NexusColors.purple.withValues(alpha: 0.4),
                    blurRadius: size * 0.55,
                    offset: Offset(0, size * 0.12),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.asset(
            'assets/branding/nexus_mark.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => CustomPaint(
              size: Size.square(size),
              painter: NexusMarkPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

class NexusMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * 0.24;
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(size.width, size.height),
          const [Color(0xFF0B1420), Color(0xFF05080E), Color(0xFF14081C)],
        ),
    );

    final highlight = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.15, 0),
        Offset(size.width * 0.85, size.height * 0.4),
        [
          Colors.white.withValues(alpha: 0.16),
          Colors.transparent,
        ],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(r)),
      highlight,
    );

    final inset = size.width * 0.18;
    final thick = size.width * 0.17;
    final top = size.height * 0.2;
    final bottom = size.height * 0.82;
    final left = inset;
    final right = size.width - inset;

    final nShader = ui.Gradient.linear(
      Offset(size.width * 0.3, top),
      Offset(size.width * 0.7, bottom),
      const [
        Color(0xFF5CE1FF),
        Color(0xFF3DA9FC),
        Color(0xFF7B5CFF),
        Color(0xFFC45CFF),
      ],
      const [0, 0.35, 0.7, 1],
    );

    final paint = Paint()
      ..shader = nShader
      ..style = PaintingStyle.fill;

    final leftBar = Path()
      ..addRRect(
        RRect.fromLTRBR(left, top, left + thick, bottom, Radius.circular(thick * 0.28)),
      );
    canvas.drawPath(leftBar, paint);

    final rightBar = Path()
      ..addRRect(
        RRect.fromLTRBR(right - thick, top, right, bottom, Radius.circular(thick * 0.28)),
      );
    canvas.drawPath(rightBar, paint);

    final diagonal = Path()
      ..moveTo(left + thick * 0.15, top + thick * 0.2)
      ..lineTo(left + thick * 1.05, top + thick * 0.05)
      ..lineTo(right - thick * 0.12, bottom - thick * 0.15)
      ..lineTo(right - thick * 1.05, bottom - thick * 0.02)
      ..close();
    canvas.drawPath(diagonal, paint);

    final shine = Paint()
      ..shader = ui.Gradient.linear(
        Offset(left, top),
        Offset(right, top + size.height * 0.25),
        [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
      );
    canvas.saveLayer(rect, Paint());
    canvas.drawPath(leftBar, shine);
    canvas.drawPath(diagonal, shine);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
