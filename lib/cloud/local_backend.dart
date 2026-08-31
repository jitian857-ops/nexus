import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_backend.dart';
import 'cloud_models.dart';
import 'password.dart';

class LocalBackend implements CloudBackend {
  LocalBackend();

  static const _key = 'nexus_cloud_v1';

  Map<String, dynamic> _root = {};
  CloudSession? _session;
  int _seq = 0;
  String? lastIssuedCode;

  @override
  bool get usesFirebase => false;

  @override
  CloudSession? get currentSession => _session;

  String _id() => 'c${DateTime.now().microsecondsSinceEpoch}${_seq++}';

  Map<String, dynamic> _map(String key) {
    final value = _root[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      final copied = Map<String, dynamic>.from(value);
      _root[key] = copied;
      return copied;
    }
    final created = <String, dynamic>{};
    _root[key] = created;
    return created;
  }

  @override
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        _root = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        _root = {};
      }
    }
    final uid = _root['sessionUid'] as String?;
    if (uid != null && uid.isNotEmpty) {
      _session = _sessionFromUid(uid);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_root));
  }

  CloudSession? _sessionFromUid(String uid) {
    final accounts = _map('accounts');
    for (final entry in accounts.entries) {
      final data = Map<String, dynamic>.from(entry.value as Map);
      if (data['uid'] != uid) continue;
      return CloudSession(
        uid: uid,
        email: data['email'] as String? ?? entry.key,
        displayName: data['displayName'] as String? ?? '',
        occupation: data['occupation'] as String? ?? '',
        emailVerified: data['verified'] as bool? ?? false,
        usesFirebase: false,
      );
    }
    return null;
  }

  Map<String, dynamic>? _accountByEmail(String email) {
    final accounts = _map('accounts');
    final data = accounts[email.trim().toLowerCase()];
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  @override
  Future<CloudSession> signUp({
    required String email,
    required String password,
    required String displayName,
    required String occupation,
  }) async {
    final key = email.trim().toLowerCase();
    if (!isValidEmail(key)) throw CloudException('メールアドレスの形が正しくありません');
    if (!isValidPassword(password)) throw CloudException('パスワードは8文字以上にしてください');
    if (displayName.trim().isEmpty) throw CloudException('名前を入力してください');
    if (_accountByEmail(key) != null) throw CloudException('このメールアドレスはすでに登録されています');
    final uid = _id();
    final salt = PasswordHash.salt();
    _map('accounts')[key] = {
      'uid': uid,
      'email': key,
      'displayName': displayName.trim(),
      'occupation': occupation.trim(),
      'salt': salt,
      'passHash': PasswordHash.hash(password, salt),
      'verified': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
    _root['sessionUid'] = uid;
    _session = CloudSession(
      uid: uid,
      email: key,
      displayName: displayName.trim(),
      occupation: occupation.trim(),
      emailVerified: false,
      usesFirebase: false,
    );
    await _persist();
    return _session!;
  }

  @override
  Future<CloudSession> signIn({
    required String email,
    required String password,
  }) async {
    final account = _accountByEmail(email);
    if (account == null) throw CloudException('メールアドレスまたはパスワードが違います');
    final salt = account['salt'] as String? ?? '';
    final hash = account['passHash'] as String? ?? '';
    if (!PasswordHash.matches(password, salt, hash)) {
      throw CloudException('メールアドレスまたはパスワードが違います');
    }
    final uid = account['uid'] as String;
    _root['sessionUid'] = uid;
    _session = _sessionFromUid(uid);
    await _persist();
    return _session!;
  }

  @override
  Future<void> signOut() async {
    _root['sessionUid'] = null;
    _session = null;
    await _persist();
  }

  @override
  Future<void> sendVerification() async {
    final session = _session;
    if (session == null) throw CloudException('ログインしてください');
    final code = PasswordHash.sixDigitCode();
    lastIssuedCode = code;
    _map('verify')[session.uid] = {
      'code': code,
      'exp': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    };
    await addMail(
      session.uid,
      MailItem(
        id: _id(),
        title: 'メールアドレスの認証',
        body: '認証コードは $code です。認証画面で入力するか、下の案内から認証できます。',
        at: DateTime.now(),
        kind: 'verify',
      ),
    );
    await _persist();
  }

  @override
  Future<CloudSession> confirmVerification({String? code}) async {
    final session = _session;
    if (session == null) throw CloudException('ログインしてください');
    final row = _map('verify')[session.uid];
    if (row is! Map) throw CloudException('認証コードを先に送ってください');
    final expected = (row['code'] as String? ?? '').trim();
    final typed = (code ?? '').trim();
    if (typed.isNotEmpty && typed != expected) throw CloudException('認証コードが違います');
    await verifyWithCode(expected);
    return refreshSession();
  }

  Future<void> verifyWithCode(String code) async {
    final session = _session;
    if (session == null) throw CloudException('ログインしてください');
    final row = _map('verify')[session.uid];
    if (row is! Map) throw CloudException('認証コードを先に送ってください');
    final exp = DateTime.tryParse(row['exp'] as String? ?? '');
    if (exp == null || exp.isBefore(DateTime.now())) {
      throw CloudException('認証コードの期限が切れています');
    }
    if (row['code'] != code.trim()) throw CloudException('認証コードが違います');
    final accounts = _map('accounts');
    final account = _accountByEmail(session.email);
    if (account == null) throw CloudException('アカウントが見つかりません');
    account['verified'] = true;
    accounts[session.email] = account;
    _session = session.copyWith(emailVerified: true);
    await addMail(
      session.uid,
      MailItem(
        id: _id(),
        title: 'メールアドレスを認証しました',
        body: '${session.email} の認証が完了しました。',
        at: DateTime.now(),
        kind: 'verify',
      ),
    );
    await _persist();
  }

  @override
  Future<CloudSession> refreshSession() async {
    final session = _session;
    if (session == null) throw CloudException('ログインしてください');
    _session = _sessionFromUid(session.uid);
    return _session!;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final account = _accountByEmail(email);
    if (account == null) return;
    final code = PasswordHash.sixDigitCode();
    lastIssuedCode = code;
    _map('reset')[email.trim().toLowerCase()] = {
      'code': code,
      'exp': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
    };
    await addMail(
      account['uid'] as String,
      MailItem(
        id: _id(),
        title: 'パスワード再設定',
        body: '再設定コードは $code です。ログイン画面の再設定から入力してください。',
        at: DateTime.now(),
        kind: 'reset',
      ),
    );
    await _persist();
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (!isValidPassword(newPassword)) throw CloudException('パスワードは8文字以上にしてください');
    final key = email.trim().toLowerCase();
    final row = _map('reset')[key];
    if (row is! Map) throw CloudException('再設定コードを先に送ってください');
    final exp = DateTime.tryParse(row['exp'] as String? ?? '');
    if (exp == null || exp.isBefore(DateTime.now())) {
      throw CloudException('再設定コードの期限が切れています');
    }
    if (row['code'] != code.trim()) throw CloudException('再設定コードが違います');
    final account = _accountByEmail(key);
    if (account == null) throw CloudException('アカウントが見つかりません');
    final salt = PasswordHash.salt();
    account['salt'] = salt;
    account['passHash'] = PasswordHash.hash(newPassword, salt);
    _map('accounts')[key] = account;
    _map('reset').remove(key);
    await _persist();
  }

  @override
  Future<CloudSession> updateProfile({
    required String displayName,
    required String occupation,
  }) async {
    final session = _session;
    if (session == null) throw CloudException('ログインしてください');
    if (displayName.trim().isEmpty) throw CloudException('名前を入力してください');
    final account = _accountByEmail(session.email);
    if (account == null) throw CloudException('アカウントが見つかりません');
    account['displayName'] = displayName.trim();
    account['occupation'] = occupation.trim();
    _map('accounts')[session.email] = account;
    _session = session.copyWith(displayName: displayName.trim(), occupation: occupation.trim());
    await _persist();
    return _session!;
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    final session = _session;
    if (session == null) throw CloudException('ログインしてください');
    final account = _accountByEmail(session.email);
    if (account == null) throw CloudException('アカウントが見つかりません');
    final salt = account['salt'] as String? ?? '';
    final hash = account['passHash'] as String? ?? '';
    if (!PasswordHash.matches(password, salt, hash)) {
      throw CloudException('パスワードが違います');
    }
    final uid = session.uid;
    _map('accounts').remove(session.email);
    _map('live').remove(uid);
    _map('mail').remove(uid);
    _map('vault').remove(uid);
    _map('verify').remove(uid);
    _root['sessionUid'] = null;
    _session = null;
    await _persist();
  }

  @override
  Future<Map<String, dynamic>?> pullLive(String uid) async {
    final data = _map('live')[uid];
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  @override
  Future<void> pushLive(String uid, Map<String, dynamic> bundle) async {
    _map('live')[uid] = bundle;
    await _persist();
  }

  @override
  Future<void> sealVault(String uid, String reason, Map<String, dynamic> bundle) async {
    final list = [
      ...((_map('vault')[uid] as List?) ?? const []),
    ];
    final encoded = jsonEncode(bundle);
    list.add({
      'id': _id(),
      'at': DateTime.now().toIso8601String(),
      'reason': reason,
      'bytes': utf8.encode(encoded).length,
      'sealed': true,
      'data': bundle,
    });
    _map('vault')[uid] = list;
    await _persist();
  }

  @override
  Future<List<VaultRecord>> listVault(String uid) async {
    final list = (_map('vault')[uid] as List?) ?? const [];
    return [
      for (final item in list)
        if (item is Map)
          VaultRecord(
            id: item['id'] as String? ?? '',
            at: DateTime.tryParse(item['at'] as String? ?? '') ?? DateTime.now(),
            reason: item['reason'] as String? ?? '',
            bytes: item['bytes'] as int? ?? 0,
          ),
    ]..sort((a, b) => b.at.compareTo(a.at));
  }

  @override
  Future<VaultRecord?> readVault(String uid, String id) async {
    final list = (_map('vault')[uid] as List?) ?? const [];
    for (final item in list) {
      if (item is! Map || item['id'] != id) continue;
      final data = item['data'];
      return VaultRecord(
        id: id,
        at: DateTime.tryParse(item['at'] as String? ?? '') ?? DateTime.now(),
        reason: item['reason'] as String? ?? '',
        bytes: item['bytes'] as int? ?? 0,
        data: data is Map ? Map<String, dynamic>.from(data) : null,
      );
    }
    return null;
  }

  @override
  Future<List<MailItem>> listMail(String uid) async {
    final list = (_map('mail')[uid] as List?) ?? const [];
    final items = [
      for (final item in list)
        if (item is Map) MailItem.fromJson(Map<String, dynamic>.from(item)),
    ];
    items.sort((a, b) => b.at.compareTo(a.at));
    return items;
  }

  @override
  Future<void> addMail(String uid, MailItem item) async {
    final list = [
      item.toJson(),
      ...((_map('mail')[uid] as List?) ?? const []),
    ];
    _map('mail')[uid] = list;
    await _persist();
  }

  @override
  Future<void> markMailRead(String uid, String id) async {
    final list = [
      for (final item in ((_map('mail')[uid] as List?) ?? const []))
        if (item is Map)
          {
            ...item,
            if (item['id'] == id) 'read': true,
          }
        else
          item,
    ];
    _map('mail')[uid] = list;
    await _persist();
  }

  /// テスト専用。永続化しないセッションを入れる。
  void enterMemorySession(CloudSession session) {
    _session = session;
    _map('accounts')[session.email] = {
      'uid': session.uid,
      'email': session.email,
      'displayName': session.displayName,
      'occupation': session.occupation,
      'verified': session.emailVerified,
      'salt': 'test',
      'passHash': PasswordHash.hash('testpass1', 'test'),
    };
  }
}
