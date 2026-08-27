import 'package:flutter/material.dart';

import '../app/theme.dart';

class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final light = NexusColors.isLight;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.85, -0.9),
            radius: 1.2,
            colors: [
              NexusColors.cyan.withValues(alpha: light ? 0.10 : 0.16),
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
                NexusColors.purple.withValues(alpha: light ? 0.08 : 0.14),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
