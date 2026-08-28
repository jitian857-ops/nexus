import 'package:flutter/material.dart';

import '../app/theme.dart';

class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    if (NexusColors.isLight) return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.85, -0.9),
            radius: 1.2,
            colors: [
              NexusColors.cyan.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.95, 0.85),
              radius: 1.05,
              colors: [
                NexusColors.purple.withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
