import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../cloud/nexus_cloud.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/negumo.dart';
import '../../widgets/ui_bits.dart';

const _createBlue = Color(0xFF6780AC);
const _signInCoral = Color(0xFFEF7059);
const _planetTeal = Color(0xFF4DB6AC);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  var _tab = 0;
  var _reset = false;
  var _showForm = false;
  var _formError = '';
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _name = TextEditingController();
  final _occupation = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  late final AnimationController _float;
  late final AnimationController _orbit;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    _orbit = AnimationController(vsync: this, duration: const Duration(milliseconds: 14000));
    if (!NexusMotion.inWidgetTest) {
      _float.repeat();
      _orbit.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    _orbit.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _name.dispose();
    _occupation.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  String get _speech {
    if (_reset) return 'メールに再設定の案内が届くよ。迷惑メールも見てねネグ。';
    if (!_showForm) return 'ボクはネグモ！いっしょに NEXUS を始めようネグ。';
    if (_tab == 1) return 'メール・パスワード・名前を書いてね。パスワードは8文字以上だよ。';
    return '登録したメールとパスワードで入るネグ。';
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

  Future<void> _logout() async {
    if (!await confirmLogout(context)) return;
    if (!mounted) return;
    await CloudScope.of(context).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    return PageScaffold(
      child: AnimatedBuilder(
        animation: Listenable.merge([_float, _orbit]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
            children: [
              const Center(child: GradientTitle('NEXUS', size: 30)),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  _reset ? 'パスワード再設定' : (_showForm ? (_tab == 0 ? 'おかえり' : 'はじめまして') : 'Launch Your Days'),
                  style: TextStyle(
                    color: NexusColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: _showForm ? 168 : 228,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _LoginSkyPainter(t: _orbit.value)),
                    ),
                    Transform.translate(
                      offset: Offset(math.sin(_float.value * math.pi * 2) * 6, 0),
                      child: NegumoMascot(
                        t: _float.value,
                        size: _showForm ? 132 : 176,
                        pose: _tab == 1 ? NegumoPose.wave : NegumoPose.float,
                      ),
                    ),
                  ],
                ),
              ),
              NegumoSpeech(text: _speech),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: NexusMotion.inWidgetTest ? Duration.zero : const Duration(milliseconds: 320),
                child: _showForm ? _form(cloud) : _landing(cloud),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _landing(NexusCloud cloud) {
    return Column(
      key: const ValueKey('landing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PillButton(
          label: '新規登録',
          color: _createBlue,
          onTap: () => setState(() {
            _showForm = true;
            _tab = 1;
            _reset = false;
          }),
        ),
        const SizedBox(height: 12),
        _PillButton(
          label: 'ログイン',
          color: _signInCoral,
          onTap: () => setState(() {
            _showForm = true;
            _tab = 0;
            _reset = false;
          }),
        ),
        TextButton(
          onPressed: () => setState(() {
            _showForm = true;
            _reset = true;
            _tab = 0;
          }),
          child: const Text('パスワードを忘れた'),
        ),
        if (cloud.isSignedIn)
          TextButton(
            onPressed: cloud.busy ? null : _logout,
            child: const Text('ログアウト'),
          ),
      ],
    );
  }

  Widget _form(NexusCloud cloud) {
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_reset)
          Row(
            children: [
              Expanded(
                child: _TabChip(
                  label: 'ログイン',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TabChip(
                  label: '新規登録',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
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
                style: FilledButton.styleFrom(
                  backgroundColor: _tab == 1 && !_reset ? _createBlue : _signInCoral,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
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
                  if (_reset) {
                    _reset = false;
                  } else {
                    _showForm = false;
                  }
                  _formError = '';
                  cloud.lastError = '';
                  cloud.lastNotice = '';
                }),
                child: Text(_reset ? 'ログインに戻る' : 'もどる'),
              ),
              if (!_reset)
                TextButton(
                  onPressed: () => setState(() {
                    _reset = true;
                    _formError = '';
                    cloud.lastError = '';
                    cloud.lastNotice = '';
                  }),
                  child: const Text('パスワードを忘れた'),
                ),
              if (cloud.isSignedIn)
                TextButton(
                  onPressed: cloud.busy ? null : _logout,
                  child: const Text('ログアウト'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          cloud.usesFirebase ? '別の端末でも、同じメールで入れます。' : 'この端末でアカウントを守ります。',
          style: TextStyle(color: NexusColors.textMuted, fontSize: 12, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.6),
        ),
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

class _LoginSkyPainter extends CustomPainter {
  _LoginSkyPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.48;
    for (var i = 0; i < 12; i++) {
      final a = t * math.pi * 2 + i * 0.7;
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * math.pi * 6 + i));
      final r = 18.0 + (i * 17) % 90;
      final p = Offset(cx + math.cos(a) * r, cy + math.sin(a * 0.8) * (r * 0.45));
      _diamond(canvas, p, 3.2 + (i % 3), Color.fromRGBO(170, 176, 186, twinkle));
    }
    _planet(canvas, Offset(cx - 118, cy - 46), 16, _planetTeal, t);
    _planet(canvas, Offset(cx + 112, cy + 28), 12, _signInCoral, -t);
  }

  void _diamond(Canvas canvas, Offset c, double s, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - s)
      ..lineTo(c.dx + s, c.dy)
      ..lineTo(c.dx, c.dy + s)
      ..lineTo(c.dx - s, c.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _planet(Canvas canvas, Offset c, double r, Color color, double spin) {
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.92));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin * math.pi * 2);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2.6, height: r * 0.42),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color.withValues(alpha: 0.55),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LoginSkyPainter oldDelegate) => oldDelegate.t != t;
}
