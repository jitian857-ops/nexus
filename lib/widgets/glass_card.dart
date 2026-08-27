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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: (glowColor ?? (light ? Colors.black : NexusColors.cyan)).withValues(
              alpha: glowColor == null ? (light ? 0.06 : 0.05) : 0.16,
            ),
            blurRadius: glowColor == null ? 16 : 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: borderColor ?? NexusColors.hairline,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        NexusColors.cardTop,
                        NexusColors.card,
                        NexusColors.surface,
                      ],
                      stops: const [0, 0.5, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 18,
                right: 18,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          NexusColors.hairline,
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: const SizedBox(height: 1.2),
                  ),
                ),
              ),
              if (glowColor != null)
                Positioned(
                  top: -46,
                  left: -36,
                  child: IgnorePointer(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            glowColor!.withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}
