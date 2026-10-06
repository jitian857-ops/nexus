import 'package:flutter/material.dart';

import '../app/theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.glowColor,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? glowColor;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(NexusColors.cardRadius);
    final light = NexusColors.isLight;
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NexusColors.cardTop,
              NexusColors.card,
            ],
          ),
          border: Border.all(color: borderColor ?? NexusColors.hairline),
          boxShadow: [
            BoxShadow(
              color: light
                  ? Colors.black.withValues(alpha: 0.04)
                  : (glowColor ?? Colors.black).withValues(alpha: glowColor == null ? 0.22 : 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SizedBox(
          height: height,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
