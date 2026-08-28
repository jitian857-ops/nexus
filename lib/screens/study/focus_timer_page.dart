import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../widgets/duration_picker.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/ui_bits.dart';
import 'study_screen.dart';

Future<void> openFocusTimer(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, _) {
        return FadeTransition(
          opacity: animation,
          child: const FocusTimerPage(),
        );
      },
    ),
  );
}

class FocusTimerPage extends StatefulWidget {
  const FocusTimerPage({super.key});

  @override
  State<FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends State<FocusTimerPage> {
  Timer? _tick;
  var _completing = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {});
    final store = AppScope.of(context);
    if (_completing) return;
    if (store.timerElapsedSeconds() <= 0) return;
    if (store.timerRemainingSeconds() > 0) return;
    _completing = true;
    store.pauseTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _complete(context, store, timedOut: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final remaining = store.timerRemainingSeconds();
    final total = store.timerTotalSeconds == 0 ? 1 : store.timerTotalSeconds;
    final progress = 1 - remaining / total;
    final selectedId = store.selectedTimerSubjectId;
    final subject = selectedId == null ? null : store.subjectById(selectedId);

    return PopScope(
      canPop: !store.timerRunning,
      child: Scaffold(
      backgroundColor: NexusColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: store.timerRunning ? null : () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: store.timerRunning ? NexusColors.textMuted : NexusColors.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    subject?.name ?? '集中タイマー',
                    style: TextStyle(
                      color: NexusColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          IgnorePointer(
                            child: Container(
                              width: 300,
                              height: 300,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    (store.timerRunning ? NexusColors.cyan : NexusColors.purple)
                                        .withValues(alpha: store.timerRunning ? 0.14 : 0.08),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          ProgressRing(
                            progress: progress.clamp(0, 1),
                            size: 220,
                            stroke: 14,
                            animate: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  mmss(remaining),
                                  style: TextStyle(
                                    color: NexusColors.text,
                                    fontSize: remaining >= 3600 ? 36 : 48,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      DurationMinutesPicker(
                        minutes: (store.timerTotalSeconds / 60).round().clamp(
                          kMinStudyDurationMinutes,
                          kMaxStudyDurationMinutes,
                        ),
                        onChanged: store.setTimerMinutes,
                        enabled: !store.timerRunning,
                      ),
                      const SizedBox(height: 10),
                      _TimerPresets(
                        store: store,
                        currentMinutes: (store.timerTotalSeconds / 60).round(),
                        enabled: !store.timerRunning,
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '教科',
                          style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _TimerSubjectPicker(
                        store: store,
                        selectedId: selectedId,
                        enabled: !store.timerRunning,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: store.timerRunning
                          ? store.pauseTimer
                          : (store.timerTotalSeconds <= 0 || selectedId == null ? null : store.startTimer),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(store.timerRunning ? '一時停止' : '開始'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _completing ? null : () => _finish(context, store),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('終了'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Future<void> _finish(BuildContext context, AppStore store) async {
    if (_completing) return;
    if (store.timerElapsedSeconds() <= 0) {
      store.finishTimer();
      if (context.mounted) Navigator.pop(context);
      return;
    }
    _completing = true;
    store.pauseTimer();
    await _complete(context, store, timedOut: false);
  }

  Future<void> _complete(BuildContext context, AppStore store, {required bool timedOut}) async {
    _tick?.cancel();
    unawaited(nexusTimerDoneFeedback());

    StudyFocus focus = StudyFocus.high;
    if (context.mounted) {
      final picked = await showGeneralDialog<StudyFocus>(
        context: context,
        barrierDismissible: true,
        barrierLabel: '完了',
        barrierColor: const Color(0xCC05080E),
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, _) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Material(
                    color: NexusColors.card,
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: NexusColors.cyan.withValues(alpha: 0.14),
                              boxShadow: [
                                BoxShadow(
                                  color: NexusColors.cyan.withValues(alpha: 0.28),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                            child: Icon(Icons.check_rounded, color: NexusColors.cyan, size: 40),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            timedOut ? '集中完了' : '学習を記録',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: NexusColors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${formatStudyHours(store.timerElapsedSeconds() / 3600)} がんばった',
                            style: TextStyle(color: NexusColors.textSecondary),
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '集中度は？',
                              style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final value in StudyFocus.values)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SizedBox(
                                width: double.infinity,
                                child: value == StudyFocus.high || value == StudyFocus.peak
                                    ? FilledButton(
                                        onPressed: () => Navigator.pop(context, value),
                                        child: Text(value.label),
                                      )
                                    : OutlinedButton(
                                        onPressed: () => Navigator.pop(context, value),
                                        child: Text(value.label),
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
      if (picked != null) focus = picked;
    }

    store.finishTimer(focus: focus);
    if (context.mounted) Navigator.pop(context);
  }
}

class _TimerSubjectPicker extends StatelessWidget {
  const _TimerSubjectPicker({
    required this.store,
    required this.selectedId,
    required this.enabled,
  });

  final AppStore store;
  final String? selectedId;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (store.subjects.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: Icon(Icons.add, size: 16, color: NexusColors.cyan),
          label: Text('教科を追加'),
          labelStyle: TextStyle(color: NexusColors.cyan, fontWeight: FontWeight.w700),
          onPressed: enabled ? () => _addSubject(context) : null,
        ),
      );
    }
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final s in store.subjects) ...[
            ChoiceChip(
              label: Text(s.name),
              avatar: Icon(s.icon, size: 16, color: selectedId == s.id ? s.color : NexusColors.textMuted),
              selected: selectedId == s.id,
              selectedColor: s.color.withValues(alpha: 0.28),
              labelStyle: TextStyle(
                color: selectedId == s.id ? s.color : NexusColors.text,
                fontWeight: FontWeight.w700,
              ),
              onSelected: enabled ? (_) => store.setTimerSubject(s.id) : null,
            ),
            const SizedBox(width: 8),
          ],
          ActionChip(
            avatar: Icon(Icons.add, size: 16, color: NexusColors.cyan),
            label: Text('＋ 教科を追加'),
            labelStyle: TextStyle(color: NexusColors.cyan, fontWeight: FontWeight.w700),
            onPressed: enabled ? () => _addSubject(context) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _addSubject(BuildContext context) async {
    final created = await promptNewSubject(context, store);
    if (created != null) store.setTimerSubject(created.id);
  }
}

class _TimerPresets extends StatelessWidget {
  const _TimerPresets({
    required this.store,
    required this.currentMinutes,
    required this.enabled,
  });

  final AppStore store;
  final int currentMinutes;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('よく使う時間', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final minutes in store.settings.timerPresets)
              GestureDetector(
                onLongPress: enabled ? () => store.removeTimerPreset(minutes) : null,
                child: ActionChip(
                  label: Text(studyGoalLabel(minutes)),
                  backgroundColor: currentMinutes == minutes
                      ? NexusColors.cyan.withValues(alpha: 0.22)
                      : null,
                  labelStyle: TextStyle(
                    color: currentMinutes == minutes ? NexusColors.cyan : NexusColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                  onPressed: enabled ? () => store.setTimerMinutes(minutes) : null,
                ),
              ),
            ActionChip(
              avatar: Icon(Icons.add_rounded, size: 16, color: NexusColors.cyan),
              label: const Text('追加'),
              labelStyle: TextStyle(color: NexusColors.cyan, fontWeight: FontWeight.w700),
              onPressed: !enabled || currentMinutes <= 0
                  ? null
                  : () => store.addTimerPreset(currentMinutes),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'チップを押すとリールがその時間になります。長押しで削除。',
          style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
