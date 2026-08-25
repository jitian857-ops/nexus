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
          const Text('Nexusを、自分らしく。', style: TextStyle(color: NexusColors.textSecondary)),
          const SizedBox(height: 14),
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
                      Text('Lv.${store.level}', style: const TextStyle(color: NexusColors.gold, fontSize: 12, letterSpacing: 0.4)),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _editProfile(context, store),
                  child: const Text('プロフィールを編集'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('設定項目', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Item(
                  icon: Icons.grid_view_rounded,
                  title: 'ホームをカスタマイズ',
                  subtitle: 'ウィジェットの順とピン留め',
                  onTap: () => _open(context, 'ホームをカスタマイズ', 'Homeのウィジェットは今日の目標・今月の残高・今週の学習時間です。'),
                ),
                _ToggleItem(
                  icon: Icons.notifications_rounded,
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
                  title: '連携',
                  subtitle: 'カレンダー・時間割・ヘルスは明示許可',
                  onTap: () => _open(context, '連携', '端末カレンダー、学校時間割、ヘルスデータはまだ接続していません。許可するまで読み取りません。'),
                ),
                _ToggleItem(
                  icon: Icons.palette_rounded,
                  title: '外観',
                  subtitle: 'Reduce Motion',
                  value: s.reduceMotion,
                  onChanged: (v) => store.updateSettings(s.copyWith(reduceMotion: v)),
                ),
                _Item(
                  icon: Icons.lock_rounded,
                  title: 'セキュリティ',
                  subtitle: 'アプリロック設定',
                  onTap: () => _open(context, 'セキュリティ', '端末認証とアプリロックは次のフェーズで接続します。通信は暗号化前提です。'),
                ),
                _Item(
                  icon: Icons.help_outline,
                  title: 'ヘルプ',
                  subtitle: 'FAQ と問い合わせ',
                  onTap: () => _open(context, 'ヘルプ', 'Nexus OS 0.1 のFAQです。投資・借入・購入の誘導はありません。'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const GlassCard(
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
          const Center(
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
            const Text('プロフィール', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            TextField(controller: controller, style: const TextStyle(color: NexusColors.text)),
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
          Text(body, style: const TextStyle(color: NexusColors.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: NexusColors.cyan),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(color: NexusColors.textMuted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: NexusColors.textMuted),
      onTap: onTap,
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: NexusColors.cyan),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(color: NexusColors.textMuted, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}
