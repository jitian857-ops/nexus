import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../domain/daily_quotes.dart';
import '../../domain/day_occasions.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/schedule_sheet.dart';
import '../../widgets/ui_bits.dart';
import 'home_header.dart';
import 'home_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _tick;
  AppStore? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context);
    if (_store != store) {
      _store?.removeListener(_syncTick);
      _store = store;
      _store!.addListener(_syncTick);
      _syncTick();
    }
  }

  void _syncTick() {
    final running = _store?.timerRunning ?? false;
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running && _tick != null) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_syncTick);
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);

    return PageScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          const HomeHeader(),
          const SizedBox(height: 14),
          const _HeroRow(),
          const SizedBox(height: 12),
          _ScheduleCard(store: store),
          const SizedBox(height: 12),
          const HomeWidgetCarousel(),
        ],
      ),
    );
  }
}

class _HeroRow extends StatelessWidget {
  const _HeroRow();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final occasion = store.todayOccasion;
    final quote = store.todayQuote;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _openOccasion(context, store.focusedDate, occasion),
            borderRadius: BorderRadius.circular(NexusColors.cardRadius),
            child: GlassCard(
              glowColor: NexusColors.cyan,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: SizedBox(
                height: 92,
                child: Stack(
                  children: [
                    Positioned(
                      right: -18,
                      top: -10,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              NexusColors.cyan.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本日は',
                          style: TextStyle(
                            color: NexusColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          occasion.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: NexusColors.text,
                            fontSize: occasion.name.length >= 8 ? 16 : 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.4,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () => _openQuote(context, quote),
            borderRadius: BorderRadius.circular(NexusColors.cardRadius),
            child: GlassCard(
              borderColor: NexusColors.purple.withValues(alpha: 0.28),
              glowColor: NexusColors.purple,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: SizedBox(
                height: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日の名言',
                      style: TextStyle(
                        color: NexusColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        quote.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '— ${quote.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: NexusColors.purple,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _openOccasion(
  BuildContext context,
  DateTime date,
  DayOccasion occasion,
) {
  return showNexusSheet<void>(
    context: context,
    builder: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          occasion.name,
          style: TextStyle(
            color: NexusColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${jpDate(date)} ・ ${occasion.kind}',
          style: TextStyle(color: NexusColors.cyan, fontSize: 12),
        ),
        if (occasion.alsoKnownAs.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'あわせて ${occasion.alsoKnownAs.join('、')}',
            style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          '由来',
          style: TextStyle(
            color: NexusColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          occasion.reason,
          style: TextStyle(
            color: NexusColors.text,
            height: 1.55,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

Future<void> _openQuote(BuildContext context, DailyQuote quote) {
  return showNexusSheet<void>(
    context: context,
    builder: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日の名言',
          style: TextStyle(color: NexusColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Text(
          quote.text,
          style: TextStyle(
            color: NexusColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '— ${quote.author}',
          style: TextStyle(
            color: NexusColors.purple,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          quote.note,
          style: TextStyle(
            color: NexusColors.textSecondary,
            height: 1.5,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final items = store.schedulesOn(store.focusedDate);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        children: [
          SectionRow(
            title: '今日の予定',
            trailing: AddChip(
              label: '予定を追加',
              onTap: () => openScheduleEditor(context),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 148,
            child: items.isEmpty
                ? Center(
                    child: Text(
                      '予定はまだありません',
                      style: TextStyle(color: NexusColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return InkWell(
                        onTap: () => openScheduleEditor(context, item: item),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: NexusColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: NexusColors.border.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: NexusColors.cyan.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  hm(item.startAt),
                                  style: TextStyle(
                                    color: NexusColors.cyan,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    color: NexusColors.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: NexusColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
