import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/negumo.dart';
import '../../widgets/ui_bits.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final memory = [
      if (store.settings.memoryStudy) '学習',
      if (store.settings.memorySchedule) '予定',
      if (store.settings.memoryMoney) 'お金',
      if (store.settings.memoryLife) '生活',
    ].join('・');

    return PageScaffold(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              children: [
                Row(
                  children: [
                    const GradientTitle('Negumo'),
                    const Spacer(),
                    Icon(Icons.lock, size: 14, color: NexusColors.green.withValues(alpha: 0.9)),
                    const SizedBox(width: 4),
                    Text('セキュア接続中', style: TextStyle(color: NexusColors.green, fontSize: 11)),
                  ],
                ),
                Text('次の一歩を、一緒に考える。', style: TextStyle(color: NexusColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  'Negumo — powered by Nexus AI',
                  style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 12),
                const Center(child: NegumoMascot(size: 168, action: NegumoAction.wave)),
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.messages.last.text, style: const TextStyle(height: 1.4)),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          onPressed: () => _confirmPlan(context, store),
                          child: const Text('計画を見直す'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Quick(label: '今日何すればいい？', icon: Icons.today, onTap: () => _send(store, '今日何すればいい？')),
                    _Quick(label: '学習計画を作る', icon: Icons.menu_book, onTap: () => _send(store, '学習計画を作る')),
                    _Quick(label: '予定を整理', icon: Icons.checklist, onTap: () => _send(store, '予定を整理')),
                    _Quick(label: '相談する', icon: Icons.chat_bubble_outline, onTap: () => _send(store, '相談する')),
                  ],
                ),
                const SizedBox(height: 12),
                if (store.proposal != null)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ネグモの提案', style: TextStyle(color: NexusColors.cyan, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(store.proposal!.summary, style: const TextStyle(height: 1.4)),
                        const SizedBox(height: 6),
                        Text(
                          '根拠: ${store.proposal!.rationale}',
                          style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          store.proposal!.status == ProposalStatus.approved
                              ? '承認済み'
                              : store.proposal!.status == ProposalStatus.rejected
                                  ? '未反映'
                                  : '未承認（データはまだ変わっていません）',
                          style: TextStyle(color: NexusColors.textSecondary, fontSize: 12),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: store.proposal!.status == ProposalStatus.pending
                                ? () => _confirmPlan(context, store)
                                : null,
                            child: const Text('プランを確認 >'),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: NexusColors.cyan),
                    const SizedBox(width: 6),
                    Text('記憶：$memoryのみ', style: TextStyle(color: NexusColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    style: TextStyle(color: NexusColors.text),
                    decoration: InputDecoration(
                      hintText: 'ネグモに聞く...',
                      hintStyle: TextStyle(color: NexusColors.textMuted),
                      filled: true,
                      fillColor: NexusColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: NexusColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    final text = _input.text.trim();
                    if (text.isEmpty) return;
                    _send(store, text);
                    _input.clear();
                  },
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _send(AppStore store, String text) {
    store.sendUserMessage(text);
    store.createDefaultProposal();
  }

  Future<void> _confirmPlan(BuildContext context, AppStore store) async {
    final p = store.proposal;
    if (p == null) return;
    final schedule = store.schedules.cast<ScheduleItem?>().firstWhere(
          (s) => s?.id == p.scheduleId,
          orElse: () => null,
        );
    final result = await showNexusSheet<String>(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('プランを確認', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(p.summary),
            const SizedBox(height: 8),
            if (schedule != null)
              Text(
                '変更: ${schedule.title} ${schedule.startAt.hour}:${schedule.startAt.minute.toString().padLeft(2, '0')} → ${p.newStartAt.hour}:${p.newStartAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: NexusColors.textSecondary),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'ok'),
              child: const Text('承認して反映'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'no'),
              child: const Text('今は反映しない'),
            ),
          ],
        );
      },
    );
    if (result == 'ok') {
      store.approveProposal();
      if (context.mounted) showNexusToast(context, store.lastToast);
    } else if (result == 'no') {
      store.rejectProposal();
      if (context.mounted) showNexusToast(context, store.lastToast);
    }
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              children: [
                Icon(icon, color: NexusColors.cyan, size: 18),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
