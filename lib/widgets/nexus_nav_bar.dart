import 'package:flutter/material.dart';

import '../app/motion.dart';
import '../app/theme.dart';
import 'ui_bits.dart';

class NexusTab {
  NexusTab._();

  static const home = 0;
  static const study = 1;
  static const life = 2;
  static const money = 3;
  static const settings = 4;
}

class NexusNavBar extends StatelessWidget {
  const NexusNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.menu_book_rounded, 'Study'),
    (Icons.favorite_rounded, 'Life'),
    (Icons.account_balance_wallet_rounded, 'Money'),
    (Icons.settings_rounded, '設定'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottom > 0 ? bottom : 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: NexusColors.navBar,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: NexusColors.hairline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: NexusColors.isLight ? 0.08 : 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slot = constraints.maxWidth / _items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: NexusMotion.duration(context, NexusMotion.med),
                    curve: NexusMotion.curve,
                    left: slot * currentIndex + 6,
                    top: 6,
                    bottom: 6,
                    width: slot - 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: NexusColors.cyan.withValues(alpha: NexusColors.isLight ? 0.14 : 0.18),
                        border: Border.all(color: NexusColors.cyan.withValues(alpha: 0.35)),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Expanded(
                          child: _NavItem(
                            icon: _items[i].$1,
                            label: _items[i].$2,
                            selected: currentIndex == i,
                            onTap: () {
                              nexusHaptic();
                              onTap(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? NexusColors.cyan : NexusColors.textMuted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: selected ? 22 : 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
