import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../widgets/duration_picker.dart';
import '../../widgets/progress_ring.dart';

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

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
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
    final remaining = store.timerRemainingSeconds();
    final total = store.timerTotalSeconds == 0 ? 1 : store.timerTotalSeconds;
    final progress = 1 - remaining / total;
    final subject = store.subjectById(store.timerSubjectId ?? store.nextStudySubjectId);

    return PopScope(
      canPop: !store.timerRunning,
      child: Scaffold(
      backgroundColor: const Color(0xFF05080E),
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
                    style: const TextStyle(
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
                            Text(
                              store.timerRunning ? '集中中' : '停止中',
                              style: const TextStyle(color: NexusColors.textMuted),
                            ),
                          ],
                        ),
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
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: store.timerRunning ? store.pauseTimer : store.startTimer,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(store.timerRunning ? '一時停止' : '開始'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _finish(context, store),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
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
    if (store.timerElapsedSeconds() <= 0) {
      store.finishTimer();
      if (context.mounted) Navigator.pop(context);
      return;
    }

    final focus = await showModalBottomSheet<StudyFocus>(
      context: context,
      backgroundColor: NexusColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '集中度は？',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              for (final value in StudyFocus.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, value),
                    child: Text(value.label),
                  ),
                ),
            ],
          ),
        );
      },
    );

    store.finishTimer(focus: focus ?? StudyFocus.high);
    if (context.mounted) Navigator.pop(context);
  }
}
