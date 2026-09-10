import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';

import 'cloud_backend.dart';
import 'cloud_models.dart';
import 'friend_models.dart';
import 'password.dart';
import 'share_access.dart';
import '../core/image_compress.dart';

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
    await _ensureProfile(uid, displayName: displayName.trim(), occupation: occupation.trim());
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
    String? photoUrl,
  }) async {
    final session = _session;
    if (session == null) throw CloudException('ログインしてください');
    if (displayName.trim().isEmpty) throw CloudException('名前を入力してください');
    final account = _accountByEmail(session.email);
    if (account == null) throw CloudException('アカウントが見つかりません');
    account['displayName'] = displayName.trim();
    account['occupation'] = occupation.trim();
    _map('accounts')[session.email] = account;
    final row = _profileMap(session.uid);
    row['displayName'] = displayName.trim();
    row['occupation'] = occupation.trim();
    if (photoUrl != null) row['photoUrl'] = photoUrl;
    _session = session.copyWith(displayName: displayName.trim(), occupation: occupation.trim());
    await _persist();
    return _session!;
  }

  @override
  Future<String> uploadMedia(List<int> bytes, {String mime = 'image/jpeg', bool avatar = false}) async {
    if (bytes.isEmpty) throw CloudException('写真を選べませんでした');
    final packed = compressForFirestore(bytes, avatar: avatar, mime: mime);
    final id = _id();
    final url = 'data:${packed.mime};base64,${base64Encode(packed.bytes)}';
    _map('media')[id] = url;
    await _persist();
    return url;
  }

  @override
  Future<String> readMedia(String src) async {
    if (src.startsWith('data:') || src.startsWith('http://') || src.startsWith('https://')) {
      return src;
    }
    const prefix = 'nexus-media:';
    if (src.startsWith(prefix)) {
      final stored = _map('media')[src.substring(prefix.length)];
      if (stored is String && stored.isNotEmpty) return stored;
    }
    return src;
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
    if (uid.isEmpty) return null;
    final data = _map('live')[uid];
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  @override
  Future<void> pushLive(String uid, Map<String, dynamic> bundle) async {
    if (uid.isEmpty) return;
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

  String _me() {
    final uid = _session?.uid;
    if (uid == null || uid.isEmpty) throw CloudException('ログインしてください');
    return uid;
  }

  Map<String, dynamic> _profileMap(String uid) {
    final row = _map('profiles')[uid];
    if (row is Map<String, dynamic>) return row;
    if (row is Map) {
      final copied = Map<String, dynamic>.from(row);
      _map('profiles')[uid] = copied;
      return copied;
    }
    final created = <String, dynamic>{'uid': uid};
    _map('profiles')[uid] = created;
    return created;
  }

  FriendProfile _profileOf(String uid) {
    final row = _profileMap(uid);
    var name = row['displayName'] as String? ?? '';
    if (name.isEmpty) {
      for (final account in _map('accounts').values) {
        if (account is Map && account['uid'] == uid) {
          name = account['displayName'] as String? ?? '';
        }
      }
    }
    return FriendProfile(
      uid: uid,
      displayName: name.isEmpty ? 'ユーザー' : name,
      friendCode: row['friendCode'] as String? ?? '',
      occupation: row['occupation'] as String? ?? '',
      photoUrl: row['photoUrl'] as String? ?? '',
    );
  }

  Future<void> _ensureProfile(String uid, {String? displayName, String? occupation}) async {
    final row = _profileMap(uid);
    if (displayName != null && displayName.isNotEmpty) row['displayName'] = displayName;
    if (occupation != null) row['occupation'] = occupation;
    if ((row['friendCode'] as String? ?? '').isEmpty) {
      await ensureFriendCode();
      return;
    }
    await _persist();
  }

  bool _blockedPair(String a, String b) {
    final blocks = _map('blocks');
    return blocks['${a}_$b'] != null || blocks['${b}_$a'] != null;
  }

  String _pairKey(String a, String b) {
    final first = a.compareTo(b) < 0 ? a : b;
    final second = first == a ? b : a;
    return '${first}_$second';
  }

  bool _areFriends(String a, String b) => _map('friendships')[_pairKey(a, b)] != null;

  DateTime? _friendshipStartedAt(String a, String b) {
    final row = _map('friendships')[_pairKey(a, b)];
    if (row is! Map) return null;
    return DateTime.tryParse(row['createdAt'] as String? ?? '');
  }

  /// 解除時の ACL 掃除失敗を試験するため。本番では false のまま。
  @visibleForTesting
  bool debugSkipAclRevoke = false;

  @visibleForTesting
  void debugPutAcl({
    required String itemId,
    required String viewerId,
    DateTime? createdAt,
    String? docId,
  }) {
    final id = docId ?? ShareAccess.aclId(itemId, viewerId);
    _map('shareAcl')[id] = {
      'itemId': itemId,
      'viewerId': viewerId,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  @visibleForTesting
  void debugAttemptChangeOwner(String itemId, String newOwnerId) {
    final raw = _map('sharedItems')[itemId];
    if (raw is! Map) throw CloudException('共有が見つかりません');
    final owner = raw['ownerId'] as String? ?? '';
    if (owner != _me()) throw CloudException('所有者ではありません');
    if (!ShareAccess.ownerImmutable(existingOwnerId: owner, requestedOwnerId: newOwnerId)) {
      throw CloudException('この共有の所有者は変えられません');
    }
  }

  Future<void> _notify(String userId, String type, String actorId, {String? targetId, String? title, String? body}) async {
    final notices = _map('friendNotices');
    final list = [...((notices[userId] as List?) ?? const [])];
    list.insert(0, {
      'id': _id(),
      'userId': userId,
      'type': type,
      'actorId': actorId,
      'targetId': targetId,
      'createdAt': DateTime.now().toIso8601String(),
    });
    notices[userId] = list;
    if (title != null) {
      await addMail(
        userId,
        MailItem(id: _id(), title: title, body: body ?? '', at: DateTime.now(), kind: type),
      );
    }
  }

  Future<void> _revokeAclsBetween(String a, String b) async {
    if (debugSkipAclRevoke) return;
    final acls = _map('shareAcl');
    for (final key in [...acls.keys]) {
      final row = Map<String, dynamic>.from(acls[key] as Map);
      final item = _map('sharedItems')[row['itemId']];
      if (item is! Map) continue;
      final owner = item['ownerId'] as String? ?? '';
      final viewer = row['viewerId'] as String? ?? '';
      if ((owner == a && viewer == b) || (owner == b && viewer == a)) {
        acls.remove(key);
      }
    }
  }

  @override
  Future<FriendProfile> ensureFriendCode({bool regenerate = false}) async {
    final uid = _me();
    final row = _profileMap(uid);
    final current = row['friendCode'] as String? ?? '';
    if (!regenerate && current.isNotEmpty) return _profileOf(uid);
    final codes = _map('friendCodes');
    if (current.isNotEmpty) codes.remove(current);
    var code = generateFriendCode();
    while (codes.containsKey(code)) {
      code = generateFriendCode();
    }
    codes[code] = uid;
    row['friendCode'] = code;
    row['uid'] = uid;
    if ((row['displayName'] as String? ?? '').isEmpty) {
      row['displayName'] = _session?.displayName ?? 'ユーザー';
    }
    row['occupation'] = row['occupation'] ?? _session?.occupation ?? '';
    await _persist();
    return _profileOf(uid);
  }

  @override
  Future<FriendProfile?> lookupFriend(String query) async {
    final me = _me();
    final q = friendCodeFromScan(query) ?? normalizeFriendQuery(query);
    if (q.isEmpty) return null;
    String? uid;
    if (q.length == 8) {
      uid = _map('friendCodes')[q] as String?;
      if (uid == null || uid.isEmpty) return null;
    } else {
      uid = query.trim();
    }
    if (uid == me) throw CloudException('自分は追加できません');
    if (_blockedPair(me, uid)) return null;
    final profiles = _map('profiles');
    if (!profiles.containsKey(uid)) {
      for (final account in _map('accounts').values) {
        if (account is Map && account['uid'] == uid) {
          await _ensureProfile(
            uid,
            displayName: account['displayName'] as String?,
            occupation: account['occupation'] as String?,
          );
        }
      }
    }
    if (!profiles.containsKey(uid) && _map('friendCodes')[q] == null) return null;
    if (!profiles.containsKey(uid)) return null;
    return _profileOf(uid);
  }

  @override
  Future<void> sendFriendRequest(String toUid) async {
    final me = _me();
    if (me == toUid) throw CloudException('自分は追加できません');
    if (_blockedPair(me, toUid)) throw CloudException('申請できません');
    if (_areFriends(me, toUid)) throw CloudException('すでにフレンドです');
    final requests = _map('friendRequests');
    for (final entry in requests.entries) {
      final row = Map<String, dynamic>.from(entry.value as Map);
      if (row['status'] != 'pending') continue;
      final sender = row['senderId'] as String? ?? '';
      final receiver = row['receiverId'] as String? ?? '';
      if ((sender == me && receiver == toUid) || (sender == toUid && receiver == me)) {
        throw CloudException('すでに申請中です');
      }
    }
    final id = _id();
    requests[id] = {
      'id': id,
      'senderId': me,
      'receiverId': toUid,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _notify(
      toUid,
      'friend_request',
      me,
      targetId: id,
      title: 'フレンド申請が届きました',
      body: '${_profileOf(me).displayName} からフレンド申請が届きました。',
    );
    await _persist();
  }

  List<FriendRequestItem> _requestsWhere(bool Function(Map<String, dynamic>) test) {
    final items = <FriendRequestItem>[];
    for (final entry in _map('friendRequests').entries) {
      final row = Map<String, dynamic>.from(entry.value as Map);
      if (!test(row)) continue;
      items.add(
        FriendRequestItem(
          id: row['id'] as String? ?? entry.key,
          senderId: row['senderId'] as String? ?? '',
          receiverId: row['receiverId'] as String? ?? '',
          status: requestStatusFrom(row['status'] as String? ?? 'pending'),
          createdAt: DateTime.tryParse(row['createdAt'] as String? ?? '') ?? DateTime.now(),
          sender: _profileOf(row['senderId'] as String? ?? ''),
          receiver: _profileOf(row['receiverId'] as String? ?? ''),
        ),
      );
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<void> respondFriendRequest(String requestId, {required bool accept}) async {
    final me = _me();
    final row = _map('friendRequests')[requestId];
    if (row is! Map) throw CloudException('申請が見つかりません');
    final data = Map<String, dynamic>.from(row);
    if (data['receiverId'] != me) throw CloudException('申請が見つかりません');
    if (data['status'] != 'pending') throw CloudException('この申請は処理済みです');
    data['status'] = accept ? 'accepted' : 'rejected';
    _map('friendRequests')[requestId] = data;
    final sender = data['senderId'] as String? ?? '';
    if (accept) {
      _map('friendships')[_pairKey(me, sender)] = {
        'userA': me.compareTo(sender) < 0 ? me : sender,
        'userB': me.compareTo(sender) < 0 ? sender : me,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await _notify(
        sender,
        'friend_accept',
        me,
        targetId: requestId,
        title: '申請が承認されました',
        body: '${_profileOf(me).displayName} がフレンド申請を承認しました。',
      );
    }
    await _persist();
  }

  @override
  Future<void> cancelFriendRequest(String requestId) async {
    final me = _me();
    final row = _map('friendRequests')[requestId];
    if (row is! Map) return;
    final data = Map<String, dynamic>.from(row);
    if (data['senderId'] != me) throw CloudException('申請が見つかりません');
    data['status'] = 'cancelled';
    _map('friendRequests')[requestId] = data;
    await _persist();
  }

  @override
  Future<List<FriendRequestItem>> incomingFriendRequests() async {
    final me = _me();
    return _requestsWhere((row) => row['receiverId'] == me && row['status'] == 'pending');
  }

  @override
  Future<List<FriendRequestItem>> outgoingFriendRequests() async {
    final me = _me();
    return _requestsWhere((row) => row['senderId'] == me && row['status'] == 'pending');
  }

  @override
  Future<List<FriendProfile>> listFriends() async {
    final me = _me();
    final friends = <FriendProfile>[];
    for (final entry in _map('friendships').entries) {
      final row = Map<String, dynamic>.from(entry.value as Map);
      final a = row['userA'] as String? ?? '';
      final b = row['userB'] as String? ?? '';
      if (a != me && b != me) continue;
      final other = a == me ? b : a;
      if (_blockedPair(me, other)) continue;
      friends.add(_profileOf(other));
    }
    return friends;
  }

  @override
  Future<void> removeFriend(String uid) async {
    final me = _me();
    _map('friendships').remove(_pairKey(me, uid));
    await _revokeAclsBetween(me, uid);
    await _persist();
  }

  @override
  Future<void> blockUser(String uid) async {
    final me = _me();
    _map('blocks')['${me}_$uid'] = {
      'blockerId': me,
      'blockedId': uid,
      'createdAt': DateTime.now().toIso8601String(),
    };
    _map('friendships').remove(_pairKey(me, uid));
    await _revokeAclsBetween(me, uid);
    await _persist();
  }

  @override
  Future<List<FriendProfile>> listBlocked() async {
    final me = _me();
    final list = <FriendProfile>[];
    for (final entry in _map('blocks').entries) {
      final row = Map<String, dynamic>.from(entry.value as Map);
      if (row['blockerId'] != me) continue;
      list.add(_profileOf(row['blockedId'] as String? ?? ''));
    }
    return list;
  }

  @override
  Future<void> reportUser({required String targetId, required String reason}) async {
    final me = _me();
    final id = _id();
    _map('reports')[id] = {
      'id': id,
      'reporterId': me,
      'targetType': 'user',
      'targetId': targetId,
      'reason': reason,
      'status': 'open',
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _persist();
  }

  @override
  Future<void> shareItem({
    required SharedKind type,
    required String sourceLocalId,
    required Map<String, dynamic> payload,
    required List<String> viewerIds,
  }) async {
    final me = _me();
    final friends = {for (final f in await listFriends()) f.uid};
    final viewers = [
      for (final id in viewerIds)
        if (id != me && friends.contains(id) && !_blockedPair(me, id)) id,
    ];
    if (viewers.isEmpty) throw CloudException('共有先を選んでください');
    final items = _map('sharedItems');
    String? existingId;
    for (final entry in items.entries) {
      final row = Map<String, dynamic>.from(entry.value as Map);
      if (row['type'] != type.name ||
          row['sourceLocalId'] != sourceLocalId ||
          row['deletedAt'] != null) {
        continue;
      }
      final ownerId = row['ownerId'] as String? ?? '';
      if (!ShareAccess.ownerImmutable(existingOwnerId: ownerId, requestedOwnerId: me)) {
        throw CloudException('この共有の所有者は変えられません');
      }
      existingId = entry.key;
      break;
    }
    final id = existingId ?? _id();
    items[id] = {
      'id': id,
      'ownerId': me,
      'type': type.name,
      'sourceLocalId': sourceLocalId,
      'payload': payload,
      'updatedAt': DateTime.now().toIso8601String(),
      'deletedAt': null,
    };
    final acls = _map('shareAcl');
    acls.removeWhere((_, value) {
      if (value is! Map) return false;
      return value['itemId'] == id;
    });
    for (final viewer in viewers) {
      acls[ShareAccess.aclId(id, viewer)] = {
        'itemId': id,
        'viewerId': viewer,
        'ownerId': me,
        'status': shareStatusForNew(type),
        'createdAt': DateTime.now().toIso8601String(),
      };
      await _notify(
        viewer,
        type == SharedKind.diary ? 'share_diary' : 'share_schedule',
        me,
        targetId: id,
        title: type == SharedKind.diary ? '日記が共有されました' : '予定が共有されました',
        body: '${_profileOf(me).displayName} が「${payload['title'] ?? ''}」を共有しました。',
      );
    }
    await _persist();
  }

  @override
  Future<void> revokeShareBySource(SharedKind type, String sourceLocalId) async {
    final me = _me();
    final items = _map('sharedItems');
    for (final entry in [...items.entries]) {
      final row = Map<String, dynamic>.from(entry.value as Map);
      if (row['ownerId'] != me || row['type'] != type.name || row['sourceLocalId'] != sourceLocalId) {
        continue;
      }
      row['deletedAt'] = DateTime.now().toIso8601String();
      items[entry.key] = row;
      _map('shareAcl').removeWhere((_, value) {
        if (value is! Map) return false;
        return value['itemId'] == entry.key;
      });
    }
    await _persist();
  }

  @override
  Future<SharedItem?> findMyShare(SharedKind type, String sourceLocalId) async {
    final me = _me();
    for (final entry in _map('sharedItems').entries) {
      final row = Map<String, dynamic>.from(entry.value as Map);
      if (row['ownerId'] != me ||
          row['type'] != type.name ||
          row['sourceLocalId'] != sourceLocalId ||
          row['deletedAt'] != null) {
        continue;
      }
      final viewers = [
        for (final acl in _map('shareAcl').values)
          if (acl is Map && acl['itemId'] == entry.key) acl['viewerId'] as String? ?? '',
      ];
      return SharedItem(
        id: entry.key,
        ownerId: me,
        type: type,
        sourceLocalId: sourceLocalId,
        payload: Map<String, dynamic>.from(row['payload'] as Map? ?? {}),
        updatedAt: DateTime.tryParse(row['updatedAt'] as String? ?? '') ?? DateTime.now(),
        owner: _profileOf(me),
        viewerIds: viewers,
        shareStatus: ShareStatus.accepted,
      );
    }
    return null;
  }

  @override
  Future<List<SharedItem>> listSharedWithMe({
    SharedKind? type,
    int limit = 20,
    bool pendingOnly = false,
  }) async {
    final me = _me();
    final items = <SharedItem>[];
    for (final entry in _map('shareAcl').entries) {
      if (entry.value is! Map) continue;
      final acl = Map<String, dynamic>.from(entry.value as Map);
      if (acl['viewerId'] != me) continue;
      final status = shareStatusFrom(acl['status'] as String?);
      if (pendingOnly) {
        if (status != ShareStatus.pending) continue;
      } else if (status != ShareStatus.accepted) {
        continue;
      }
      final itemId = acl['itemId'] as String? ?? '';
      final raw = _map('sharedItems')[itemId];
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final kind = sharedKindFrom(row['type'] as String? ?? 'diary');
      if (type != null && kind != type) continue;
      final ownerId = row['ownerId'] as String? ?? '';
      if (!ShareAccess.viewerCanRead(
        viewerId: me,
        ownerId: ownerId,
        deleted: row['deletedAt'] != null,
        aclDocId: entry.key,
        aclItemId: itemId,
        aclViewerId: acl['viewerId'] as String? ?? '',
        friends: _areFriends(me, ownerId),
        blocked: _blockedPair(me, ownerId),
        aclGrantedAt: DateTime.tryParse(acl['createdAt'] as String? ?? ''),
        friendshipStartedAt: _friendshipStartedAt(me, ownerId),
      )) {
        continue;
      }
      items.add(
        SharedItem(
          id: itemId,
          ownerId: ownerId,
          type: kind,
          sourceLocalId: row['sourceLocalId'] as String? ?? '',
          payload: Map<String, dynamic>.from(row['payload'] as Map? ?? {}),
          updatedAt: DateTime.tryParse(row['updatedAt'] as String? ?? '') ?? DateTime.now(),
          owner: _profileOf(ownerId),
          aclId: entry.key,
          shareStatus: status,
        ),
      );
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (items.length <= limit) return items;
    return items.sublist(0, limit);
  }

  @override
  Future<void> respondShare(String aclId, {required bool accept}) async {
    final me = _me();
    final acls = _map('shareAcl');
    final raw = acls[aclId];
    if (raw is! Map) throw CloudException('共有が見つかりません');
    final acl = Map<String, dynamic>.from(raw);
    if (acl['viewerId'] != me) throw CloudException('共有が見つかりません');
    if (accept) {
      acl['status'] = 'accepted';
      acls[aclId] = acl;
    } else {
      acls.remove(aclId);
    }
    await _persist();
  }

  @override
  Future<void> reactToShare(String itemId, String emoji) async {
    final me = _me();
    _map('shareReactions')['${itemId}_$me'] = {
      'itemId': itemId,
      'uid': me,
      'emoji': emoji,
    };
    await _persist();
  }

  @override
  Future<List<ShareReaction>> listReactions(String itemId) async {
    return [
      for (final value in _map('shareReactions').values)
        if (value is Map && value['itemId'] == itemId)
          ShareReaction(
            itemId: itemId,
            uid: value['uid'] as String? ?? '',
            emoji: value['emoji'] as String? ?? '',
          ),
    ];
  }

  @override
  Future<void> replyToShare(String itemId, String body) async {
    final text = body.trim();
    if (text.isEmpty) throw CloudException('ひとことを入力してください');
    final me = _me();
    final id = _id();
    _map('shareReplies')[id] = {
      'id': id,
      'itemId': itemId,
      'authorId': me,
      'body': text,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _persist();
  }

  @override
  Future<List<ShareReply>> listReplies(String itemId) async {
    final items = [
      for (final value in _map('shareReplies').values)
        if (value is Map && value['itemId'] == itemId)
          ShareReply(
            id: value['id'] as String? ?? '',
            itemId: itemId,
            authorId: value['authorId'] as String? ?? '',
            body: value['body'] as String? ?? '',
            createdAt: DateTime.tryParse(value['createdAt'] as String? ?? '') ?? DateTime.now(),
            author: _profileOf(value['authorId'] as String? ?? ''),
          ),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  @override
  Future<FriendCircle> createCircle({required String name, required List<String> memberIds}) async {
    final me = _me();
    final text = name.trim();
    if (text.isEmpty) throw CloudException('グループ名を入力してください');
    final members = <String>{me, ...memberIds.where((id) => id != me)};
    final id = _id();
    _map('circles')[id] = {
      'id': id,
      'name': text,
      'ownerId': me,
      'memberIds': members.toList(),
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _persist();
    return _circleOf(id);
  }

  FriendCircle _circleOf(String id) {
    final row = Map<String, dynamic>.from(_map('circles')[id] as Map? ?? {});
    return FriendCircle(
      id: id,
      name: row['name'] as String? ?? '',
      ownerId: row['ownerId'] as String? ?? '',
      memberIds: [
        for (final id in (row['memberIds'] as List? ?? const []))
          if (id is String && id.isNotEmpty) id,
      ],
      createdAt: DateTime.tryParse(row['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<void> updateCircle(FriendCircle circle) async {
    final me = _me();
    final row = _map('circles')[circle.id];
    if (row is! Map || row['ownerId'] != me) throw CloudException('グループを変えられません');
    final members = <String>{me, ...circle.memberIds};
    _map('circles')[circle.id] = {
      ...Map<String, dynamic>.from(row),
      'name': circle.name.trim(),
      'memberIds': members.toList(),
    };
    await _persist();
  }

  @override
  Future<void> deleteCircle(String id) async {
    final me = _me();
    final row = _map('circles')[id];
    if (row is! Map || row['ownerId'] != me) throw CloudException('グループを消せません');
    _map('circles').remove(id);
    _map('circlePolls').removeWhere((_, value) => value is Map && value['circleId'] == id);
    _map('circleWants').removeWhere((_, value) => value is Map && value['circleId'] == id);
    await _persist();
  }

  @override
  Future<List<FriendCircle>> listCircles() async {
    final me = _me();
    return [
      for (final entry in _map('circles').entries)
        if (entry.value is Map)
          _circleOf(entry.key)
    ].where((c) => c.ownerId == me || c.memberIds.contains(me)).toList();
  }

  @override
  Future<CirclePoll> createPoll({
    required String circleId,
    required String title,
    required List<String> options,
  }) async {
    final me = _me();
    final circle = _circleOf(circleId);
    if (!circle.memberIds.contains(me) && circle.ownerId != me) {
      throw CloudException('グループのメンバーではありません');
    }
    final cleaned = [for (final o in options) if (o.trim().isNotEmpty) o.trim()];
    if (title.trim().isEmpty || cleaned.length < 2) throw CloudException('日程の候補を2つ以上入れてください');
    final id = _id();
    _map('circlePolls')[id] = {
      'id': id,
      'circleId': circleId,
      'title': title.trim(),
      'options': cleaned,
      'votes': <String, dynamic>{},
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _persist();
    return _pollOf(id);
  }

  CirclePoll _pollOf(String id) {
    final row = Map<String, dynamic>.from(_map('circlePolls')[id] as Map? ?? {});
    final votes = <String, int>{};
    final raw = row['votes'];
    if (raw is Map) {
      for (final e in raw.entries) {
        votes[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    return CirclePoll(
      id: id,
      circleId: row['circleId'] as String? ?? '',
      title: row['title'] as String? ?? '',
      options: [
        for (final o in (row['options'] as List? ?? const []))
          if (o is String) o,
      ],
      votes: votes,
      createdAt: DateTime.tryParse(row['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<void> votePoll(String pollId, int optionIndex) async {
    final me = _me();
    final poll = _pollOf(pollId);
    if (optionIndex < 0 || optionIndex >= poll.options.length) return;
    final circle = _circleOf(poll.circleId);
    if (!circle.memberIds.contains(me) && circle.ownerId != me) {
      throw CloudException('グループのメンバーではありません');
    }
    final row = Map<String, dynamic>.from(_map('circlePolls')[pollId] as Map);
    final votes = Map<String, dynamic>.from(row['votes'] as Map? ?? {});
    votes[me] = optionIndex;
    row['votes'] = votes;
    _map('circlePolls')[pollId] = row;
    await _persist();
  }

  @override
  Future<List<CirclePoll>> listPolls(String circleId) async {
    final list = [
      for (final entry in _map('circlePolls').entries)
        if (entry.value is Map && (entry.value as Map)['circleId'] == circleId) _pollOf(entry.key),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<CircleWant> addWant({required String circleId, required String title}) async {
    final me = _me();
    final text = title.trim();
    if (text.isEmpty) throw CloudException('やりたいことを入力してください');
    final id = _id();
    _map('circleWants')[id] = {
      'id': id,
      'circleId': circleId,
      'title': text,
      'done': false,
      'creatorId': me,
    };
    await _persist();
    return _wantOf(id);
  }

  CircleWant _wantOf(String id) {
    final row = Map<String, dynamic>.from(_map('circleWants')[id] as Map? ?? {});
    return CircleWant(
      id: id,
      circleId: row['circleId'] as String? ?? '',
      title: row['title'] as String? ?? '',
      done: row['done'] as bool? ?? false,
      creatorId: row['creatorId'] as String? ?? '',
    );
  }

  @override
  Future<void> toggleWant(String wantId) async {
    final row = _map('circleWants')[wantId];
    if (row is! Map) return;
    row['done'] = !(row['done'] as bool? ?? false);
    _map('circleWants')[wantId] = Map<String, dynamic>.from(row);
    await _persist();
  }

  @override
  Future<List<CircleWant>> listWants(String circleId) async {
    return [
      for (final entry in _map('circleWants').entries)
        if (entry.value is Map && (entry.value as Map)['circleId'] == circleId) _wantOf(entry.key),
    ];
  }

  @override
  Future<MemoryAlbum> createAlbum({
    required String title,
    required List<String> participantIds,
    String? circleId,
  }) async {
    final me = _me();
    final text = title.trim();
    if (text.isEmpty) throw CloudException('アルバム名を入力してください');
    final id = _id();
    final people = <String>{me, ...participantIds};
    _map('memoryAlbums')[id] = {
      'id': id,
      'title': text,
      'ownerId': me,
      'participantIds': people.toList(),
      'circleId': circleId,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _persist();
    return _albumOf(id);
  }

  MemoryAlbum _albumOf(String id) {
    final row = Map<String, dynamic>.from(_map('memoryAlbums')[id] as Map? ?? {});
    return MemoryAlbum(
      id: id,
      title: row['title'] as String? ?? '',
      ownerId: row['ownerId'] as String? ?? '',
      participantIds: [
        for (final id in (row['participantIds'] as List? ?? const []))
          if (id is String && id.isNotEmpty) id,
      ],
      circleId: row['circleId'] as String?,
      createdAt: DateTime.tryParse(row['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<List<MemoryAlbum>> listAlbums() async {
    final me = _me();
    return [
      for (final entry in _map('memoryAlbums').entries)
        if (entry.value is Map) _albumOf(entry.key),
    ].where((a) => a.ownerId == me || a.participantIds.contains(me)).toList();
  }

  @override
  Future<void> updateAlbum(MemoryAlbum album) async {
    final me = _me();
    final row = _map('memoryAlbums')[album.id];
    if (row is! Map || row['ownerId'] != me) throw CloudException('アルバムを変えられません');
    final people = <String>{me, ...album.participantIds};
    _map('memoryAlbums')[album.id] = {
      ...Map<String, dynamic>.from(row),
      'title': album.title.trim(),
      'participantIds': people.toList(),
      'circleId': album.circleId,
    };
    await _persist();
  }

  @override
  Future<void> addMemoryPhoto({
    required String albumId,
    required DateTime day,
    String dataB64 = '',
    String url = '',
    String mime = 'image/jpeg',
  }) async {
    final me = _me();
    var storedUrl = url;
    final storedB64 = dataB64;
    if (storedUrl.isEmpty && storedB64.isNotEmpty) {
      storedUrl = 'data:$mime;base64,$storedB64';
    }
    if (storedUrl.isEmpty) throw CloudException('写真を選べませんでした');
    final id = _id();
    _map('memoryPhotos')[id] = {
      'id': id,
      'albumId': albumId,
      'day': DateTime(day.year, day.month, day.day).toIso8601String(),
      'authorId': me,
      'dataB64': storedB64,
      'url': storedUrl,
      'mime': mime,
    };
    await _persist();
  }

  @override
  Future<List<MemoryPhoto>> listMemoryPhotos(String albumId) async {
    final list = [
      for (final value in _map('memoryPhotos').values)
        if (value is Map && value['albumId'] == albumId)
          MemoryPhoto(
            id: value['id'] as String? ?? '',
            albumId: albumId,
            day: DateTime.tryParse(value['day'] as String? ?? '') ?? DateTime.now(),
            authorId: value['authorId'] as String? ?? '',
            dataB64: value['dataB64'] as String? ?? '',
            url: value['url'] as String? ?? '',
            mime: value['mime'] as String? ?? 'image/jpeg',
          ),
    ]..sort((a, b) => b.day.compareTo(a.day));
    return list;
  }

  @override
  Future<void> addPhotoComment({
    required String albumId,
    required String photoId,
    required String body,
  }) async {
    final text = body.trim();
    if (text.isEmpty) throw CloudException('コメントを入力してください');
    final me = _me();
    final id = _id();
    _map('photoComments')[id] = {
      'id': id,
      'albumId': albumId,
      'photoId': photoId,
      'authorId': me,
      'body': text,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _persist();
  }

  @override
  Future<List<PhotoComment>> listPhotoComments({
    required String albumId,
    required String photoId,
  }) async {
    final items = [
      for (final value in _map('photoComments').values)
        if (value is Map && value['albumId'] == albumId && value['photoId'] == photoId)
          PhotoComment(
            id: value['id'] as String? ?? '',
            photoId: photoId,
            authorId: value['authorId'] as String? ?? '',
            body: value['body'] as String? ?? '',
            createdAt: DateTime.tryParse(value['createdAt'] as String? ?? '') ?? DateTime.now(),
            author: _profileOf(value['authorId'] as String? ?? ''),
          ),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  @override
  Future<String> ensureDmChat(String otherUid) async {
    final me = _me();
    final id = 'dm_${_pairKey(me, otherUid)}';
    _map('chats')[id] = {
      'id': id,
      'type': 'dm',
      'memberIds': [me, otherUid],
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _persist();
    return id;
  }

  @override
  Future<String> ensureCircleChat(FriendCircle circle) async {
    final me = _me();
    if (!circle.memberIds.contains(me) && circle.ownerId != me) {
      throw CloudException('グループのメンバーではありません');
    }
    final id = 'circle_${circle.id}';
    final members = <String>{me, circle.ownerId, ...circle.memberIds};
    _map('chats')[id] = {
      'id': id,
      'type': 'circle',
      'circleId': circle.id,
      'memberIds': members.toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _persist();
    return id;
  }

  @override
  Future<List<TalkMessage>> listMessages(String chatId) async {
    final items = [
      for (final value in _map('talkMessages').values)
        if (value is Map && value['chatId'] == chatId)
          TalkMessage(
            id: value['id'] as String? ?? '',
            chatId: chatId,
            authorId: value['authorId'] as String? ?? '',
            body: value['body'] as String? ?? '',
            imageUrl: value['imageUrl'] as String? ?? '',
            createdAt: DateTime.tryParse(value['createdAt'] as String? ?? '') ?? DateTime.now(),
            author: _profileOf(value['authorId'] as String? ?? ''),
          ),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  @override
  Future<void> sendMessage(String chatId, {String body = '', String imageUrl = ''}) async {
    final text = body.trim();
    if (text.isEmpty && imageUrl.isEmpty) throw CloudException('メッセージを入力してください');
    final me = _me();
    final chat = _map('chats')[chatId];
    if (chat is! Map) throw CloudException('トークが見つかりません');
    final members = [
      for (final id in (chat['memberIds'] as List? ?? const []))
        if (id is String) id,
    ];
    if (!members.contains(me)) throw CloudException('トークのメンバーではありません');
    final id = _id();
    _map('talkMessages')[id] = {
      'id': id,
      'chatId': chatId,
      'authorId': me,
      'body': text,
      'imageUrl': imageUrl,
      'createdAt': DateTime.now().toIso8601String(),
    };
    chat['updatedAt'] = DateTime.now().toIso8601String();
    chat['lastText'] = text.isEmpty ? '写真' : text;
    _map('chats')[chatId] = Map<String, dynamic>.from(chat);
    await _persist();
  }

  @override
  Future<void> markFriendNoticeRead(String id) async {
    final me = _me();
    final list = [
      for (final item in ((_map('friendNotices')[me] as List?) ?? const []))
        if (item is Map)
          {
            ...item,
            if (item['id'] == id) 'readAt': DateTime.now().toIso8601String(),
          }
        else
          item,
    ];
    _map('friendNotices')[me] = list;
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
    final row = _profileMap(session.uid);
    row['displayName'] = session.displayName;
    row['occupation'] = session.occupation;
    row['uid'] = session.uid;
  }
}
