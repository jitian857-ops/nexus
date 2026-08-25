import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../domain/money_calc.dart';
import '../../widgets/duration_picker.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/ui_bits.dart';
import 'focus_timer_page.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final store = AppScope.of(context);
      if (store.timerRunning) setState(() {});
    });
  }

  @override
  void dispose() {
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
            style: const TextStyle(color: NexusColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          _TotalStudyCard(store: store),
          const SizedBox(height: 12),
          const SectionRow(title: '科目別・今週の勉強時間'),
          const SizedBox(height: 8),
          if (store.subjects.isEmpty)
            const SizedBox(
              height: 108,
              child: Center(
                child: Text('教科はまだありません', style: TextStyle(color: NexusColors.textMuted)),
              ),
            )
          else
            SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: store.subjects.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final s = store.subjects[i];
                return GlassCard(
                  child: SizedBox(
                    width: 132,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(s.icon, color: s.color, size: 18),
                        const Spacer(),
                        Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          '${s.weekHours}h',
                          style: TextStyle(color: s.color, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
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
                      const Text('復習カード', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '今日のキュー ${store.reviewDueCount()}枚',
                        style: const TextStyle(color: NexusColors.textSecondary),
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
                  const Text('目標はまだありません', style: TextStyle(color: NexusColors.textMuted)),
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
                  const Text('試験日はまだありません', style: TextStyle(color: NexusColors.textMuted))
                else
                  SizedBox(
                    height: 128,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: store.exams.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        return SizedBox(
                          width: 96,
                          child: _ExamRing(exam: store.exams[i], today: store.focusedDate),
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
                const SizedBox(height: 4),
                const Text(
                  '写真で記録すると、1日後と5日後の復習カードが作られます。',
                  style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                ),
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
              _Hours(label: '今週', value: '${store.weekStudyHours}h', color: NexusColors.purple),
              const SizedBox(width: 24),
              _Hours(label: '累計', value: '${store.totalStudyHours}h', color: NexusColors.cyan),
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
                    Text(s.name, style: const TextStyle(color: NexusColors.textMuted, fontSize: 11)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 126,
            child: CustomPaint(
              painter: _StackedBarPainter(
                stacks: store.weekStackedHours(),
                colors: [for (final s in store.subjects) s.color],
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final label in weekLabels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: NexusColors.textMuted, fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StackedBarPainter extends CustomPainter {
  _StackedBarPainter({required this.stacks, required this.colors});

  final List<List<double>> stacks;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (stacks.isEmpty) return;
    var maxTotal = 0.0;
    for (final day in stacks) {
      final total = day.fold<double>(0, (a, b) => a + b);
      if (total > maxTotal) maxTotal = total;
    }
    if (maxTotal <= 0) maxTotal = 1;

    final slot = size.width / stacks.length;
    final barWidth = slot * 0.48;
    for (var i = 0; i < stacks.length; i++) {
      final x = slot * i + (slot - barWidth) / 2;
      var y = size.height;
      for (var s = 0; s < stacks[i].length; s++) {
        final hours = stacks[i][s];
        if (hours <= 0) continue;
        final h = size.height * (hours / maxTotal);
        y -= h;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, h),
          const Radius.circular(3),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = colors[s % colors.length],
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter oldDelegate) {
    return oldDelegate.stacks != stacks || oldDelegate.colors != colors;
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openFocusTimer(context),
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        child: Column(
          children: [
            const SectionRow(title: '集中タイマー'),
            const SizedBox(height: 8),
            Text(
              mmss(store.timerRemainingSeconds()),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'タップして全画面で集中',
              style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
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
                  style: const TextStyle(color: NexusColors.textMuted, fontSize: 11),
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
                style: const TextStyle(color: NexusColors.textMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalBlock extends StatelessWidget {
  const _GoalBlock({required this.goal, required this.store});

  final StudyGoal goal;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(goal.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          '現在 ${goal.current}  /  目標 ${goal.target}  /  ${jpDate(goal.dueAt)}まで',
          style: const TextStyle(color: NexusColors.textSecondary, fontSize: 12),
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
        const SizedBox(height: 8),
        for (var i = 0; i < goal.subGoals.length; i++)
          if (goal.subGoals[i].title.trim().isNotEmpty)
            InkWell(
              onTap: () => store.toggleSubGoal(goal.id, i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      goal.subGoals[i].done
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 18,
                      color: goal.subGoals[i].done ? NexusColors.cyan : NexusColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'サブゴール ${i + 1}  ${goal.subGoals[i].title}',
                      style: TextStyle(
                        color: goal.subGoals[i].done ? NexusColors.textSecondary : NexusColors.text,
                        decoration: goal.subGoals[i].done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
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
          progress: days <= 0 ? 1 : (1 - days / 40).clamp(0.1, 1),
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
          style: const TextStyle(color: NexusColors.textMuted, fontSize: 10),
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
        Text(label, style: const TextStyle(color: NexusColors.textMuted, fontSize: 12)),
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
                      const Icon(Icons.check_circle, color: NexusColors.cyan, size: 16),
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
                    style: const TextStyle(color: NexusColors.textMuted, fontSize: 11),
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

Future<StudySubject?> promptNewSubject(BuildContext context, AppStore store) async {
  final name = TextEditingController();
  final saved = await showNexusSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('教科を追加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            autofocus: true,
            style: const TextStyle(color: NexusColors.text),
            decoration: const InputDecoration(labelText: '教科名'),
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
  final text = name.text.trim();
  name.dispose();
  if (saved == true && text.isNotEmpty) {
    final subject = store.addSubject(name: text);
    if (context.mounted) showNexusToast(context, store.lastToast);
    return subject;
  }
  return null;
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
                      avatar: const Icon(Icons.add, size: 16, color: NexusColors.cyan),
                      label: const Text('＋ 教科を追加'),
                      labelStyle: const TextStyle(
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
              const Text('集中度', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
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
  if (saved == true && subjectId != null) {
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
              const Text('提出物を追加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                style: const TextStyle(color: NexusColors.text),
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
              const Text('試験日を追加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                style: const TextStyle(color: NexusColors.text),
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
  final current = TextEditingController(text: '0');
  final target = TextEditingController(text: '100');
  final subs = List.generate(4, (_) => TextEditingController());
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
                const Text('目標を追加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  style: const TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '目標名（例: TOEIC 800）'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: current,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: NexusColors.text),
                        decoration: const InputDecoration(labelText: '現在'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: target,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: NexusColors.text),
                        decoration: const InputDecoration(labelText: '目標値'),
                      ),
                    ),
                  ],
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
                const Text('サブゴール（4つ）', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
                for (var i = 0; i < 4; i++)
                  TextField(
                    controller: subs[i],
                    style: const TextStyle(color: NexusColors.text),
                    decoration: InputDecoration(labelText: 'サブゴール ${i + 1}'),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('追加'),
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
      current: int.tryParse(current.text) ?? 0,
      target: int.tryParse(target.text) ?? 100,
      dueAt: due,
      subGoalTitles: [for (final c in subs) c.text],
    );
    if (context.mounted) showNexusToast(context, store.lastToast);
  }
  title.dispose();
  current.dispose();
  target.dispose();
  for (final c in subs) {
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
  if (store.subjects.isEmpty) {
    final created = await promptNewSubject(context, store);
    if (created == null || !context.mounted) {
      title.dispose();
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
                style: const TextStyle(color: NexusColors.text),
                decoration: const InputDecoration(labelText: '問題名（任意）'),
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
    store.addProblem(subjectId: subjectId, title: name, photoBytes: photo);
    if (context.mounted) showNexusToast(context, store.lastToast);
  }
  title.dispose();
}

Future<void> _openReview(BuildContext context, AppStore store) async {
  final due = store.reviewCards
      .where((c) => c.status == 'pending' && !c.dueAt.isAfter(store.focusedDate))
      .toList();
  await showNexusSheet<void>(
    context: context,
    builder: (context) {
      if (due.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(12),
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
          const SizedBox(height: 6),
          Text('${card.intervalStep}日後カード', style: const TextStyle(color: NexusColors.textMuted)),
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
