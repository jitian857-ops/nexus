import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/motion.dart';

enum NegumoAction { idle, walk, fly, wave, auto }

/// ネグモ。2Dスプライトをコマ送りして、歩き・飛び・手振りをループする。
class NegumoMascot extends StatefulWidget {
  const NegumoMascot({
    super.key,
    this.size = 176,
    this.action = NegumoAction.auto,
  });

  final double size;
  final NegumoAction action;

  @override
  State<NegumoMascot> createState() => _NegumoMascotState();
}

class _NegumoMascotState extends State<NegumoMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  static const _idle = 'assets/mascot/negumo_idle.png';
  static const _walkA = 'assets/mascot/negumo_walk_a.png';
  static const _walkB = 'assets/mascot/negumo_walk_b.png';
  static const _walkC = 'assets/mascot/negumo_walk_c.png';
  static const _fly = 'assets/mascot/negumo_fly.png';
  static const _wave = 'assets/mascot/negumo_wave.png';

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 9000));
    if (!NexusMotion.inWidgetTest) _loop.repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  NegumoAction get _action {
    if (widget.action != NegumoAction.auto) return widget.action;
    final t = _loop.value;
    if (t < 0.18) return NegumoAction.wave;
    if (t < 0.58) return NegumoAction.walk;
    if (t < 0.82) return NegumoAction.fly;
    return NegumoAction.idle;
  }

  String get _frame {
    final t = _loop.value;
    switch (_action) {
      case NegumoAction.walk:
        final step = ((t * 24) % 4).floor();
        return switch (step) {
          0 => _walkA,
          1 => _walkB,
          2 => _walkC,
          _ => _walkB,
        };
      case NegumoAction.fly:
        return _fly;
      case NegumoAction.wave:
        return ((t * 8) % 1) < 0.55 ? _wave : _idle;
      case NegumoAction.idle:
      case NegumoAction.auto:
        return _idle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        final t = _loop.value;
        final action = _action;
        var dx = 0.0;
        var dy = 0.0;
        var flip = false;
        var scale = 1.0;
        if (widget.action == NegumoAction.auto && action == NegumoAction.walk) {
          final walkT = ((t - 0.18) / 0.40).clamp(0.0, 1.0);
          dx = -72 + walkT * 144;
          flip = walkT > 0.97;
        } else if (action == NegumoAction.fly) {
          dy = math.sin(t * math.pi * 6) * 16;
          dx = math.cos(t * math.pi * 4) * 10;
        } else if (action == NegumoAction.idle || action == NegumoAction.wave) {
          dy = math.sin(t * math.pi * 2) * 6;
          scale = 1 + math.sin(t * math.pi * 2) * 0.015;
        }
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.flip(
            flipX: flip,
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Image.asset(
                  _frame,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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
