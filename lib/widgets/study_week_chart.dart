import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/format.dart';

class StudyWeekChart extends StatelessWidget {
  const StudyWeekChart({
    super.key,
    this.dayHours,
    this.stacks,
    this.colors,
  });

  final List<double>? dayHours;
  final List<List<double>>? stacks;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StudyWeekChartPainter(
        dayHours: dayHours,
        stacks: stacks,
        colors: colors ?? [NexusColors.cyan],
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _StudyWeekChartPainter extends CustomPainter {
  _StudyWeekChartPainter({
    required this.dayHours,
    required this.stacks,
    required this.colors,
  });

  final List<double>? dayHours;
  final List<List<double>>? stacks;
  final List<Color> colors;

  List<double> get _totals {
    if (stacks != null && stacks!.isNotEmpty) {
      return [for (final day in stacks!) day.fold<double>(0, (a, b) => a + b)];
    }
    final hours = dayHours ?? const <double>[];
    if (hours.isEmpty) return List<double>.filled(7, 0);
    return hours;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final totals = _totals;
    if (totals.isEmpty) return;
    final dataMax = totals.fold<double>(0, (a, b) => a > b ? a : b);
    final axis = niceStudyAxis(dataMax);
    const labelWidth = 34.0;
    final chart = Rect.fromLTWH(labelWidth, 4, size.width - labelWidth, size.height - 8);

    final gridPaint = Paint()
      ..color = NexusColors.textMuted.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      color: NexusColors.textMuted.withValues(alpha: 0.9),
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );

    for (final tick in axis.ticks) {
      final y = chart.bottom - chart.height * (tick / axis.max);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final text = _tickLabel(tick);
      final painter = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: labelWidth);
      painter.paint(canvas, Offset(0, y - painter.height / 2));
    }

    final slot = chart.width / totals.length;
    final barWidth = slot * 0.48;
    if (stacks != null && stacks!.isNotEmpty) {
      for (var i = 0; i < stacks!.length; i++) {
        final x = chart.left + slot * i + (slot - barWidth) / 2;
        var y = chart.bottom;
        for (var s = 0; s < stacks![i].length; s++) {
          final hours = stacks![i][s];
          if (hours <= 0) continue;
          final h = chart.height * (hours / axis.max);
          y -= h;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, h), const Radius.circular(3)),
            Paint()..color = colors[s % colors.length],
          );
        }
      }
      return;
    }

    final barPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [NexusColors.cyan, NexusColors.purple],
      ).createShader(chart);
    for (var i = 0; i < totals.length; i++) {
      final hours = totals[i];
      if (hours <= 0) continue;
      final h = chart.height * (hours / axis.max);
      final x = chart.left + slot * i + (slot - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, chart.bottom - h, barWidth, h),
          const Radius.circular(4),
        ),
        barPaint,
      );
    }
  }

  String _tickLabel(double hours) {
    if (hours >= 1 || hours == hours.roundToDouble()) {
      return hours == hours.roundToDouble() ? '${hours.toInt()}h' : '${hours.toStringAsFixed(1)}h';
    }
    return '${hours.toStringAsFixed(2)}h';
  }

  @override
  bool shouldRepaint(covariant _StudyWeekChartPainter oldDelegate) {
    return oldDelegate.dayHours != dayHours ||
        oldDelegate.stacks != stacks ||
        oldDelegate.colors != colors;
  }
}
