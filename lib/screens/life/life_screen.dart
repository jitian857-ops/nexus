import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/schedule_sheet.dart';
import '../../widgets/ui_bits.dart';
import 'sleep_sheet.dart';

const _lifeCardHeight = 208.0;

class LifeScreen extends StatelessWidget {
  const LifeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final day = store.lifeDate;
    final items = store.schedulesOn(day);

    return PageScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientTitle('Life'),
                  ],
                ),
              ),
              _DateButton(
                label: jpDate(day),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: day,
                    firstDate: DateTime(2026, 1, 1),
                    lastDate: DateTime(2027, 12, 31),
                  );
                  if (picked != null) store.setLifeDate(picked);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              children: [
                SectionRow(
                  title: 'カレンダー',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => store.shiftLifeMonth(-1),
                        icon: Icon(Icons.chevron_left, color: NexusColors.cyan),
                      ),
                      Text(jpMonth(day), style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => store.shiftLifeMonth(1),
                        icon: Icon(Icons.chevron_right, color: NexusColors.cyan),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _MonthGrid(store: store),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                SectionRow(
                  title: '${day.month}月${day.day}日の予定',
                  trailing: AddChip(label: '予定を追加', onTap: () => openScheduleEditor(context, day: day)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 132,
                  child: items.isEmpty
                      ? Center(
                          child: Text('予定はありません', style: TextStyle(color: NexusColors.textMuted)),
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final item = items[i];
                            return InkWell(
                              onTap: () => openScheduleEditor(context, item: item),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: NexusColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border(
                                    left: BorderSide(color: NexusColors.cyan, width: 3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      hm(item.startAt),
                                      style: TextStyle(
                                        color: NexusColors.cyan,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SizedBox(height: _lifeCardHeight, child: _HabitCard(store: store))),
              const SizedBox(width: 10),
              Expanded(child: SizedBox(height: _lifeCardHeight, child: _SleepCard(store: store))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: SizedBox(height: _lifeCardHeight, child: _MoodCard(store: store))),
              const SizedBox(width: 10),
              Expanded(child: SizedBox(height: _lifeCardHeight, child: _StepsCard(store: store))),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _editDiary(context, store),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionRow(
                    title: '${day.month}月${day.day}日の日記',
                    trailing: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: day,
                          firstDate: DateTime(day.year - 1, 1, 1),
                          lastDate: DateTime(day.year + 1, 12, 31),
                        );
                        if (picked != null) store.setLifeDate(picked);
                      },
                      child: AbsorbPointer(
                        child: _DateButton(
                          label: jpDate(day),
                          onTap: () {},
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    store.diary.isEmpty ? 'この日の日記はまだありません' : store.diary,
                    style: TextStyle(
                      height: 1.4,
                      color: store.diary.isEmpty ? NexusColors.textMuted : NexusColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editDiary(BuildContext context, AppStore store) async {
    final controller = TextEditingController(text: store.diary);
    final saved = await showNexusSheet<bool>(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${store.lifeDate.month}月${store.lifeDate.day}日の日記',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 5,
              style: TextStyle(color: NexusColors.text),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (saved == true) store.setDiary(controller.text.trim());
    controller.dispose();
  }
}

Future<void> _openHabitForm(BuildContext context, AppStore store, {Habit? existing}) async {
  final name = TextEditingController(text: existing?.name ?? '');
  var icon = existing?.icon ?? Icons.wb_sunny_rounded;
  var color = existing?.color ?? const Color(0xFFFFC857);
  const colors = [
    Color(0xFFFFC857),
    Color(0xFF00D4FF),
    Color(0xFF3DFF8A),
    Color(0xFF9B6BFF),
    Color(0xFFFF8AD2),
    Color(0xFFC4B7A0),
  ];
  const icons = [
    Icons.wb_sunny_rounded,
    Icons.menu_book_rounded,
    Icons.directions_run_rounded,
    Icons.bedtime_rounded,
    Icons.spa_rounded,
    Icons.nightlight_round,
    Icons.fitness_center_rounded,
    Icons.self_improvement_rounded,
  ];
  final saved = await showNexusSheet<Object>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? '習慣を追加' : '習慣を編集', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                autofocus: true,
                style: TextStyle(color: NexusColors.text),
                decoration: const InputDecoration(labelText: '習慣名'),
              ),
              const SizedBox(height: 12),
              Text('アイコン', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
              Wrap(
                spacing: 4,
                children: [
                  for (final i in icons)
                    IconButton(
                      onPressed: () => setSheet(() => icon = i),
                      icon: Icon(i, color: i == icon ? color : NexusColors.textMuted),
                    ),
                ],
              ),
              Text('色', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
              Row(
                children: [
                  for (final c in colors)
                    GestureDetector(
                      onTap: () => setSheet(() => color = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c == color ? NexusColors.text : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(existing == null ? '追加' : '保存'),
              ),
              if (existing != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'delete'),
                  child: Text('削除', style: TextStyle(color: NexusColors.expense)),
                ),
              ],
            ],
          );
        },
      );
    },
  );
  if (saved == 'delete' && existing != null) {
    store.deleteHabit(existing.id);
    if (context.mounted) showNexusToast(context, store.lastToast);
  } else if (saved == true && name.text.trim().isNotEmpty) {
    if (existing == null) {
      store.addHabit(name: name.text.trim(), icon: icon, color: color);
    } else {
      store.updateHabit(existing.copyWith(name: name.text.trim(), icon: icon, color: color));
    }
    if (context.mounted) showNexusToast(context, store.lastToast);
  }
  name.dispose();
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NexusColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, size: 14, color: NexusColors.cyan),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final focused = store.lifeDate;
    final first = DateTime(focused.year, focused.month, 1);
    final daysInMonth = DateTime(focused.year, focused.month + 1, 0).day;
    final leading = mondayIndex(first);
    final now = DateTime.now();
    final today = (now.year == focused.year && now.month == focused.month) ? now.day : -1;
    final marked = {
      for (final s in store.schedules)
        if (s.startAt.year == focused.year && s.startAt.month == focused.month) s.startAt.day,
    };

    return Column(
      children: [
        Row(
          children: [
            for (final label in weekLabels)
              Expanded(
                child: Center(
                  child: Text(label, style: TextStyle(color: NexusColors.textMuted, fontSize: 11)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < 6; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _DayCell(
                      day: row * 7 + col - leading + 1,
                      daysInMonth: daysInMonth,
                      selected: focused.day,
                      today: today,
                      marked: marked,
                      onTap: (d) => store.setLifeDate(DateTime(focused.year, focused.month, d)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.daysInMonth,
    required this.selected,
    required this.today,
    required this.marked,
    required this.onTap,
  });

  final int day;
  final int daysInMonth;
  final int selected;
  final int today;
  final Set<int> marked;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 32);
    final isSelected = day == selected;
    final isToday = day == today;
    return InkWell(
      onTap: () => onTap(day),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: isSelected
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [NexusColors.cyan, NexusColors.purple],
                      ),
                      boxShadow: NexusColors.isLight
                          ? null
                          : [
                              BoxShadow(
                                color: NexusColors.cyan.withValues(alpha: 0.35),
                                blurRadius: 10,
                              ),
                            ],
                    )
                  : isToday
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: NexusColors.cyan.withValues(alpha: 0.55),
                          ),
                        )
                      : null,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Colors.white
                      : isToday
                          ? NexusColors.cyan
                          : NexusColors.textSecondary,
                  fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (marked.contains(day) && !isSelected)
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: NexusColors.cyan, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

class _LifeCardTitle extends StatelessWidget {
  const _LifeCardTitle({
    required this.icon,
    required this.color,
    required this.title,
  });

  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      height: _lifeCardHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _LifeCardTitle(
                  icon: Icons.local_fire_department_rounded,
                  color: NexusColors.gold,
                  title: '習慣チェーン',
                ),
              ),
              IconButton(
                onPressed: () => _openHabitForm(context, store),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(Icons.add_rounded, size: 20, color: NexusColors.cyan),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: store.habits.isEmpty
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Text('習慣はまだありません', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final habit in store.habits)
                        _HabitRow(key: ValueKey(habit.id), store: store, habit: habit),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HabitRow extends StatefulWidget {
  const _HabitRow({super.key, required this.store, required this.habit});

  final AppStore store;
  final Habit habit;

  @override
  State<_HabitRow> createState() => _HabitRowState();
}

class _HabitRowState extends State<_HabitRow> {
  var _lit = false;

  Future<void> _flash() async {
    setState(() => _lit = true);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (mounted) setState(() => _lit = false);
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final day = widget.store.lifeDate;
    return InkWell(
      onTap: () {
        final turningOn = !habit.doneOn(day);
        widget.store.toggleHabit(habit.id, day);
        if (turningOn) {
          nexusHaptic();
          _flash();
        }
      },
      onLongPress: () => _openHabitForm(context, widget.store, existing: habit),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: _lit ? NexusColors.gold.withValues(alpha: 0.12) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(habit.icon, size: 16, color: habit.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(habit.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 280),
              style: TextStyle(
                color: _lit ? NexusColors.gold : habit.color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              child: Text('${habit.currentStreak(day)}日連続'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepCard extends StatelessWidget {
  const _SleepCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final week = store.sleepWeekHours(store.lifeDate);
    return InkWell(
      onTap: () => openSleepLogger(context, store),
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        height: _lifeCardHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LifeCardTitle(
              icon: Icons.bedtime_rounded,
              color: NexusColors.periwinkle,
              title: '睡眠の記録',
            ),
            const SizedBox(height: 8),
            Text(
              store.isSleeping ? '就寝中' : '${store.sleepHours.toStringAsFixed(1)}h',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            Text(
              store.isSleeping ? 'タップして起床を記録' : '就寝・起床で記録  目標 7-8時間',
              style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < week.length; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 48 * ((week[i] / 9).clamp(0.08, 1)),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: i == mondayIndex(store.lifeDate)
                                ? [NexusColors.purple, NexusColors.cyan]
                                : [
                                    NexusColors.cyan.withValues(alpha: 0.7),
                                    NexusColors.purple.withValues(alpha: 0.45),
                                  ],
                          ),
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

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      height: _lifeCardHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LifeCardTitle(
            icon: Icons.emoji_emotions_rounded,
            color: NexusColors.green,
            title: '気分とエネルギー',
          ),
          const SizedBox(height: 8),
          Text('いまの気分は?', style: TextStyle(color: NexusColors.textMuted, fontSize: 11)),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Expanded(
                  child: IconButton(
                    onPressed: () => store.setMood(i),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(
                      i <= store.mood
                          ? (store.mood >= 4
                              ? Icons.sentiment_very_satisfied_rounded
                              : Icons.sentiment_satisfied_rounded)
                          : Icons.sentiment_neutral_rounded,
                      size: 22,
                      color: i <= store.mood ? NexusColors.green : NexusColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          Text('エネルギーは?', style: TextStyle(color: NexusColors.textMuted, fontSize: 11)),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Expanded(
                  child: IconButton(
                    onPressed: () => store.setEnergy(i),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(
                      Icons.bolt_rounded,
                      size: 22,
                      color: i <= store.energy ? NexusColors.green : NexusColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final left = (store.stepGoal - store.steps).clamp(0, store.stepGoal);
    return GlassCard(
      height: _lifeCardHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LifeCardTitle(
            icon: Icons.directions_walk_rounded,
            color: NexusColors.cyan,
            title: '今日の歩数',
          ),
          const SizedBox(height: 10),
          Text(
            '${store.steps} 歩',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: store.steps / store.stepGoal,
              minHeight: 8,
              color: NexusColors.green,
              backgroundColor: NexusColors.border,
            ),
          ),
          const SizedBox(height: 8),
          Text('目標まであと $left 歩', style: TextStyle(color: NexusColors.textMuted, fontSize: 11)),
          const Spacer(),
        ],
      ),
    );
  }
}
