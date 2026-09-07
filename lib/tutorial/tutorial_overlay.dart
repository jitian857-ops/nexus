import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../cloud/nexus_cloud.dart';
import '../data/app_store.dart';
import '../widgets/glass_card.dart';
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
  var _page = 0;
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
    setState(() {
      _showing = tab;
      _page = 0;
    });
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
    setState(() {
      _showing = null;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tab = _showing;
    return Stack(
      children: [
        widget.child,
        if (tab != null) _Pager(deck: TutorialDeck.of(tab), page: _page, onPage: (i) => setState(() => _page = i), onSkip: () => _finish(skipped: true), onDone: () => _finish(skipped: false)),
      ],
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.deck,
    required this.page,
    required this.onPage,
    required this.onSkip,
    required this.onDone,
  });

  final TutorialDeck deck;
  final int page;
  final ValueChanged<int> onPage;
  final VoidCallback onSkip;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final slides = deck.slides;
    final last = page >= slides.length - 1;
    final slide = slides[page.clamp(0, slides.length - 1)];
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onSkip,
                child: const Text('スキップ'),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    slide.asset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: NexusColors.background,
                      child: Center(
                        child: Icon(Icons.phone_iphone_rounded, color: NexusColors.cyan, size: 64),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GlassCard(
                glowColor: NexusColors.cyan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/mascot/negumo_wave.png',
                          width: 44,
                          height: 44,
                          errorBuilder: (_, _, _) => const SizedBox(width: 44, height: 44),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            slide.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      slide.body,
                      style: TextStyle(color: NexusColors.textSecondary, height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (var i = 0; i < slides.length; i++)
                          Container(
                            width: i == page ? 16 : 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: i == page ? NexusColors.cyan : NexusColors.hairline,
                            ),
                          ),
                        const Spacer(),
                        FilledButton(
                          onPressed: last
                              ? onDone
                              : () => onPage((page + 1).clamp(0, slides.length - 1)),
                          child: Text(last ? 'はじめる' : '次へ'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
