import 'package:flutter/material.dart';

import '../core/format.dart';

class CountUpYen extends StatefulWidget {
  const CountUpYen({
    super.key,
    required this.value,
    this.style,
  });

  final int value;
  final TextStyle? style;

  @override
  State<CountUpYen> createState() => _CountUpYenState();
}

class _CountUpYenState extends State<CountUpYen> {
  late int _from;

  @override
  void initState() {
    super.initState();
    _from = widget.value;
  }

  @override
  void didUpdateWidget(covariant CountUpYen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _from = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from.toDouble(), end: widget.value.toDouble()),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Text(yen(value.round()), style: widget.style);
      },
    );
  }
}
