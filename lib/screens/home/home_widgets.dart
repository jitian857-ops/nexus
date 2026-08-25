import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../widgets/count_up_yen.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/nexus_nav_bar.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/ui_bits.dart';

class HomeWidgetCarousel extends StatelessWidget {
  const HomeWidgetCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final money = store.money;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _GoalCard(
                progress: store.goalProgress,
                remainingLabel: remainingStudyLabel(store.remainingStudyMinutes()),
                goalLabel: studyGoalLabel(store.dailyStudyGoalMinutes),
                onTap: () => _openStudyGoalEditor(context, store),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BalanceCard(
                balance: money.balance,
                income: money.income,
                expense: money.expense,
                onTap: () => store.goTo(NexusTab.money),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _StudyTimeCard(
          hours: store.weekStudyHours,
          bars: store.weekBars,
          onTap: () => store.goTo(NexusTab.study),
        ),
      ],
    );
  }
}

class WidgetLabel extends StatelessWidget {
  const WidgetLabel({super.key, required this.code, required this.title});

  final String code;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          code,
          style: TextStyle(
            color: NexusColors.purple.withValues(alpha: 0.9),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: NexusColors.textSecondary, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.progress,
    required this.remainingLabel,
    required this.goalLabel,
    required this.onTap,
  });

  final double progress;
  final String remainingLabel;
  final String goalLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = remainingLabel == '達成';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NexusColors.cardRadius),
      child: GlassCard(
        height: 168,
        glowColor: NexusColors.cyan,
        child: Column(
          children: [
            const WidgetLabel(code: 'W01', title: '今日の目標'),
            Expanded(
              child: Center(
                child: ProgressRing(
                  progress: progress,
                  size: 96,
                  stroke: 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        done ? '達成' : '残り',
                        style: const TextStyle(color: NexusColors.textMuted, fontSize: 10),
                      ),
                      Text(
                        done ? '' : remainingLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: NexusColors.text,
                          fontSize: remainingLabel.length >= 6 ? 13 : 16,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Text('目標 $goalLabel', style: const TextStyle(color: NexusColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

Future<void> _openStudyGoalEditor(BuildContext context, AppStore store) async {
  const presets = [30, 60, 90, 120, 180, 240];
  await showNexusSheet<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          final remaining = remainingStudyLabel(store.remainingStudyMinutes());
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('今日の勉強時間', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                remaining == '達成' ? '今日の目標は達成しています' : '残り $remaining',
                style: const TextStyle(color: NexusColors.cyan, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in presets)
                    ChoiceChip(
                      label: Text(studyGoalLabel(minutes)),
                      selected: store.dailyStudyGoalMinutes == minutes,
                      selectedColor: NexusColors.cyan.withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        color: store.dailyStudyGoalMinutes == minutes ? NexusColors.cyan : NexusColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) {
                        store.setDailyStudyGoalMinutes(minutes);
                        setSheet(() {});
                      },
                    ),
                ],
              ),
              Slider(
                value: store.dailyStudyGoalMinutes.toDouble(),
                min: 10,
                max: 360,
                divisions: 35,
                label: studyGoalLabel(store.dailyStudyGoalMinutes),
                onChanged: (value) {
                  store.setDailyStudyGoalMinutes(value.round());
                  setSheet(() {});
                },
              ),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
            ],
          );
        },
      );
    },
  );
}

class _StudyTimeCard extends StatelessWidget {
  const _StudyTimeCard({
    required this.hours,
    required this.bars,
    required this.onTap,
  });

  final double hours;
  final List<double> bars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NexusColors.cardRadius),
      child: GlassCard(
        height: 256,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WidgetLabel(code: 'W04', title: '今週の学習時間'),
            Text(
              '${hours}h',
              style: const TextStyle(
                color: NexusColors.purple,
                fontSize: 28,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < weekLabels.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedFractionallySizedBox(
                                  duration: const Duration(milliseconds: 520),
                                  curve: Curves.easeOutCubic,
                                  heightFactor: i < bars.length ? bars[i] : 0,
                                  widthFactor: 1,
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(Radius.circular(4)),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [NexusColors.cyan, NexusColors.purple],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              weekLabels[i],
                              style: const TextStyle(color: NexusColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.income,
    required this.expense,
    required this.onTap,
  });

  final int balance;
  final int income;
  final int expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NexusColors.cardRadius),
      child: GlassCard(
        height: 168,
        glowColor: NexusColors.gold,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WidgetLabel(code: 'W13', title: '今月の残高'),
            const Spacer(),
            CountUpYen(
              value: balance,
              style: const TextStyle(
                color: NexusColors.gold,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const Text('収入', style: TextStyle(color: NexusColors.textMuted, fontSize: 11)),
                const Spacer(),
                Text(
                  yen(income),
                  style: const TextStyle(
                    color: NexusColors.income,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('支出', style: TextStyle(color: NexusColors.textMuted, fontSize: 11)),
                const Spacer(),
                Text(
                  yen(-expense),
                  style: const TextStyle(
                    color: NexusColors.expense,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
