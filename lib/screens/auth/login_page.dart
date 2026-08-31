import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../cloud/nexus_cloud.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/nexus_logo.dart';
import '../../widgets/ui_bits.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  var _tab = 0;
  var _reset = false;
  var _formError = '';
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _name = TextEditingController();
  final _occupation = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _name.dispose();
    _occupation.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cloud = CloudScope.of(context);
    setState(() => _formError = '');
    try {
      if (_reset) {
        if (cloud.usesFirebase || _code.text.trim().isEmpty) {
          await cloud.sendPasswordReset(_email.text);
        } else {
          await cloud.confirmPasswordReset(
            email: _email.text,
            code: _code.text,
            newPassword: _newPassword.text,
          );
          if (!mounted) return;
          setState(() => _reset = false);
        }
        return;
      }
      if (_tab == 0) {
        await cloud.signIn(email: _email.text, password: _password.text);
      } else {
        if (_password.text != _confirm.text) {
          setState(() => _formError = 'パスワードが一致しません');
          return;
        }
        await cloud.signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
          occupation: _occupation.text,
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    return PageScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          const Center(child: NexusLogo(size: 72)),
          const SizedBox(height: 12),
          const Center(child: GradientTitle('NEXUS', size: 28)),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _reset
                  ? 'パスワード再設定'
                  : (_tab == 0 ? 'ログイン' : '新規登録'),
              style: TextStyle(color: NexusColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 18),
          if (!_reset)
            Row(
              children: [
                Expanded(child: _TabChip(label: 'ログイン', selected: _tab == 0, onTap: () => setState(() => _tab = 0))),
                const SizedBox(width: 8),
                Expanded(child: _TabChip(label: '新規登録', selected: _tab == 1, onTap: () => setState(() => _tab = 1))),
              ],
            ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: 'メールアドレス'),
                ),
                if (!_reset) ...[
                  TextField(
                    controller: _password,
                    obscureText: true,
                    style: TextStyle(color: NexusColors.text),
                    decoration: const InputDecoration(labelText: 'パスワード'),
                  ),
                  if (_tab == 1) ...[
                    TextField(
                      controller: _confirm,
                      obscureText: true,
                      style: TextStyle(color: NexusColors.text),
                      decoration: const InputDecoration(labelText: 'パスワード（確認）'),
                    ),
                    TextField(
                      controller: _name,
                      style: TextStyle(color: NexusColors.text),
                      decoration: const InputDecoration(labelText: '名前'),
                    ),
                    TextField(
                      controller: _occupation,
                      style: TextStyle(color: NexusColors.text),
                      decoration: const InputDecoration(labelText: '職業'),
                    ),
                  ],
                ] else ...[
                  if (!cloud.usesFirebase) ...[
                    TextField(
                      controller: _code,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: NexusColors.text),
                      decoration: const InputDecoration(labelText: '再設定コード'),
                    ),
                    TextField(
                      controller: _newPassword,
                      obscureText: true,
                      style: TextStyle(color: NexusColors.text),
                      decoration: const InputDecoration(labelText: '新しいパスワード'),
                    ),
                  ],
                ],
                if (_formError.isNotEmpty || cloud.lastError.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formError.isNotEmpty ? _formError : cloud.lastError,
                    style: TextStyle(color: NexusColors.expense, fontSize: 12),
                  ),
                ],
                if (cloud.lastNotice.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(cloud.lastNotice, style: TextStyle(color: NexusColors.green, fontSize: 12)),
                ],
                if (!cloud.usesFirebase && cloud.localIssuedCode != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'この端末のコード: ${cloud.localIssuedCode}',
                    style: TextStyle(color: NexusColors.cyan, fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: cloud.busy ? null : _submit,
                  child: Text(
                    _reset
                        ? (cloud.usesFirebase
                            ? '再設定メールを送る'
                            : (_code.text.trim().isEmpty ? 'コードを送る' : 'パスワードを更新'))
                        : (_tab == 0 ? 'ログイン' : '登録する'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _reset = !_reset;
                    _formError = '';
                    cloud.lastError = '';
                    cloud.lastNotice = '';
                  }),
                  child: Text(_reset ? 'ログインに戻る' : 'パスワードを忘れた'),
                ),
                if (cloud.isSignedIn)
                  TextButton(
                    onPressed: cloud.busy ? null : () => cloud.signOut(),
                    child: const Text('ログアウト'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            cloud.usesFirebase
                ? '別の端末でも、同じメールで入れます。'
                : 'この端末の保管庫でアカウントを守ります。クラウドキーを入れると別端末とも同期します。',
            style: TextStyle(color: NexusColors.textMuted, fontSize: 12, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});

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
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? NexusColors.cyan : NexusColors.border),
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
