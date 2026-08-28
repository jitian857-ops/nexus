import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../data/nexus_icons.dart';
import '../../domain/money_calc.dart';
import '../../widgets/duration_picker.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/study_week_chart.dart';
import '../../widgets/ui_bits.dart';
import 'focus_timer_page.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              const Expanded(child: GradientTitle('Study')),
              AddChip(
                label: '学習を追加',
                onTap: () => _addStudySession(context, store),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            jpDate(store.focusedDate),
            style: TextStyle(color: NexusColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          _TotalStudyCard(store: store),
          const SizedBox(height: 12),
          SectionRow(
            title: '科目別・今週の勉強時間',
            trailing: AddChip(
              label: '教科を追加',
              onTap: () => promptNewSubject(context, store),
            ),
          ),
          const SizedBox(height: 8),
          if (store.subjects.isEmpty)
            SizedBox(
              height: 124,
              child: Center(
                child: Text('教科はまだありません', style: TextStyle(color: NexusColors.textMuted)),
              ),
            )
          else
            SizedBox(
              height: 124,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                padding: EdgeInsets.zero,
                itemCount: store.subjects.length,
                onReorder: store.reorderSubjects,
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) => Transform.scale(scale: 1.05, child: child),
                  );
                },
                itemBuilder: (context, i) {
                  final s = store.subjects[i];
                  final hours = store.subjectWeekHours(s.id);
                  return Padding(
                    key: ValueKey(s.id),
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: 132,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ReorderableTapDragListener(
                              index: i,
                              enabled: store.subjects.length > 1,
                              onTap: () => openSubjectWeek(context, store, s.id),
                              child: GlassCard(
                                borderColor: s.color.withValues(alpha: 0.35),
                                glowColor: s.color,
                                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: s.color.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Icon(s.icon, color: s.color, size: 17),
                                    ),
                                    const Spacer(),
                                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(
                                      formatStudyHours(s.weekHours),
                                      style: TextStyle(color: s.color, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 6),
                                    _WeekDots(hours: hours, color: s.color),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: _TinyDelete(
                              onTap: () async {
                                final ok = await _confirmDelete(context, title: '教科を削除', body: '「${s.name}」を削除します。');
                                if (!ok || !context.mounted) return;
                                store.deleteSubject(s.id);
                                showNexusToast(context, store.lastToast);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (store.subjects.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'ダブルタップしてからドラッグすると順番を変えられます',
                style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
              ),
            ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                SectionRow(
                  title: '提出物',
                  trailing: AddChip(
                    label: '提出物を追加',
                    onTap: () => _addAssignment(context, store),
                  ),
                ),
                const SizedBox(height: 8),
                if (store.assignments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('提出物はまだありません', style: TextStyle(color: NexusColors.textMuted)),
                  ),
                for (final a in store.assignments)
                  _AssignmentRow(assignment: a, today: store.focusedDate, store: store),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _TimerCard(store: store),
          const SizedBox(height: 12),
          GlassCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('復習カード', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '今日のキュー ${store.reviewDueCount()}枚',
                        style: TextStyle(color: NexusColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => _openReview(context, store),
                  child: const Text('復習する'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionRow(
                  title: '目標ロードマップ',
                  trailing: AddChip(
                    label: '目標を追加',
                    onTap: () => _addGoal(context, store),
                  ),
                ),
                const SizedBox(height: 8),
                if (store.goals.isEmpty)
                  Text('目標はまだありません', style: TextStyle(color: NexusColors.textMuted)),
                for (final goal in store.goals) ...[
                  _GoalBlock(goal: goal, store: store),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                SectionRow(
                  title: '試験カウントダウン',
                  trailing: AddChip(
                    label: '試験日を追加',
                    onTap: () => _addExam(context, store),
                  ),
                ),
                const SizedBox(height: 12),
                if (store.exams.isEmpty)
                  Text('試験日はまだありません', style: TextStyle(color: NexusColors.textMuted))
                else
                SizedBox(
                    height: 128,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: store.exams.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final exam = store.exams[i];
                        return SizedBox(
                          width: 96,
                          child: Stack(
                            children: [
                              _ExamRing(exam: exam, today: store.focusedDate),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: _TinyDelete(
                                  onTap: () async {
                                    final ok = await _confirmDelete(context, title: '試験日を削除', body: '「${exam.title}」を削除します。');
                                    if (!ok || !context.mounted) return;
                                    store.deleteExam(exam.id);
                                    showNexusToast(context, store.lastToast);
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionRow(title: '今日の問題'),
                const SizedBox(height: 10),
                for (final p in store.problems) _ProblemRow(problem: p, store: store),
                const SizedBox(height: 8),
                AddChip(label: '問題を記録', onTap: () => _recordProblem(context, store)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingPlay extends StatelessWidget {
  const _PulsingPlay({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NexusColors.cyan, NexusColors.purple],
        ),
        boxShadow: [
          BoxShadow(
            color: NexusColors.cyan.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        running ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: NexusColors.isLight ? Colors.white : Colors.black,
        size: 28,
      ),
    );
  }
}

class _TotalStudyCard extends StatelessWidget {
  const _TotalStudyCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionRow(title: '総勉強時間'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: NexusColors.purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NexusColors.purple.withValues(alpha: 0.25)),
                  ),
                  child: _Hours(label: '今週', value: formatStudyHours(store.weekStudyHours), color: NexusColors.purple),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: NexusColors.cyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NexusColors.cyan.withValues(alpha: 0.25)),
                  ),
                  child: _Hours(label: '累計', value: formatStudyHours(store.totalStudyHours), color: NexusColors.cyan),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              for (final s in store.subjects)
                Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(s.name, style: TextStyle(color: NexusColors.textMuted, fontSize: 11)),
                  ],
                ),
            ],
                ),
                const SizedBox(height: 12),
          SizedBox(
            height: 126,
            child: StudyWeekChart(
              stacks: store.weekStackedHours(),
              colors: [for (final s in store.subjects) s.color],
            ),
          ),
            const SizedBox(height: 6),
          Row(
              children: [
              const SizedBox(width: 34),
              for (final label in weekLabels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
                  ),
                  ),
              ],
            ),
          ],
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final selectedId = store.selectedTimerSubjectId;
    final subject = selectedId == null ? null : store.subjectById(selectedId);
    return InkWell(
      onTap: () => openFocusTimer(context),
      borderRadius: BorderRadius.circular(NexusColors.cardRadius),
      child: GlassCard(
        glowColor: NexusColors.cyan,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionRow(title: '集中タイマー'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (rect) =>
                            LinearGradient(colors: NexusColors.accentSweep)
                                .createShader(rect),
                        child: Text(
                          mmss(store.timerRemainingSeconds()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (subject != null)
                        Text(
                          subject.name,
                          style: TextStyle(
                            color: subject.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                _PulsingPlay(running: store.timerRunning),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.assignment,
    required this.today,
    required this.store,
  });

  final Assignment assignment;
  final DateTime today;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final risk = assignmentRisk(dueAt: assignment.dueAt, today: today, done: assignment.done);
    final color = switch (risk) {
      '要注意' => NexusColors.expense,
      '注意' => const Color(0xFFFFC857),
      _ => NexusColors.cyan,
    };
    final subject = store.subjectById(assignment.subjectId)?.name ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(assignment.title),
                Text(
                  subject,
                  style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                daysLeftLabel(assignment.dueAt, today),
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                '${assignment.dueAt.month}/${assignment.dueAt.day}まで',
                style: TextStyle(color: NexusColors.textMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyDelete extends StatelessWidget {
  const _TinyDelete({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: NexusColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: NexusColors.border),
          ),
          child: Icon(Icons.close, size: 12, color: NexusColors.textMuted),
        ),
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, {required String title, required String body}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: NexusColors.card,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('やめる')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      );
    },
  );
  return result == true;
}

class _GoalBlock extends StatelessWidget {
  const _GoalBlock({required this.goal, required this.store});

  final StudyGoal goal;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final steps = goal.filledSubGoals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(goal.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            _TinyDelete(
              onTap: () async {
                final ok = await _confirmDelete(context, title: '目標を削除', body: '「${goal.title}」を削除します。');
                if (!ok || !context.mounted) return;
                store.deleteGoal(goal.id);
                showNexusToast(context, store.lastToast);
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          [
            if (goal.target > 0) '現在 ${goal.current}  /  目標 ${goal.target}',
            '${jpDate(goal.dueAt)}まで',
          ].join('  /  '),
          style: TextStyle(color: NexusColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (steps.isNotEmpty)
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: steps.length,
              separatorBuilder: (_, _) => Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(width: 18, height: 2, color: NexusColors.cyan.withValues(alpha: 0.35)),
              ),
              itemBuilder: (context, i) {
                final step = steps[i];
                final original = goal.subGoals.indexWhere((s) => s.title == step.title);
                return InkWell(
                  onTap: () => store.toggleSubGoal(goal.id, original < 0 ? i : original),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: step.done ? NexusColors.cyan.withValues(alpha: 0.2) : NexusColors.surface,
                            border: Border.all(
                              color: step.done ? NexusColors.cyan : NexusColors.border,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            step.done ? Icons.check_rounded : Icons.flag_outlined,
                            size: 14,
                            color: step.done ? NexusColors.cyan : NexusColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          step.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: step.done ? NexusColors.textMuted : NexusColors.text,
                            decoration: step.done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: goal.progress,
            minHeight: 8,
            color: NexusColors.cyan,
            backgroundColor: NexusColors.border,
          ),
        ),
      ],
    );
  }
}

class _ExamRing extends StatelessWidget {
  const _ExamRing({required this.exam, required this.today});

  final Exam exam;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final days = dateOnly(exam.examAt).difference(dateOnly(today)).inDays;
    final label = days < 0 ? '終了' : days == 0 ? '今日' : '$days日';
    return Column(
      children: [
        ProgressRing(
          progress: exam.countdownProgress(today),
          size: 78,
          stroke: 6,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          exam.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        Text(
          '${exam.examAt.month}/${exam.examAt.day} (${exam.weekdayLabel})',
          style: TextStyle(color: NexusColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }
}

class _Hours extends StatelessWidget {
  const _Hours({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ProblemRow extends StatelessWidget {
  const _ProblemRow({required this.problem, required this.store});

  final ProblemRecord problem;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final subject = store.subjectById(problem.subjectId)?.name ?? '';
    final cards = store.reviewCards.where((c) => c.problemId == problem.id).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: NexusColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (problem.photoBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  problem.photoBytes!,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: NexusColors.cyan, size: 16),
                const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$subject  ${problem.title}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              cards.map((c) => '${c.intervalStep}日後').join(' ・ '),
              style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
            ),
            if (problem.answer.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '解答  ${problem.answer}',
                style: TextStyle(color: NexusColors.textSecondary, fontSize: 12),
              ),
            ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<StudySubject?> promptNewSubject(
  BuildContext context,
  AppStore store, {
  StudySubject? existing,
}) async {
  final name = TextEditingController(text: existing?.name ?? '');
  var icon = existing?.icon ?? kStudyIcons.first;
  var color = existing?.color ?? NexusColors.boxPalette.first;
  final saved = await showNexusSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null ? '教科を追加' : '教科を編集',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                autofocus: existing == null,
                style: TextStyle(color: NexusColors.text),
                decoration: const InputDecoration(labelText: '教科名'),
              ),
              const SizedBox(height: 8),
              BoxLookPicker(
                icon: icon,
                color: color,
                choices: kStudyIconChoices,
                iconAreaHeight: 176,
                onIcon: (value) => setSheet(() => icon = value),
                onColor: (value) => setSheet(() => color = value),
              ),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(existing == null ? '追加' : '保存'),
              ),
            ],
          );
        },
      );
    },
  );
  final text = name.text.trim();
  name.dispose();
  if (saved != true || text.isEmpty) return null;
  if (existing == null) {
    final subject = store.addSubject(name: text, icon: icon, color: color);
    if (context.mounted) showNexusToast(context, store.lastToast);
    return subject;
  }
  store.updateSubject(existing.copyWith(name: text, icon: icon, color: color));
  if (context.mounted) showNexusToast(context, store.lastToast);
  return store.subjectById(existing.id);
}

Future<void> openSubjectWeek(BuildContext context, AppStore store, String subjectId) async {
  await showNexusSheet<void>(
    context: context,
    builder: (context) {
      return ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final subject = store.subjectById(subjectId);
          if (subject == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(context).canPop()) Navigator.pop(context);
            });
            return const SizedBox.shrink();
          }
          final hours = store.subjectWeekHours(subject.id);
          final peak = hours.fold<double>(0, (a, b) => a > b ? a : b);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(subject.icon, color: subject.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subject.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => promptNewSubject(context, store, existing: subject),
                    child: const Text('編集'),
                  ),
                ],
              ),
              Text(
                '今週 ${formatStudyHours(subject.weekHours)}',
                style: TextStyle(color: subject.color, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'この週に勉強した曜日',
                style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < 7; i++) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        weekLabels[i],
                        style: TextStyle(
                          color: hours[i] > 0 ? NexusColors.text : NexusColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: peak <= 0 ? 0 : hours[i] / peak,
                          color: subject.color,
                          backgroundColor: NexusColors.border.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 52,
                      child: Text(
                        hours[i] <= 0 ? '—' : formatStudyHours(hours[i]),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: hours[i] > 0 ? subject.color : NexusColors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      );
    },
  );
}

class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.hours, required this.color});

  final List<double> hours;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Container(
            width: 7,
            height: 7,
            margin: EdgeInsets.only(right: i == 6 ? 0 : 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hours[i] > 0 ? color : NexusColors.border,
            ),
          ),
      ],
    );
  }
}

Future<void> _addStudySession(BuildContext context, AppStore store) async {
  String? subjectId = store.subjects.isEmpty ? null : store.subjects.first.id;
  var minutes = 30;
  var focus = StudyFocus.high;
  final saved = await showNexusSheet<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('学習を追加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final s in store.subjects) ...[
                      ChoiceChip(
                        label: Text(s.name),
                        selected: subjectId == s.id,
                        selectedColor: s.color.withValues(alpha: 0.28),
                        labelStyle: TextStyle(
                          color: subjectId == s.id ? s.color : NexusColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => setSheet(() => subjectId = s.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ActionChip(
                      avatar: Icon(Icons.add, size: 16, color: NexusColors.cyan),
                      label: Text('＋ 教科を追加'),
                      labelStyle: TextStyle(
                        color: NexusColors.cyan,
                        fontWeight: FontWeight.w700,
                      ),
                      onPressed: () async {
                        final created = await promptNewSubject(context, store);
                        if (created != null) setSheet(() => subjectId = created.id);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              DurationMinutesPicker(
                minutes: minutes,
                onChanged: (value) => setSheet(() => minutes = value),
              ),
              const SizedBox(height: 8),
              Text('集中度', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final value in StudyFocus.values)
                    ChoiceChip(
                      label: Text(value.label),
                      selected: focus == value,
                      selectedColor: NexusColors.cyan.withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        color: focus == value ? NexusColors.cyan : NexusColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => setSheet(() => focus = value),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: subjectId == null ? null : () => Navigator.pop(context, true),
                child: const Text('記録する'),
              ),
            ],
          ),
          );
        },
      );
    },
  );
  if (saved == true && subjectId != null && minutes > 0) {
    store.addStudySession(subjectId: subjectId!, minutes: minutes, focus: focus);
    if (context.mounted) {
      nexusHaptic();
      showNexusToast(context, store.lastToast);
    }
  }
}

Future<void> _addAssignment(BuildContext context, AppStore store) async {
  if (store.subjects.isEmpty) {
    final created = await promptNewSubject(context, store);
    if (created == null || !context.mounted) return;
  }
  final title = TextEditingController();
  var subjectId = store.subjects.first.id;
  var due = store.focusedDate.add(const Duration(days: 3));
  final saved = await showNexusSheet<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('提出物を追加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: subjectId,
                dropdownColor: NexusColors.card,
                isExpanded: true,
                items: [
                  for (final s in store.subjects)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setSheet(() => subjectId = v ?? subjectId),
              ),
              TextField(
                controller: title,
                style: TextStyle(color: NexusColors.text),
                decoration: const InputDecoration(labelText: '提出物名'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: due,
                    firstDate: store.focusedDate.subtract(const Duration(days: 1)),
                    lastDate: DateTime(store.focusedDate.year + 2),
                  );
                  if (picked != null) setSheet(() => due = picked);
                },
                child: Text('期限  ${jpDate(due)}（${daysLeftLabel(due, store.focusedDate)}）'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('追加'),
              ),
            ],
          );
        },
      );
    },
  );
  if (saved == true && title.text.trim().isNotEmpty) {
    store.addAssignment(subjectId: subjectId, title: title.text.trim(), dueAt: due);
    if (context.mounted) showNexusToast(context, store.lastToast);
  }
  title.dispose();
}

