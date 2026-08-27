import 'package:flutter/material.dart';

import '../data/app_store.dart';

class NexusMotion {
  NexusMotion._();

  static const fast = Duration(milliseconds: 180);
  static const med = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 420);
  static const page = Duration(milliseconds: 280);
  static const curve = Curves.easeOutCubic;
  static const pop = Curves.easeOutCubic;

  static bool get inWidgetTest {
    return WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
  }

  static Duration duration(BuildContext context, Duration value) {
    try {
      if (AppScope.of(context).settings.reduceMotion) return Duration.zero;
    } catch (_) {}
    return value;
  }
}

class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: NexusMotion.fast,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class NexusPageTransitionsBuilder extends PageTransitionsBuilder {
  const NexusPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduce = NexusMotion.duration(context, const Duration(milliseconds: 1)) == Duration.zero;
    if (reduce) return child;
    final curved = CurvedAnimation(parent: animation, curve: NexusMotion.curve);
    return FadeTransition(opacity: curved, child: child);
  }
}
