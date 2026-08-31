import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../cloud/nexus_cloud.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/nexus_logo.dart';
import '../../widgets/ui_bits.dart';
import 'mailbox_page.dart';
import 'vault_page.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final cloud = CloudScope.of(context);
    final s = store.settings;

    return PageScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const GradientTitle('設定'),
          const SizedBox(height: 14),
          GlassCard(
            glowColor: NexusColors.cyan,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('テーマ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  '${s.themeBase == 'white' ? 'ホワイト' : 'ブラック'} / ${NexusPalette.byId(s.themeId).label}',
                  style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _BaseToneChip(
                        label: 'ホワイト',
                        selected: s.themeBase == 'white',
                        onTap: () => store.updateSettings(
                          s.copyWith(
                            themeId: UserSettings.composeThemeId('white', s.themeAccent),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BaseToneChip(
                        label: 'ブラック',
                        selected: s.themeBase == 'black',
                        onTap: () => store.updateSettings(
                          s.copyWith(
                            themeId: UserSettings.composeThemeId('black', s.themeAccent),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: [
                    for (final accent in UserSettings.themeAccents)
                      _ThemeSwatch(
                        palette: NexusPalette.byId(
                          UserSettings.composeThemeId(s.themeBase, accent.$1),
                        ),
                        selected: s.themeAccent == accent.$1,
                        onTap: () => store.updateSettings(
                          s.copyWith(
                            themeId: UserSettings.composeThemeId(s.themeBase, accent.$1),
                          ),
                        ),
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
                      Text(
                        store.occupation.isEmpty ? 'Lv.${store.level}' : '${store.occupation}  ·  Lv.${store.level}',
                        style: TextStyle(color: NexusColors.gold, fontSize: 12, letterSpacing: 0.4),
                      ),
                      if (cloud.session != null)
                        Text(cloud.session!.email, style: TextStyle(color: NexusColors.textMuted, fontSize: 11)),
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
          Text('アカウント', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Item(
                  icon: Icons.mail_outline_rounded,
                  color: NexusColors.cyan,
                  title: 'メールボックス',
                  subtitle: cloud.unreadMail == 0 ? '認証や保管の案内' : '未読 ${cloud.unreadMail} 通',
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(builder: (_) => const MailboxPage()),
                  ),
                ),
                _Item(
                  icon: Icons.inventory_2_rounded,
                  color: NexusColors.gold,
                  title: '保管庫',
                  subtitle: 'アプリからは書き換えできない保存',
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(builder: (_) => const VaultPage()),
                  ),
                ),
                _Item(
                  icon: Icons.logout_rounded,
                  color: NexusColors.purple,
                  title: 'ログアウト',
                  subtitle: cloud.session?.email ?? '',
                  onTap: () async {
                    await cloud.signOut();
                    store.detachCloud();
                  },
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
            child: TextButton(
              onPressed: () => _deleteAccount(context, store, cloud),
              child: Text('アカウントを削除', style: TextStyle(color: NexusColors.expense)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Nexus OS 0.1', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, AppStore store) async {
    final cloud = CloudScope.of(context);
    final name = TextEditingController(text: store.userName);
    final job = TextEditingController(text: store.occupation);
    final saved = await showNexusSheet<bool>(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('プロフィール', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            TextField(
              controller: name,
              style: TextStyle(color: NexusColors.text),
              decoration: const InputDecoration(labelText: '名前'),
            ),
            TextField(
              controller: job,
              style: TextStyle(color: NexusColors.text),
              decoration: const InputDecoration(labelText: '職業'),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
          ],
        );
      },
    );
    if (saved == true && name.text.trim().isNotEmpty) {
      store.setUserName(name.text.trim());
      store.setOccupation(job.text);
      try {
        await cloud.updateProfile(displayName: name.text.trim(), occupation: job.text.trim());
      } catch (_) {}
    }
    name.dispose();
    job.dispose();
  }

  Future<void> _deleteAccount(BuildContext context, AppStore store, NexusCloud cloud) async {
    final password = TextEditingController();
    final ok = await showNexusSheet<bool>(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('アカウントを削除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: NexusColors.expense)),
            const SizedBox(height: 8),
            Text(
              '学習・Money・日記などの同期データと保管庫も消えます。保管庫は画面から直したり消したりできませんが、アカウント削除のときだけまとめて消します。',
              style: TextStyle(color: NexusColors.textSecondary, height: 1.4),
            ),
            TextField(
              controller: password,
              obscureText: true,
              style: TextStyle(color: NexusColors.text),
              decoration: const InputDecoration(labelText: 'パスワード'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      try {
        await cloud.deleteAccount(password: password.text);
        store.detachCloud();
      } catch (_) {
        if (context.mounted) showNexusToast(context, cloud.lastError);
      }
    }
    password.dispose();
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

class _BaseToneChip extends StatelessWidget {
  const _BaseToneChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? NexusColors.cyan.withValues(alpha: 0.16) : NexusColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? NexusColors.cyan : NexusColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? NexusColors.cyan : NexusColors.text,
            ),
          ),
        ),
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
                boxShadow: selected && !NexusColors.isLight
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
