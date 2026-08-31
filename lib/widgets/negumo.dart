import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ネグモ。3Dシートの雰囲気を、動くマスコットとして描く。
class NegumoMascot extends StatelessWidget {
  const NegumoMascot({
    super.key,
    required this.t,
    this.size = 168,
    this.pose = NegumoPose.float,
  });

  final double t;
  final double size;
  final NegumoPose pose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.12,
      child: CustomPaint(
        painter: _NegumoPainter(t: t, pose: pose),
      ),
    );
  }
}

enum NegumoPose { float, wave, hop, point }

class _NegumoPainter extends CustomPainter {
  _NegumoPainter({required this.t, required this.pose});

  final double t;
  final NegumoPose pose;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bob = math.sin(t * math.pi * 2) * size.height * 0.028;
    final squash = 1 + math.sin(t * math.pi * 2) * 0.03;
    canvas.translate(cx, size.height * 0.62 + bob);
    canvas.scale(1 + (pose == NegumoPose.hop ? math.sin(t * math.pi) * 0.06 : 0), squash);

    _bubbles(canvas, size);
    _antennas(canvas, size);
    _body(canvas, size);
    _face(canvas, size);
    _arms(canvas, size);
  }

  void _body(Canvas canvas, Size size) {
    final w = size.width * 0.42;
    final h = size.height * 0.34;
    final body = Path()
      ..addOval(Rect.fromCenter(center: Offset.zero, width: w * 2, height: h * 2));
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xF5F7F1E8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0x55C8BFAF),
    );

    final coreR = size.width * 0.09;
    canvas.drawCircle(Offset(0, size.height * 0.02), coreR * 1.35, Paint()..color = const Color(0x333DA9FC));
    canvas.drawCircle(Offset(0, size.height * 0.02), coreR, Paint()..color = const Color(0xFF3DA9FC));
    _star(canvas, Offset(0, size.height * 0.02), coreR * 0.55, Colors.white);
  }

  void _face(Canvas canvas, Size size) {
    final blink = (t % 1) > 0.92 && (t % 1) < 0.97;
    final eyeH = blink ? 1.4 : size.width * 0.028;
    final eyeW = size.width * 0.028;
    canvas.drawOval(Rect.fromCenter(center: Offset(-size.width * 0.07, -size.height * 0.08), width: eyeW, height: eyeH), Paint()..color = const Color(0xFF1A1A1A));
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.07, -size.height * 0.08), width: eyeW, height: eyeH), Paint()..color = const Color(0xFF1A1A1A));
    canvas.drawCircle(Offset(-size.width * 0.11, -size.height * 0.04), size.width * 0.018, Paint()..color = const Color(0x88FF8A9A));
    canvas.drawCircle(Offset(size.width * 0.11, -size.height * 0.04), size.width * 0.018, Paint()..color = const Color(0x88FF8A9A));
    final mouth = Path()
      ..moveTo(-size.width * 0.03, -size.height * 0.02)
      ..quadraticBezierTo(0, size.height * 0.01, size.width * 0.03, -size.height * 0.02);
    canvas.drawPath(
      mouth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF333333),
    );
  }

  void _antennas(Canvas canvas, Size size) {
    final sway = math.sin(t * math.pi * 2) * 10;
    _antenna(canvas, size, left: true, sway: sway);
    _antenna(canvas, size, left: false, sway: -sway);
  }

  void _antenna(Canvas canvas, Size size, {required bool left, required double sway}) {
    final start = Offset(left ? -size.width * 0.08 : size.width * 0.08, -size.height * 0.16);
    final mid = Offset(left ? -size.width * 0.22 + sway * 0.4 : size.width * 0.22 + sway * 0.4, -size.height * 0.38);
    final end = Offset(left ? -size.width * 0.28 + sway : size.width * 0.28 + sway, -size.height * 0.48);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.028
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xCCF7F1E8),
    );
    final node = end;
    if (left) {
      canvas.drawCircle(node, size.width * 0.055, Paint()..color = Colors.white);
      canvas.drawCircle(node, size.width * 0.028, Paint()..color = const Color(0xFF3DA9FC));
    } else {
      final r = size.width * 0.048;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: node, width: r * 2, height: r * 2), const Radius.circular(5)),
        Paint()..color = Colors.white,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: node, width: r, height: r), const Radius.circular(3)),
        Paint()..color = const Color(0xFF3DA9FC),
      );
    }
    canvas.drawCircle(node + Offset(left ? -size.width * 0.04 : size.width * 0.04, 0), 3.2, Paint()..color = const Color(0xFFFF8A4A));
  }

  void _arms(Canvas canvas, Size size) {
    final wave = pose == NegumoPose.wave || pose == NegumoPose.float ? math.sin(t * math.pi * 2) * 16 : 0.0;
    final point = pose == NegumoPose.point ? -28.0 : 0.0;
    _arm(canvas, size, left: true, lift: wave);
    _arm(canvas, size, left: false, lift: point);
  }

  void _arm(Canvas canvas, Size size, {required bool left, required double lift}) {
    final start = Offset(left ? -size.width * 0.28 : size.width * 0.28, size.height * 0.02);
    final end = Offset(left ? -size.width * 0.38 : size.width * 0.4, -size.height * 0.02 - lift);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..strokeWidth = size.width * 0.055
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xF5F7F1E8),
    );
  }

  void _bubbles(Canvas canvas, Size size) {
    for (var i = 0; i < 5; i++) {
      final a = (t + i * 0.18) % 1;
      final x = math.sin(i * 1.7) * size.width * 0.34;
      final y = size.height * 0.22 - a * size.height * 0.42;
      canvas.drawCircle(
        Offset(x, y),
        3 + (i % 3).toDouble(),
        Paint()..color = const Color(0x55FFFFFF),
      );
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 4 * math.pi / 5;
      final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NegumoPainter oldDelegate) => oldDelegate.t != t || oldDelegate.pose != pose;
}

class NegumoSpeech extends StatelessWidget {
  const NegumoSpeech({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E1D8)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2C2A28),
        ),
      ),
    );
  }
}
