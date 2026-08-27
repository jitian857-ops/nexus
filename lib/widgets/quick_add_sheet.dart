import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/app_store.dart';
import '../screens/life/checkin_sheet.dart';
import '../screens/money/money_forms.dart';
import '../screens/study/focus_timer_page.dart';
import 'schedule_sheet.dart';
import 'ui_bits.dart';

Future<void> openQuickAdd(BuildContext context) {
  final store = AppScope.of(context);
  return showNexusSheet<void>(
    context: context,
    builder: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('追加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('今日必要なものだけを足す', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        _QuickTile(
          icon: Icons.event_rounded,
          label: '予定',
          onTap: () {
            Navigator.pop(context);
            openScheduleEditor(context);
          },
        ),
        _QuickTile(
          icon: Icons.timer_rounded,
          label: '勉強',
          onTap: () {
            Navigator.pop(context);
            openFocusTimer(context);
          },
        ),
        _QuickTile(
          icon: Icons.payments_rounded,
          label: '支出',
          onTap: () {
            Navigator.pop(context);
            openQuickSpend(context, store);
          },
        ),
        _QuickTile(
          icon: Icons.spa_rounded,
          label: '習慣',
          onTap: () {
            Navigator.pop(context);
            openCheckIn(context, store);
          },
        ),
      ],
    ),
  );
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: NexusColors.sky.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              AccentIcon(icon),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
