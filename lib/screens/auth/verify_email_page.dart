import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../cloud/nexus_cloud.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_bits.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    final email = cloud.session?.email ?? '';
    return PageScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          const GradientTitle('メール認証', size: 26),
          const SizedBox(height: 8),
          Text(
            '$email の受信箱に、認証用のリンクを送りました。',
            style: TextStyle(color: NexusColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            '送信元は noreply@nexus-50e0e.firebaseapp.com です。届かないときは迷惑メールも見てください。アプリ内のメールボックスは控えだけです。',
            style: TextStyle(color: NexusColors.textMuted, height: 1.4, fontSize: 13),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!cloud.usesFirebase) ...[
                  TextField(
                    controller: _code,
                    style: TextStyle(color: NexusColors.text),
                    decoration: const InputDecoration(labelText: '認証コード'),
                  ),
                  if (cloud.localIssuedCode != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'この端末のコード: ${cloud.localIssuedCode}',
                        style: TextStyle(color: NexusColors.cyan, fontWeight: FontWeight.w700),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                if (cloud.lastError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(cloud.lastError, style: TextStyle(color: NexusColors.expense)),
                  ),
                if (cloud.lastNotice.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(cloud.lastNotice, style: TextStyle(color: NexusColors.green)),
                  ),
                FilledButton(
                  onPressed: cloud.busy ? null : () => cloud.confirmVerification(code: _code.text),
                  child: Text(cloud.usesFirebase ? 'メールのリンクを開いたので確認する' : '認証する'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: cloud.busy ? null : cloud.sendVerification,
                  child: const Text('認証メールを再送'),
                ),
                TextButton(
                  onPressed: cloud.busy
                      ? null
                      : () async {
                          if (!await confirmLogout(context)) return;
                          await cloud.signOut();
                        },
                  child: const Text('ログアウト'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
