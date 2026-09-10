import 'package:flutter/material.dart';

import '../app/motion.dart';
import '../app/theme.dart';
import '../cloud/nexus_cloud.dart';
import '../data/app_store.dart';
import 'tutorial_catalog.dart';
import 'tutorial_gate.dart';

class TutorialLayer extends StatefulWidget {
  const TutorialLayer({super.key, required this.child});

  final Widget child;

  @override
  State<TutorialLayer> createState() => _TutorialLayerState();
}

class _TutorialLayerState extends State<TutorialLayer> {
  AppStore? _store;
  TutorialTab? _showing;
  var _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context);
    if (_store != store) {
      _store?.removeListener(_onStore);
      _store = store;
      _store!.addListener(_onStore);
    }
    _consider();
  }

  @override
  void dispose() {
    _store?.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (_showing != null) return;
    _consider();
  }

  Future<void> _consider() async {
    if (!mounted || _busy || _showing != null) return;
    final store = AppScope.of(context);
    final cloud = CloudScope.of(context);
    final tab = TutorialDeck.forIndex(store.tabIndex);
    if (tab == null || cloud.uid.isEmpty) return;
    _busy = true;
    final show = await TutorialGate.shouldShow(
      uid: cloud.uid,
      tab: tab,
      hasRecords: store.hasMeaningfulRecords,
    );
    if (!mounted) return;
    _busy = false;
    if (!show) return;
    setState(() => _showing = tab);
  }

  Future<void> _finish({required bool skipped}) async {
    final tab = _showing;
    final uid = CloudScope.of(context).uid;
    if (tab != null && uid.isNotEmpty) {
      if (skipped) {
        await TutorialGate.markSkipped(uid, tab);
      } else {
        await TutorialGate.markDone(uid, tab);
      }
    }
    if (!mounted) return;
    setState(() => _showing = null);
  }

  Duration get _fadeDuration {
    if (NexusMotion.inWidgetTest) return Duration.zero;
    return NexusMotion.duration(context, NexusMotion.med);
  }

  @override
  Widget build(BuildContext context) {
    final tab = _showing;
    return Stack(
      children: [
        widget.child,
        AnimatedSwitcher(
          duration: _fadeDuration,
          switchInCurve: NexusMotion.curve,
          switchOutCurve: NexusMotion.curve,
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: tab == null
              ? const SizedBox.shrink(key: ValueKey('tutorial-off'))
              : _Pager(
                  key: ValueKey(tab),
                  deck: TutorialDeck.of(tab),
                  onSkip: () => _finish(skipped: true),
                  onDone: () => _finish(skipped: false),
                ),
        ),
      ],
    );
  }
}

class _Pager extends StatefulWidget {
  const _Pager({
    super.key,
    required this.deck,
    required this.onSkip,
    required this.onDone,
  });

  final TutorialDeck deck;
  final VoidCallback onSkip;
  final VoidCallback onDone;

  @override
  State<_Pager> createState() => _PagerState();
}

class _PagerState extends State<_Pager> {
  static const _viewportFraction = 0.74;

  late final PageController _controller;
  var _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: _viewportFraction);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Duration get _pageDuration {
    if (NexusMotion.inWidgetTest) return Duration.zero;
    return NexusMotion.duration(context, NexusMotion.page);
  }

  Future<void> _goTo(int index) async {
    if (!_controller.hasClients) return;
    final target = index.clamp(0, widget.deck.slides.length - 1);
    if (target == _page) return;
    final duration = _pageDuration;
    if (duration == Duration.zero) {
      _controller.jumpToPage(target);
      return;
    }
    await _controller.animateToPage(target, duration: duration, curve: NexusMotion.curve);
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.deck.slides;
    return Material(
      key: const Key('tutorial-overlay'),
      color: Colors.black.withValues(alpha: 0.42),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            key: const Key('tutorial-pager'),
            controller: _controller,
            itemCount: slides.length,
            padEnds: true,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final slide = slides[i];
              final last = i >= slides.length - 1;
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final page = _controller.hasClients
                      ? (_controller.page ?? _page.toDouble())
                      : _page.toDouble();
                  final dist = (page - i).abs().clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 56, 4, 36),
                    child: Center(
                      child: Transform.scale(
                        scale: 1 - dist * 0.08,
                        child: child,
                      ),
                    ),
                  );
                },
                child: _FloatingPhone(
                  child: Semantics(
                    label: slide.label,
                    button: true,
                    hint: last ? widget.deck.finishLabel : '次へ',
                    child: GestureDetector(
                      key: i == _page ? const Key('tutorial-next') : null,
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (i >= slides.length - 1) {
                          widget.onDone();
                        } else {
                          _goTo(i + 1);
                        }
                      },
                      child: Image.asset(
                        slide.asset,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: NexusColors.background,
                          child: const Center(
                            child: Icon(Icons.phone_iphone_rounded, color: Colors.white54, size: 64),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: PressScale(
                  onTap: widget.onSkip,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: const StadiumBorder(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text('スキップ', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingPhone extends StatelessWidget {
  const _FloatingPhone({required this.child});

  final Widget child;

  static const _bezel = 7.0;
  static const _outerRadius = 38.0;
  static const _innerRadius = 32.0;
  static const _aspect = 9 / 19.5;

  @override
  Widget build(BuildContext context) {
    final light = NexusColors.isLight;
    return AspectRatio(
      aspectRatio: _aspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_outerRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: light
                ? [
                    NexusColors.border,
                    NexusColors.frame,
                    NexusColors.border,
                  ]
                : [
                    NexusColors.cyan.withValues(alpha: 0.45),
                    NexusColors.purple.withValues(alpha: 0.28),
                    NexusColors.text.withValues(alpha: 0.08),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: light ? 0.28 : 0.55),
              blurRadius: 42,
              offset: const Offset(0, 22),
              spreadRadius: -6,
            ),
            BoxShadow(
              color: light
                  ? Colors.black.withValues(alpha: 0.1)
                  : NexusColors.cyan.withValues(alpha: 0.18),
              blurRadius: light ? 16 : 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(_bezel),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_innerRadius),
            child: SizedBox.expand(child: child),
          ),
        ),
      ),
    );
  }
}
