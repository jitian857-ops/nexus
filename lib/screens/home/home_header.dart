import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../widgets/nexus_logo.dart';
import '../../widgets/nexus_nav_bar.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

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
                store.userName,
                style: const TextStyle(
                  color: NexusColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    'Lv.${store.level}',
                    style: const TextStyle(
                      color: NexusColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: NexusColors.purple.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: NexusColors.purple.withValues(alpha: 0.55),
              ),
            ),
            child: const Icon(
              Icons.push_pin_rounded,
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
              const Icon(Icons.calendar_month_rounded, size: 14, color: NexusColors.cyan),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: NexusColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.expand_more_rounded, size: 16, color: NexusColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
