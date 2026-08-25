import 'package:flutter/material.dart';

import '../../app/theme.dart';

class NegumoMascot extends StatelessWidget {
  const NegumoMascot({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 168,
      height: 168,
      child: CustomPaint(painter: _NegumoPainter()),
    );
  }
}

class _NegumoPainter extends CustomPainter {
  const _NegumoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + 8);
    final body = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFEAF4FF).withValues(alpha: 0.95),
          const Color(0xFF9AD7FF).withValues(alpha: 0.55),
          const Color(0xFF3BA7FF).withValues(alpha: 0.18),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: 70));

    canvas.drawOval(Rect.fromCenter(center: c, width: 118, height: 128), body);

    final antenna = Paint()
      ..color = const Color(0xFF7BE7FF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(c.translate(-22, -58), c.translate(-34, -78), antenna);
    canvas.drawLine(c.translate(22, -58), c.translate(36, -76), antenna);
    canvas.drawCircle(c.translate(-34, -78), 4, Paint()..color = NexusColors.cyan);
    canvas.drawCircle(c.translate(36, -76), 4, Paint()..color = NexusColors.cyan);

    canvas.drawOval(
      Rect.fromCenter(center: c.translate(-16, -10), width: 12, height: 18),
      Paint()..color = const Color(0xFF101418),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(16, -10), width: 12, height: 18),
      Paint()..color = const Color(0xFF101418),
    );
    canvas.drawCircle(c.translate(-22, 8), 8, Paint()..color = const Color(0xFFFF8AA0).withValues(alpha: 0.55));
    canvas.drawCircle(c.translate(22, 8), 8, Paint()..color = const Color(0xFFFF8AA0).withValues(alpha: 0.55));

    final starPaint = Paint()
      ..color = NexusColors.cyan
      ..style = PaintingStyle.fill;
    final starPath = Path()
      ..moveTo(c.dx, c.dy + 16)
      ..lineTo(c.dx + 11, c.dy + 28)
      ..lineTo(c.dx, c.dy + 40)
      ..lineTo(c.dx - 11, c.dy + 28)
      ..close();
    canvas.drawPath(starPath, starPaint);
    canvas.drawCircle(Offset(c.dx, c.dy + 28), 6, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