Future<void> _addExam(BuildContext context, AppStore store) async {
  final title = TextEditingController();
  var examAt = store.focusedDate.add(const Duration(days: 14));
  final saved = await showNexusSheet<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('試験日を追加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                style: TextStyle(color: NexusColors.text),
                decoration: const InputDecoration(labelText: '科目・試験名'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: examAt,
                    firstDate: store.focusedDate,
                    lastDate: DateTime(store.focusedDate.year + 2),
                  );
                  if (picked != null) setSheet(() => examAt = picked);
                },
                child: Text('試験日  ${jpDate(examAt)}（${daysLeftLabel(examAt, store.focusedDate)}）'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('追加'),
              ),
            ],
          );
        },
      );
    },
  );
  if (saved == true && title.text.trim().isNotEmpty) {
    store.addExam(title: title.text.trim(), examAt: examAt);
    if (context.mounted) showNexusToast(context, store.lastToast);
  }
  title.dispose();
}

Future<void> _addGoal(BuildContext context, AppStore store) async {
  final title = TextEditingController();
  final target = TextEditingController();
  final steps = [TextEditingController(text: '基礎')];
  var due = DateTime(store.focusedDate.year, store.focusedDate.month + 3, store.focusedDate.day);
  final saved = await showNexusSheet<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('目標ロードマップ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'ゴールまでの地点を並べて、進んだらタップでチェックできます。',
                  style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '目標名（例: TOEIC 800）'),
                ),
                TextField(
                  controller: target,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '目標値（任意）'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: due,
                      firstDate: store.focusedDate,
                      lastDate: DateTime(store.focusedDate.year + 3),
                    );
                    if (picked != null) setSheet(() => due = picked);
                  },
                  child: Text('期限  ${jpDate(due)}'),
                ),
                const SizedBox(height: 10),
                Text('ルート', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
                for (var i = 0; i < steps.length; i++)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: NexusColors.cyan.withValues(alpha: 0.16),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(fontSize: 11, color: NexusColors.cyan, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: steps[i],
                          style: TextStyle(color: NexusColors.text),
                          decoration: InputDecoration(labelText: '地点 ${i + 1}'),
                        ),
                      ),
                      IconButton(
                        onPressed: steps.length == 1
                            ? null
                            : () => setSheet(() {
                                steps[i].dispose();
                                steps.removeAt(i);
                              }),
                        icon: Icon(Icons.remove_circle_outline, size: 18, color: NexusColors.textMuted),
                      ),
                    ],
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setSheet(() => steps.add(TextEditingController())),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('地点を足す'),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('ロードマップを作る'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  if (saved == true && title.text.trim().isNotEmpty) {
    store.addGoal(
      title: title.text.trim(),
      current: 0,
      target: int.tryParse(target.text) ?? 0,
      dueAt: due,
      subGoalTitles: [for (final c in steps) c.text],
    );
    if (context.mounted) showNexusToast(context, store.lastToast);
  }
  title.dispose();
  target.dispose();
  for (final c in steps) {
    c.dispose();
  }
}

