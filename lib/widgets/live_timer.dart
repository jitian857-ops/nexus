import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_store.dart';

/// Rebuilds only this subtree once a second while a timer is running and the
/// widget is on-screen. Hidden tabs (TickerMode disabled) do not tick.
class LiveTimerBuilder extends StatefulWidget {
  const LiveTimerBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, AppStore store) builder;

  @override
  State<LiveTimerBuilder> createState() => _LiveTimerBuilderState();
}

class _LiveTimerBuilderState extends State<LiveTimerBuilder> {
  Timer? _tick;
  AppStore? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context);
    if (_store != store) {
      _store?.removeListener(_onStore);
      _store = store;
      _store!.addListener(_onStore);
    }
    _syncTick();
  }

  void _onStore() => _syncTick();

  void _syncTick() {
    final active = TickerMode.valuesOf(context).enabled;
    final running = _store?.timerRunning ?? false;
    if (active && running) {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_onStore);
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncTick();
    return widget.builder(context, AppScope.of(context));
  }
}
