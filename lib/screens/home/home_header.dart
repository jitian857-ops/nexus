import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../widgets/nexus_logo.dart';
import '../../widgets/nexus_nav_bar.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'こんばんは';
    if (hour < 11) return 'おはよう';
    if (hour < 18) return 'こんにちは';
    return 'こんばんは';
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);

    return Row(
      children: [
        const NexusLogo(size: 46),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()}、',
                style: TextStyle(
                  color: NexusColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                store.userName,
                style: TextStyle(
                  color: NexusColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    'Lv.${store.level}',
                    style: TextStyle(
                      color: NexusColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: store.levelProgress,
                        minHeight: 4,
                        backgroundColor: NexusColors.border,
                        color: NexusColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: _DateChip(
              label: jpDate(store.focusedDate),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: store.focusedDate,
                  firstDate: DateTime(store.focusedDate.year - 1, 1, 1),
                  lastDate: DateTime(store.focusedDate.year + 1, 12, 31),
                );
                if (picked != null) store.setFocusedDate(picked);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => store.goTo(NexusTab.settings),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  NexusColors.purple.withValues(alpha: 0.24),
                  NexusColors.purple.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: NexusColors.purple.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 16,
              color: NexusColors.purple,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: NexusColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NexusColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 14, color: NexusColors.cyan),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: NexusColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.expand_more_rounded, size: 16, color: NexusColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