Future<Uint8List?> _takeProblemPhoto(BuildContext context) async {
  final picker = ImagePicker();
  Future<Uint8List?> from(ImageSource source) async {
    final file = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    if (file == null) return null;
    return file.readAsBytes();
  }

  try {
    final bytes = await from(ImageSource.camera);
    if (bytes != null) return bytes;
  } catch (_) {
    if (context.mounted) {
      showNexusToast(context, 'カメラを起動できないので、ギャラリーから選びます');
    }
  }
  try {
    return await from(ImageSource.gallery);
  } catch (_) {
    if (context.mounted) {
      showNexusToast(context, '写真を取得できませんでした');
    }
    return null;
  }
}

Future<void> _recordProblem(BuildContext context, AppStore store) async {
  final photo = await _takeProblemPhoto(context);
  if (photo == null || !context.mounted) return;

  final title = TextEditingController();
  final answer = TextEditingController();
  if (store.subjects.isEmpty) {
    final created = await promptNewSubject(context, store);
    if (created == null || !context.mounted) {
      title.dispose();
      answer.dispose();
      return;
    }
  }
  var subjectId = store.subjects.first.id;
  final saved = await showNexusSheet<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('問題を記録', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(photo, height: 140, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: subjectId,
                dropdownColor: NexusColors.card,
                isExpanded: true,
                items: [
                  for (final s in store.subjects)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setSheet(() => subjectId = v ?? subjectId),
              ),
              TextField(
                controller: title,
                style: TextStyle(color: NexusColors.text),
                decoration: const InputDecoration(labelText: '問題名（任意）'),
              ),
              TextField(
                controller: answer,
                minLines: 2,
                maxLines: 4,
                style: TextStyle(color: NexusColors.text),
                decoration: const InputDecoration(labelText: '解答（任意）'),
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
    },
  );
  if (saved == true) {
    final name = title.text.trim().isEmpty ? '問題 ${store.problems.length + 1}' : title.text.trim();
    store.addProblem(subjectId: subjectId, title: name, photoBytes: photo, answer: answer.text.trim());
    if (context.mounted) showNexusToast(context, store.lastToast);
  }
  title.dispose();
  answer.dispose();
}

Future<void> _openReview(BuildContext context, AppStore store) async {
  final due = store.reviewCards
      .where((c) => c.status == 'pending' && !c.dueAt.isAfter(store.focusedDate))
      .toList();
  await showNexusSheet<void>(
    context: context,
    builder: (context) {
      if (due.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Text('今日の復習はありません。', style: TextStyle(color: NexusColors.textSecondary)),
        );
      }
      final card = due.first;
      final problem = store.problems.firstWhere((p) => p.id == card.problemId);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (problem.photoBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(problem.photoBytes!, height: 160, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
          ],
          Text(problem.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (problem.answer.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(problem.answer, style: TextStyle(color: NexusColors.textSecondary)),
          ],
          const SizedBox(height: 6),
          Text('${card.intervalStep}日後カード', style: TextStyle(color: NexusColors.textMuted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final rating in ReviewRating.values)
                OutlinedButton(
                  onPressed: () {
                    store.rateReview(card.id, rating);
                    Navigator.pop(context);
                  },
                  child: Text(switch (rating) {
                    ReviewRating.again => 'もう一度',
                    ReviewRating.hard => '難しい',
                    ReviewRating.normal => '普通',
                    ReviewRating.easy => '簡単',
                  }),
                ),
            ],
          ),
        ],
      );
    },
  );
}
