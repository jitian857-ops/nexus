import 'package:flutter/material.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../cloud/nexus_cloud.dart';
import '../../cloud/password.dart';
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
  var _hidePassword = true;
  var _hideConfirm = true;
  var _hideNewPassword = true;
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

  void _clearMessages() {
    _formError = '';
    final cloud = CloudScope.of(context);
    cloud.lastError = '';
    cloud.lastNotice = '';
  }

  void _showLogin() {
    setState(() {
      _tab = 0;
      _reset = false;
      _clearMessages();
    });
  }

  void _showRegister() {
    setState(() {
      _tab = 1;
      _reset = false;
      _clearMessages();
    });
  }

  Future<void> _submit() async {
    final cloud = CloudScope.of(context);
    setState(() => _formError = '');
    try {
      if (_reset) {
        if (!isValidEmail(_email.text)) {
          setState(() => _formError = 'メールアドレスの形が正しくありません');
          return;
        }
        if (cloud.usesFirebase || _code.text.trim().isEmpty) {
          await cloud.sendPasswordReset(_email.text);
        } else {
          if (!isValidPassword(_newPassword.text)) {
            setState(() => _formError = 'パスワードは8文字以上にしてください');
            return;
          }
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
        if (_email.text.trim().isEmpty || _password.text.isEmpty) {
          setState(() => _formError = 'メールアドレスとパスワードを入力してください');
          return;
        }
        await cloud.signIn(email: _email.text, password: _password.text);
        return;
      }
      if (_password.text != _confirm.text) {
        setState(() => _formError = 'パスワードが一致しません');
        return;
      }
      if (_name.text.trim().isEmpty) {
        setState(() => _formError = '名前を入力してください');
        return;
      }
      if (!isValidEmail(_email.text)) {
        setState(() => _formError = 'メールアドレスの形が正しくありません');
        return;
      }
      if (!isValidPassword(_password.text)) {
        setState(() => _formError = 'パスワードは8文字以上にしてください');
        return;
      }
      await cloud.signUp(
        email: _email.text,
        password: _password.text,
        displayName: _name.text,
        occupation: _occupation.text,
      );
    } catch (_) {}
  }

  Future<void> _logout() async {
    if (!await confirmLogout(context)) return;
    if (!mounted) return;
    await CloudScope.of(context).signOut();
  }

  String get _title {
    if (_reset) return 'パスワードを再設定';
    return _tab == 0 ? 'おかえりなさい' : 'NEXUSをはじめよう';
  }

  String get _subtitle {
    if (_reset) {
      return '登録したメールアドレスを入力してください。';
    }
    return _tab == 0 ? 'NEXUSにログインして、続きをはじめましょう。' : 'アカウントを作成して、新しい一歩を。';
  }

  String get _actionLabel {
    final cloud = CloudScope.of(context);
    if (_reset) {
      return cloud.usesFirebase
          ? '再設定メールを送る'
          : (_code.text.trim().isEmpty ? 'コードを送る' : 'パスワードを更新');
    }
    return _tab == 0 ? 'ログイン' : '登録する';
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    final palette = _AuthLook.of(context);
    final message = _formError.isNotEmpty ? _formError : cloud.lastError;
    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AuthAuroraPainter(light: palette.light),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
              children: [
                SizedBox(
                  height: 168,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 10,
                        child: _WatermarkColumn(
                          color: palette.watermark,
                          lines: const ['PEOPLE', 'IDEAS', 'TECHNOLOGY', 'A BRIGHTER', 'TOMORROW'],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 10,
                        child: _WatermarkColumn(
                          color: palette.watermark,
                          alignEnd: true,
                          lines: const ['つながる、', 'ひろがる、', 'もっと先へ。', '', 'A BRIGHTER', 'TOMORROW', 'TOGETHER'],
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, 0.28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const NexusLogo(size: 78),
                            const SizedBox(height: 10),
                            Text(
                              'NEXUS',
                              style: TextStyle(
                                color: palette.wordmark,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                letterSpacing: 5.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.title,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.subtitle, fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 22),
                if (!_reset)
                  _AuthTabs(
                    login: _tab == 0,
                    palette: palette,
                    onLogin: _showLogin,
                    onRegister: _showRegister,
                  ),
                const SizedBox(height: 22),
                _AuthField(
                  label: 'メールアドレス',
                  hint: 'you@example.com',
                  icon: Icons.mail_outline_rounded,
                  controller: _email,
                  palette: palette,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                ),
                if (!_reset) ...[
                  const SizedBox(height: 14),
                  _AuthField(
                    label: 'パスワード',
                    hint: '••••••••',
                    icon: Icons.lock_outline_rounded,
                    controller: _password,
                    palette: palette,
                    obscure: _hidePassword,
                    onToggleObscure: () => setState(() => _hidePassword = !_hidePassword),
                    autofillHints: const [AutofillHints.password],
                  ),
                  if (_tab == 1) ...[
                    const SizedBox(height: 14),
                    _AuthField(
                      label: 'パスワード（確認）',
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      controller: _confirm,
                      palette: palette,
                      obscure: _hideConfirm,
                      onToggleObscure: () => setState(() => _hideConfirm = !_hideConfirm),
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: 14),
                    _AuthField(
                      label: '名前',
                      hint: 'お名前を入力',
                      icon: Icons.person_outline_rounded,
                      controller: _name,
                      palette: palette,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                    ),
                    const SizedBox(height: 14),
                    _AuthField(
                      label: '職業',
                      hint: '職業を入力',
                      icon: Icons.work_outline_rounded,
                      controller: _occupation,
                      palette: palette,
                      autofillHints: const [AutofillHints.jobTitle],
                    ),
                  ],
                ] else if (!cloud.usesFirebase) ...[
                  const SizedBox(height: 14),
                  _AuthField(
                    label: '再設定コード',
                    hint: '6桁のコード',
                    icon: Icons.pin_outlined,
                    controller: _code,
                    palette: palette,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _AuthField(
                    label: '新しいパスワード',
                    hint: '8文字以上',
                    icon: Icons.lock_outline_rounded,
                    controller: _newPassword,
                    palette: palette,
                    obscure: _hideNewPassword,
                    onToggleObscure: () => setState(() => _hideNewPassword = !_hideNewPassword),
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                ],
                if (_tab == 0 && !_reset) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _reset = true;
                        _clearMessages();
                      }),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.link,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: const Text('パスワードをお忘れですか？', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                ],
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(message, style: TextStyle(color: NexusColors.expense, fontSize: 12, height: 1.4)),
                ],
                if (cloud.lastNotice.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(cloud.lastNotice, style: TextStyle(color: NexusColors.green, fontSize: 12, height: 1.4)),
                ],
                SizedBox(height: _tab == 0 && !_reset ? 8 : 18),
                _AuthPrimaryButton(
                  label: _actionLabel,
                  busy: cloud.busy,
                  palette: palette,
                  onTap: cloud.busy ? null : _submit,
                ),
                if (_tab == 0 && !_reset) ...[
                  const SizedBox(height: 18),
                  _OrDivider(palette: palette),
                  const SizedBox(height: 18),
                  _AuthGuestButton(
                    palette: palette,
                    enabled: !cloud.busy,
                    onTap: cloud.busy ? null : cloud.enterGuestSession,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ゲストのデータは、この端末に保存されます。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.caption, fontSize: 12, height: 1.4),
                  ),
                ],
                if (_tab == 1 && !_reset) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text('すでにアカウントをお持ちですか？ ', style: TextStyle(color: palette.caption, fontSize: 13)),
                      GestureDetector(
                        onTap: _showLogin,
                        child: Text('ログイン', style: TextStyle(color: palette.link, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
                if (_reset) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _showLogin,
                    child: Text('ログインに戻る', style: TextStyle(color: palette.link, fontWeight: FontWeight.w700)),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 14, color: palette.caption),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        cloud.usesFirebase ? '同じアカウントで、どの端末からでも。' : 'この端末でアカウントを守ります。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.caption, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                if (cloud.isSignedIn)
                  TextButton(
                    onPressed: cloud.busy ? null : _logout,
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

class _AuthLook {
  const _AuthLook({
    required this.light,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.wordmark,
    required this.watermark,
    required this.fieldFill,
    required this.fieldBorder,
    required this.fieldFocus,
    required this.hint,
    required this.icon,
    required this.segmentBg,
    required this.segmentSelected,
    required this.ctaStart,
    required this.ctaEnd,
    required this.ctaShadow,
    required this.link,
    required this.caption,
  });

  final bool light;
  final Color background;
  final Color title;
  final Color subtitle;
  final Color wordmark;
  final Color watermark;
  final Color fieldFill;
  final Color fieldBorder;
  final Color fieldFocus;
  final Color hint;
  final Color icon;
  final Color segmentBg;
  final Color segmentSelected;
  final Color ctaStart;
  final Color ctaEnd;
  final Color ctaShadow;
  final Color link;
  final Color caption;

  static _AuthLook of(BuildContext context) {
    if (NexusColors.isLight) {
      return const _AuthLook(
        light: true,
        background: Color(0xFFF8FAFE),
        title: Color(0xFF18233A),
        subtitle: Color(0xFF7A8496),
        wordmark: Color(0xFF3A4660),
        watermark: Color(0x2A3A4A68),
        fieldFill: Colors.white,
        fieldBorder: Color(0xFFE3E8F0),
        fieldFocus: Color(0xFF3D7CFF),
        hint: Color(0xFFB7BEC9),
        icon: Color(0xFF9AA3B2),
        segmentBg: Color(0xFFEEF1F6),
        segmentSelected: Colors.white,
        ctaStart: Color(0xFF2F73FF),
        ctaEnd: Color(0xFF3E86FF),
        ctaShadow: Color(0xFF2F73FF),
        link: Color(0xFF2F73FF),
        caption: Color(0xFF8B93A3),
      );
    }
    return _AuthLook(
      light: false,
      background: NexusColors.background,
      title: NexusColors.text,
      subtitle: NexusColors.textSecondary,
      wordmark: NexusColors.textSecondary,
      watermark: NexusColors.textMuted.withValues(alpha: 0.45),
      fieldFill: NexusColors.surface,
      fieldBorder: NexusColors.border,
      fieldFocus: NexusColors.cyan,
      hint: NexusColors.textMuted,
      icon: NexusColors.textMuted,
      segmentBg: NexusColors.cardTop,
      segmentSelected: NexusColors.card,
      ctaStart: const Color(0xFF2F73FF),
      ctaEnd: const Color(0xFF3E86FF),
      ctaShadow: const Color(0xFF2F73FF),
      link: NexusColors.cyan,
      caption: NexusColors.textMuted,
    );
  }
}

class _AuthAuroraPainter extends CustomPainter {
  const _AuthAuroraPainter({required this.light});

  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());

    void blob(Alignment center, double radius, Color color) {
      final origin = center.alongSize(size);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: origin, radius: size.width * radius));
      canvas.drawRect(rect, paint);
    }

    if (light) {
      blob(const Alignment(-1.05, -1.2), 1.2, const Color(0x9978D4FF));
      blob(const Alignment(-0.15, -1.25), 0.95, const Color(0x6689B4FF));
      blob(const Alignment(0.55, -1.05), 0.9, const Color(0x55C4B5FD));
      blob(const Alignment(1.15, -0.55), 0.72, const Color(0x447DD3FC));
    } else {
      blob(const Alignment(-1.0, -1.1), 1.1, NexusColors.cyan.withValues(alpha: 0.28));
      blob(const Alignment(0.8, -0.9), 0.9, NexusColors.purple.withValues(alpha: 0.22));
    }

    final wave = Path()
      ..moveTo(0, size.height * 0.42)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.08,
        size.width * 0.42,
        size.height * 0.62,
        size.width * 0.7,
        size.height * 0.28,
      )
      ..cubicTo(
        size.width * 0.88,
        size.height * 0.06,
        size.width,
        size.height * 0.22,
        size.width,
        0,
      )
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      wave,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: light
              ? const [Color(0x5578D4FF), Color(0x3389B4FF), Color(0x00FFFFFF)]
              : [
                  NexusColors.cyan.withValues(alpha: 0.16),
                  NexusColors.purple.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AuthAuroraPainter oldDelegate) => oldDelegate.light != light;
}

class _WatermarkColumn extends StatelessWidget {
  const _WatermarkColumn({
    required this.lines,
    required this.color,
    this.alignEnd = false,
  });

  final List<String> lines;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Text(
      lines.join('\n'),
      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        color: color,
        fontSize: 8,
        height: 1.45,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AuthTabs extends StatelessWidget {
  const _AuthTabs({
    required this.login,
    required this.palette,
    required this.onLogin,
    required this.onRegister,
  });

  final bool login;
  final _AuthLook palette;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.segmentBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _item('ログイン', login, onLogin),
          _item('新規登録', !login, onRegister),
        ],
      ),
    );
  }

  Widget _item(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: NexusMotion.inWidgetTest ? Duration.zero : NexusMotion.fast,
          curve: NexusMotion.curve,
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? palette.segmentSelected : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: palette.light ? 0.06 : 0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: selected ? palette.title : palette.caption,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.palette,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final _AuthLook palette;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: palette.title, fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          style: TextStyle(color: palette.title, fontWeight: FontWeight.w600),
          cursorColor: palette.fieldFocus,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: palette.hint, fontWeight: FontWeight.w500),
            prefixIcon: Icon(icon, color: palette.icon),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: palette.icon,
                    ),
                  ),
            filled: true,
            fillColor: palette.fieldFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: palette.fieldBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: palette.fieldBorder)),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: palette.fieldFocus, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthPrimaryButton extends StatelessWidget {
  const _AuthPrimaryButton({
    required this.label,
    required this.busy,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final _AuthLook palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      enabled: onTap != null,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [palette.ctaStart, palette.ctaEnd]),
          boxShadow: [
            BoxShadow(
              color: palette.ctaShadow.withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                else
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                if (!busy)
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthGuestButton extends StatelessWidget {
  const _AuthGuestButton({
    required this.palette,
    required this.enabled,
    required this.onTap,
  });

  final _AuthLook palette;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      enabled: enabled,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.fieldFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.link, width: 1.2),
        ),
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              'ゲストとして試す',
              style: TextStyle(color: palette.link, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.palette});

  final _AuthLook palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: palette.fieldBorder, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('または', style: TextStyle(color: palette.caption, fontSize: 12)),
        ),
        Expanded(child: Divider(color: palette.fieldBorder, height: 1)),
      ],
    );
  }
}
