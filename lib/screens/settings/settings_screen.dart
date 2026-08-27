import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_store.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/nexus_logo.dart';
import '../../widgets/ui_bits.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.settings;

    return PageScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const GradientTitle('設定'),
          const SizedBox(height: 4),
          Text('Nexusを、自分らしく。', style: TextStyle(color: NexusColors.textSecondary)),
          const SizedBox(height: 14),
          GlassCard(
            glowColor: NexusColors.cyan,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('テーマ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  NexusPalette.byId(s.themeId).label,
                  style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: [
                    for (final palette in NexusPalette.all)
                      _ThemeSwatch(
                        palette: palette,
                        selected: s.themeId == palette.id,
                        onTap: () => store.updateSettings(s.copyWith(themeId: palette.id)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Row(
              children: [
                const NexusLogo(size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Text('Lv.${store.level}', style: TextStyle(color: NexusColors.gold, fontSize: 12, letterSpacing: 0.4)),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _editProfile(context, store),
                  child: Text('プロフィールを編集'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('設定項目', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Item(
                  icon: Icons.grid_view_rounded,
                  color: NexusColors.cyan,
                  title: 'ホームをカスタマイズ',
                  subtitle: 'ウィジェットの順とピン留め',
                  onTap: () => _open(context, 'ホームをカスタマイズ', 'Homeのウィジェットは今日の目標・今月の残高・今週の学習時間です。'),
                ),
                _ToggleItem(
                  icon: Icons.notifications_rounded,
                  color: NexusColors.gold,
                  title: '通知',
                  subtitle: '課題・予定・復習のリマインド',
                  value: s.notifyTasks && s.notifySchedule && s.notifyReview && s.notifyNegumo,
                  onChanged: (v) => store.updateSettings(
                    s.copyWith(
                      notifyTasks: v,
                      notifySchedule: v,
                      notifyReview: v,
                      notifyNegumo: v,
                    ),
                  ),
                ),
                _Item(
                  icon: Icons.calendar_month,
                  color: NexusColors.green,
                  title: '連携',
                  subtitle: 'カレンダー・時間割・ヘルスは明示許可',
                  onTap: () => _open(context, '連携', '端末カレンダー、学校時間割、ヘルスデータはまだ接続していません。許可するまで読み取りません。'),
                ),
                _ToggleItem(
                  icon: Icons.motion_photos_off_rounded,
                  color: NexusColors.purple,
                  title: '動きを減らす',
                  subtitle: '画面のアニメーションを抑える',
                  value: s.reduceMotion,
                  onChanged: (v) => store.updateSettings(s.copyWith(reduceMotion: v)),
                ),
                _Item(
                  icon: Icons.lock_rounded,
                  color: NexusColors.expense,
                  title: 'セキュリティ',
                  subtitle: 'アプリロック設定',
                  onTap: () => _open(context, 'セキュリティ', '端末認証とアプリロックは次のフェーズで接続します。通信は暗号化前提です。'),
                ),
                _Item(
                  icon: Icons.help_outline,
                  color: NexusColors.periwinkle,
                  title: 'ヘルプ',
                  subtitle: 'FAQ と問い合わせ',
                  onTap: () => _open(context, 'ヘルプ', 'Nexus OS 0.1 のFAQです。投資・借入・購入の誘導はありません。'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: NexusColors.cyan),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'あなたのデータは、あなたが管理します。何を保存するかをいつでも確認・変更できます。',
                    style: TextStyle(height: 1.4, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('Nexus OS 0.1', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, AppStore store) async {
    final controller = TextEditingController(text: store.userName);
    final saved = await showNexusSheet<bool>(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('プロフィール', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            TextField(controller: controller, style: TextStyle(color: NexusColors.text)),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
          ],
        );
      },
    );
    if (saved == true && controller.text.trim().isNotEmpty) {
      store.setUserName(controller.text.trim());
    }
    controller.dispose();
  }

  Future<void> _open(BuildContext context, String title, String body) {
    return showNexusSheet<void>(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: NexusColors.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final NexusPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.background, palette.cyan, palette.purple],
                ),
                border: Border.all(
                  color: selected ? palette.cyan : palette.border,
                  width: selected ? 2.5 : 1,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: palette.cyan.withValues(alpha: 0.35), blurRadius: 10)]
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              palette.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? NexusColors.text : NexusColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _SettingsIcon(icon: icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: NexusColors.textMuted),
      onTap: onTap,
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: _SettingsIcon(icon: icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}
