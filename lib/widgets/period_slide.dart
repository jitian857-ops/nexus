import 'package:flutter/material.dart';

import '../app/motion.dart';
import '../data/app_store.dart';

class PeriodSlide extends StatefulWidget {
  const PeriodSlide({
    super.key,
    required this.periodKey,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  final Object periodKey;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget child;

  @override
  State<PeriodSlide> createState() => _PeriodSlideState();
}

class _PeriodSlideState extends State<PeriodSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Widget? _outgoing;
  var _dir = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: NexusMotion.page)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed || !mounted) return;
        setState(() {
          _outgoing = null;
          _dir = 0;
        });
      });
  }

  @override
  void didUpdateWidget(covariant PeriodSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periodKey == widget.periodKey) return;
    if (_skipMotion) {
      _outgoing = null;
      _dir = 0;
      _controller.value = 0;
      return;
    }
    _outgoing = oldWidget.child;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _skipMotion {
    if (NexusMotion.inWidgetTest) return true;
    try {
      return AppScope.of(context).settings.reduceMotion;
    } catch (_) {
      return false;
    }
  }

  void _go(int delta) {
    if (delta == 0) return;
    if (_controller.isAnimating) {
      _controller.value = 1;
      _outgoing = null;
    }
    _dir = delta.toDouble();
    if (delta < 0) {
      widget.onPrevious();
    } else {
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: NexusMotion.curve);
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 180) {
          _go(-1);
        } else if (velocity < -180) {
          _go(1);
        }
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _go(-1),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _go(1),
                  ),
                ),
              ],
            ),
          ),
          ClipRect(
            child: AnimatedBuilder(
              animation: curved,
              builder: (context, _) {
                return Stack(
                  children: [
                    if (_outgoing != null)
                      IgnorePointer(
                        child: FractionalTranslation(
                          translation: Offset(-_dir * curved.value, 0),
                          child: _outgoing,
                        ),
                      ),
                    FractionalTranslation(
                      translation: Offset(_dir * (1 - curved.value), 0),
                      child: widget.child,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
