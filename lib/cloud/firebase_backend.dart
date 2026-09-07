import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cloud_backend.dart';
import 'cloud_models.dart';
import 'friend_models.dart';
import 'password.dart';
import 'share_access.dart';

class FirebaseBackend implements CloudBackend {
  FirebaseBackend({FirebaseAuth? auth, FirebaseFirestore? store})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = store ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  bool get usesFirebase => true;

  CloudSession? _session;

  @override
  CloudSession? get currentSession => _session;

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);

  ActionCodeSettings _continueSettings() {
    return ActionCodeSettings(
      url: 'https://jitian857-ops.github.io/nexus/',
      handleCodeInApp: false,
    );
  }

  Future<void> _sendVerificationEmail(User user) async {
    await _auth.setLanguageCode('ja');
    try {
      await user.sendEmailVerification(_continueSettings());
    } catch (error) {
      final text = error.toString();
      final continueUriBad = error is FirebaseAuthException &&
              (error.code == 'unauthorized-continue-uri' ||
                  error.code == 'invalid-continue-uri' ||
                  error.code == 'missing-continue-uri') ||
          text.contains('continue-uri') ||
          text.contains('continue_uri');
      if (continueUriBad) {
        await user.sendEmailVerification();
        return;
      }
      rethrow;
    }
  }

  Future<void> _safeAddMail(String uid, MailItem item) async {
    try {
      await addMail(uid, item);
    } catch (_) {}
  }

  @override
  Future<void> init() async {
    await _auth.setLanguageCode('ja');
    final user = _auth.currentUser;
    if (user == null) {
      _session = null;
      return;
    }
    _session = await _sessionFrom(user);
  }

  Future<CloudSession> _sessionFrom(User user) async {
    final snap = await _user(user.uid).get();
    final data = snap.data() ?? {};
    return CloudSession(
      uid: user.uid,
      email: user.email ?? '',
      displayName: (data['displayName'] as String?) ?? user.displayName ?? '',
      occupation: data['occupation'] as String? ?? '',
      emailVerified: user.emailVerified,
      usesFirebase: true,
    );
  }

  Future<void> _writeProfile(User user, {required String displayName, required String occupation}) async {
    await _user(user.uid).set(
      {
        'email': user.email,
        'displayName': displayName,
        'occupation': occupation,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await _db.collection('profiles').doc(user.uid).set(
      {
        'uid': user.uid,
        'displayName': displayName,
        'occupation': occupation,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<CloudSession> signUp({
    required String email,
    required String password,
    required String displayName,
    required String occupation,
  }) async {
    if (!isValidEmail(email)) throw CloudException('メールアドレスの形が正しくありません');
    if (!isValidPassword(password)) throw CloudException('パスワードは8文字以上にしてください');
    if (displayName.trim().isEmpty) throw CloudException('名前を入力してください');
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) throw CloudException('登録できませんでした');
      await user.updateDisplayName(displayName.trim());
      await _writeProfile(user, displayName: displayName.trim(), occupation: occupation.trim());
      await _sendVerificationEmail(user);
      _session = await _sessionFrom(user);
      await ensureFriendCode();
      await _safeAddMail(
        user.uid,
        MailItem(
          id: _db.collection('_').doc().id,
          title: 'NEXUS へようこそ',
          body: '${user.email} の受信箱（Gmail など）を見てください。送信元は noreply@nexus-50e0e.firebaseapp.com です。この画面は控えです。',
          at: DateTime.now(),
          kind: 'verify',
        ),
      );
      return _session!;
    } catch (error) {
      throw CloudException(cloudErrorMessage(error));
    }
  }

  @override
  Future<CloudSession> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) throw CloudException('ログインできませんでした');
      _session = await _sessionFrom(user);
      return _session!;
    } catch (error) {
      throw CloudException(cloudErrorMessage(error));
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _session = null;
  }

  @override
  Future<void> sendVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw CloudException('ログインしてください');
    await _sendVerificationEmail(user);
    await _safeAddMail(
      user.uid,
      MailItem(
        id: _db.collection('_').doc().id,
        title: '認証メールを再送しました',
        body: '${user.email} の受信箱と迷惑メールを見てください。送信元は noreply@nexus-50e0e.firebaseapp.com です。',
        at: DateTime.now(),
        kind: 'verify',
      ),
    );
  }

  @override
  Future<CloudSession> confirmVerification({String? code}) async {
    final user = _auth.currentUser;
    if (user == null) throw CloudException('ログインしてください');
    await user.reload();
    final fresh = _auth.currentUser;
    if (fresh == null) throw CloudException('ログインしてください');
    if (!fresh.emailVerified) {
      throw CloudException('メールのリンクを開いてから、もう一度確認してください');
    }
    _session = await _sessionFrom(fresh);
    await _safeAddMail(
      fresh.uid,
      MailItem(
        id: _db.collection('_').doc().id,
        title: 'メールアドレスを認証しました',
        body: '${fresh.email} の認証が完了しました。',
        at: DateTime.now(),
        kind: 'verify',
      ),
    );
    return _session!;
  }

  @override
  Future<CloudSession> refreshSession() async {
    final user = _auth.currentUser;
    if (user == null) throw CloudException('ログインしてください');
    await user.reload();
    _session = await _sessionFrom(_auth.currentUser!);
    return _session!;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (!isValidEmail(email)) throw CloudException('メールアドレスの形が正しくありません');
    try {
      await _auth.setLanguageCode('ja');
      try {
        await _auth.sendPasswordResetEmail(
          email: email.trim(),
          actionCodeSettings: _continueSettings(),
        );
      } on FirebaseAuthException catch (error) {
        if (error.code == 'unauthorized-continue-uri' ||
            error.code == 'invalid-continue-uri' ||
            error.code == 'missing-continue-uri') {
          await _auth.sendPasswordResetEmail(email: email.trim());
          return;
        }
        rethrow;
      }
    } catch (error) {
      throw CloudException(cloudErrorMessage(error));
    }
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (!isValidPassword(newPassword)) throw CloudException('パスワードは8文字以上にしてください');
    try {
      await _auth.confirmPasswordReset(code: code.trim(), newPassword: newPassword);
    } catch (error) {
      throw CloudException(cloudErrorMessage(error));
    }
  }

  @override
  Future<CloudSession> updateProfile({
    required String displayName,
    required String occupation,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw CloudException('ログインしてください');
    if (displayName.trim().isEmpty) throw CloudException('名前を入力してください');
    await user.updateDisplayName(displayName.trim());
    await _writeProfile(user, displayName: displayName.trim(), occupation: occupation.trim());
    _session = (await _sessionFrom(user)).copyWith(
      displayName: displayName.trim(),
      occupation: occupation.trim(),
    );
    return _session!;
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw CloudException('ログインしてください');
    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);
      await _user(user.uid).set({'purge': true}, SetOptions(merge: true));
      final uid = user.uid;
      await _deleteCollection(_user(uid).collection('mail'));
      await _deleteCollection(_user(uid).collection('vault'));
      await _deleteDoc(_user(uid).collection('live').doc('current'));
      await _user(uid).delete();
      await user.delete();
      _session = null;
    } catch (error) {
      throw CloudException(cloudErrorMessage(error));
    }
  }

  Future<void> _deleteDoc(DocumentReference<Map<String, dynamic>> doc) async {
    try {
      await doc.delete();
    } catch (_) {}
  }

  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> col) async {
    final snap = await col.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Future<Map<String, dynamic>?> pullLive(String uid) async {
    final snap = await _user(uid).collection('live').doc('current').get();
    return snap.data();
  }

  @override
  Future<void> pushLive(String uid, Map<String, dynamic> bundle) async {
    await _user(uid).collection('live').doc('current').set(bundle);
  }

  @override
  Future<void> sealVault(String uid, String reason, Map<String, dynamic> bundle) async {
    final encoded = bundle.toString();
    await _user(uid).collection('vault').add({
      'at': DateTime.now().toIso8601String(),
      'reason': reason,
      'bytes': encoded.length,
      'sealed': true,
      'data': bundle,
    });
  }

  @override
  Future<List<VaultRecord>> listVault(String uid) async {
    final snap = await _user(uid).collection('vault').orderBy('at', descending: true).get();
    return [
      for (final doc in snap.docs)
        VaultRecord(
          id: doc.id,
          at: DateTime.tryParse(doc.data()['at'] as String? ?? '') ?? DateTime.now(),
          reason: doc.data()['reason'] as String? ?? '',
          bytes: doc.data()['bytes'] as int? ?? 0,
        ),
    ];
  }

  @override
  Future<VaultRecord?> readVault(String uid, String id) async {
    final snap = await _user(uid).collection('vault').doc(id).get();
    final data = snap.data();
    if (data == null) return null;
    final payload = data['data'];
    return VaultRecord(
      id: snap.id,
      at: DateTime.tryParse(data['at'] as String? ?? '') ?? DateTime.now(),
      reason: data['reason'] as String? ?? '',
      bytes: data['bytes'] as int? ?? 0,
      data: payload is Map ? Map<String, dynamic>.from(payload) : null,
    );
  }

  @override
  Future<List<MailItem>> listMail(String uid) async {
    final snap = await _user(uid).collection('mail').orderBy('at', descending: true).get();
    return [
      for (final doc in snap.docs)
        MailItem.fromJson({
          ...doc.data(),
          'id': doc.id,
        }),
    ];
  }

  @override
  Future<void> addMail(String uid, MailItem item) async {
    await _user(uid).collection('mail').doc(item.id).set(item.toJson());
  }

  @override
  Future<void> markMailRead(String uid, String id) async {
    await _user(uid).collection('mail').doc(id).set({'read': true}, SetOptions(merge: true));
  }

  String _uid() {
    final uid = _auth.currentUser?.uid ?? _session?.uid;
    if (uid == null || uid.isEmpty) throw CloudException('ログインしてください');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _profile(String uid) => _db.collection('profiles').doc(uid);

  Future<FriendProfile> _readProfile(String uid) async {
    final snap = await _profile(uid).get();
    final data = snap.data() ?? {};
    return FriendProfile(
      uid: uid,
      displayName: data['displayName'] as String? ?? 'ユーザー',
      friendCode: data['friendCode'] as String? ?? '',
      occupation: data['occupation'] as String? ?? '',
    );
  }

  Future<bool> _blockedPair(String a, String b) async {
    final one = await _db.collection('blocks').doc('${a}_$b').get();
    if (one.exists) return true;
    final two = await _db.collection('blocks').doc('${b}_$a').get();
    return two.exists;
  }

  Future<bool> _areFriends(String a, String b) async {
    final snap = await _db.collection('friendships').doc(_pairKey(a, b)).get();
    return snap.exists;
  }

  Future<DateTime?> _friendshipStartedAt(String a, String b) async {
    final snap = await _db.collection('friendships').doc(_pairKey(a, b)).get();
    return DateTime.tryParse(snap.data()?['created_at'] as String? ?? '');
  }

  String _pairKey(String a, String b) {
    final first = a.compareTo(b) < 0 ? a : b;
    final second = first == a ? b : a;
    return '${first}_$second';
  }

  Future<void> _notify(String userId, String type, String actorId, {String? targetId, String? title, String? body}) async {
    await _db.collection('notifications').add({
      'user_id': userId,
      'type': type,
      'actor_id': actorId,
      'target_id': targetId,
      'title': title,
      'body': body,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<FriendProfile> ensureFriendCode({bool regenerate = false}) async {
    final uid = _uid();
    final snap = await _profile(uid).get();
    final current = snap.data()?['friendCode'] as String? ?? '';
    if (!regenerate && current.isNotEmpty) return _readProfile(uid);
    if (current.isNotEmpty) {
      await _db.collection('friend_codes').doc(current).delete();
    }
    String code = generateFriendCode();
    for (var i = 0; i < 8; i++) {
      final exists = await _db.collection('friend_codes').doc(code).get();
      if (!exists.exists) break;
      code = generateFriendCode();
    }
    await _db.collection('friend_codes').doc(code).set({'uid': uid});
    await _profile(uid).set(
      {
        'uid': uid,
        'friendCode': code,
        'displayName': _session?.displayName ?? _auth.currentUser?.displayName ?? 'ユーザー',
        'occupation': _session?.occupation ?? '',
      },
      SetOptions(merge: true),
    );
    return _readProfile(uid);
  }

  @override
  Future<FriendProfile?> lookupFriend(String query) async {
    final me = _uid();
    final q = normalizeFriendQuery(query);
    if (q.isEmpty) return null;
    String? uid;
    if (q.length == 8) {
      final code = await _db.collection('friend_codes').doc(q).get();
      uid = code.data()?['uid'] as String?;
    }
    uid ??= query.trim();
    if (uid.isEmpty) return null;
    if (uid == me) throw CloudException('自分は追加できません');
    if (await _blockedPair(me, uid)) return null;
    final snap = await _profile(uid).get();
    if (!snap.exists) return null;
    return _readProfile(uid);
  }

  @override
  Future<void> sendFriendRequest(String toUid) async {
    final me = _uid();
    if (me == toUid) throw CloudException('自分は追加できません');
    if (await _blockedPair(me, toUid)) throw CloudException('申請できません');
    final friend = await _db.collection('friendships').doc(_pairKey(me, toUid)).get();
    if (friend.exists) throw CloudException('すでにフレンドです');
    final mine = await _db.collection('friend_requests').where('sender_id', isEqualTo: me).get();
    final theirs = await _db.collection('friend_requests').where('receiver_id', isEqualTo: me).get();
    for (final doc in [...mine.docs, ...theirs.docs]) {
      final row = doc.data();
      if (row['status'] != 'pending') continue;
      final sender = row['sender_id'] as String? ?? '';
      final receiver = row['receiver_id'] as String? ?? '';
      if ((sender == me && receiver == toUid) || (sender == toUid && receiver == me)) {
        throw CloudException('すでに申請中です');
      }
    }
    final ref = _db.collection('friend_requests').doc();
    await ref.set({
      'sender_id': me,
      'receiver_id': toUid,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
    final meProfile = await _readProfile(me);
    await _notify(
      toUid,
      'friend_request',
      me,
      targetId: ref.id,
      title: 'フレンド申請が届きました',
      body: '${meProfile.displayName} からフレンド申請が届きました。',
    );
  }

  FriendRequestItem _requestFrom(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return FriendRequestItem(
      id: doc.id,
      senderId: data['sender_id'] as String? ?? '',
      receiverId: data['receiver_id'] as String? ?? '',
      status: requestStatusFrom(data['status'] as String? ?? 'pending'),
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<void> respondFriendRequest(String requestId, {required bool accept}) async {
    final me = _uid();
    final ref = _db.collection('friend_requests').doc(requestId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) throw CloudException('申請が見つかりません');
    if (data['receiver_id'] != me) throw CloudException('申請が見つかりません');
    if (data['status'] != 'pending') throw CloudException('この申請は処理済みです');
    final sender = data['sender_id'] as String? ?? '';
    await ref.update({'status': accept ? 'accepted' : 'rejected'});
    if (accept) {
      final a = me.compareTo(sender) < 0 ? me : sender;
      final b = a == me ? sender : me;
      await _db.collection('friendships').doc('${a}_$b').set({
        'user_a': a,
        'user_b': b,
        'created_at': DateTime.now().toIso8601String(),
      });
      final meProfile = await _readProfile(me);
      await _notify(
        sender,
        'friend_accept',
        me,
        targetId: requestId,
        title: '申請が承認されました',
        body: '${meProfile.displayName} がフレンド申請を承認しました。',
      );
    }
  }

  @override
  Future<void> cancelFriendRequest(String requestId) async {
    final me = _uid();
    final ref = _db.collection('friend_requests').doc(requestId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;
    if (data['sender_id'] != me) throw CloudException('申請が見つかりません');
    await ref.update({'status': 'cancelled'});
  }

  Future<List<FriendRequestItem>> _fillRequestProfiles(List<FriendRequestItem> items) async {
    return [
      for (final item in items)
        FriendRequestItem(
          id: item.id,
          senderId: item.senderId,
          receiverId: item.receiverId,
          status: item.status,
          createdAt: item.createdAt,
          sender: await _readProfile(item.senderId),
          receiver: await _readProfile(item.receiverId),
        ),
    ];
  }

  @override
  Future<List<FriendRequestItem>> incomingFriendRequests() async {
    final me = _uid();
    final snap = await _db.collection('friend_requests').where('receiver_id', isEqualTo: me).get();
    final items = [
      for (final doc in snap.docs)
        if (doc.data()['status'] == 'pending') _requestFrom(doc),
    ];
    return _fillRequestProfiles(items);
  }

  @override
  Future<List<FriendRequestItem>> outgoingFriendRequests() async {
    final me = _uid();
    final snap = await _db.collection('friend_requests').where('sender_id', isEqualTo: me).get();
    final items = [
      for (final doc in snap.docs)
        if (doc.data()['status'] == 'pending') _requestFrom(doc),
    ];
    return _fillRequestProfiles(items);
  }

  @override
  Future<List<FriendProfile>> listFriends() async {
    final me = _uid();
    final a = await _db.collection('friendships').where('user_a', isEqualTo: me).get();
    final b = await _db.collection('friendships').where('user_b', isEqualTo: me).get();
    final others = <String>{};
    for (final doc in [...a.docs, ...b.docs]) {
      final ua = doc.data()['user_a'] as String? ?? '';
      final ub = doc.data()['user_b'] as String? ?? '';
      others.add(ua == me ? ub : ua);
    }
    final list = <FriendProfile>[];
    for (final uid in others) {
      if (await _blockedPair(me, uid)) continue;
      list.add(await _readProfile(uid));
    }
    return list;
  }

  @override
  Future<void> removeFriend(String uid) async {
    final me = _uid();
    await _db.collection('friendships').doc(_pairKey(me, uid)).delete();
    await _revokeAclsBetween(me, uid);
  }

  Future<void> _revokeAclsBetween(String a, String b) async {
    final mine = await _db.collection('share_acl').where('viewer_id', isEqualTo: b).get();
    for (final doc in mine.docs) {
      final itemId = doc.data()['item_id'] as String? ?? '';
      final item = await _db.collection('shared_items').doc(itemId).get();
      if (item.data()?['owner_id'] == a) await doc.reference.delete();
    }
    final theirs = await _db.collection('share_acl').where('viewer_id', isEqualTo: a).get();
    for (final doc in theirs.docs) {
      final itemId = doc.data()['item_id'] as String? ?? '';
      final item = await _db.collection('shared_items').doc(itemId).get();
      if (item.data()?['owner_id'] == b) await doc.reference.delete();
    }
  }

  @override
  Future<void> blockUser(String uid) async {
    final me = _uid();
    await _db.collection('blocks').doc('${me}_$uid').set({
      'blocker_id': me,
      'blocked_id': uid,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _db.collection('friendships').doc(_pairKey(me, uid)).delete();
    await _revokeAclsBetween(me, uid);
  }

  @override
  Future<List<FriendProfile>> listBlocked() async {
    final me = _uid();
    final snap = await _db.collection('blocks').where('blocker_id', isEqualTo: me).get();
    return [
      for (final doc in snap.docs) await _readProfile(doc.data()['blocked_id'] as String? ?? ''),
    ];
  }

  @override
  Future<void> reportUser({required String targetId, required String reason}) async {
    final me = _uid();
    await _db.collection('reports').add({
      'reporter_id': me,
      'target_type': 'user',
      'target_id': targetId,
      'reason': reason,
      'status': 'open',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> shareItem({
    required SharedKind type,
    required String sourceLocalId,
    required Map<String, dynamic> payload,
    required List<String> viewerIds,
  }) async {
    final me = _uid();
    final friends = {for (final f in await listFriends()) f.uid};
    final viewers = [
      for (final id in viewerIds)
        if (id != me && friends.contains(id) && !(await _blockedPair(me, id))) id,
    ];
    if (viewers.isEmpty) throw CloudException('共有先を選んでください');
    final existing = await _db.collection('shared_items').where('owner_id', isEqualTo: me).get();
    DocumentReference<Map<String, dynamic>> ref;
    final match = existing.docs.where(
      (d) =>
          d.data()['source_local_id'] == sourceLocalId &&
          d.data()['type'] == type.name &&
          d.data()['deleted_at'] == null,
    );
    if (match.isNotEmpty) {
      ref = match.first.reference;
      final existingOwner = match.first.data()['owner_id'] as String? ?? '';
      if (!ShareAccess.ownerImmutable(existingOwnerId: existingOwner, requestedOwnerId: me)) {
        throw CloudException('この共有の所有者は変えられません');
      }
      await ref.set({
        'owner_id': me,
        'type': type.name,
        'source_local_id': sourceLocalId,
        'payload': payload,
        'updated_at': DateTime.now().toIso8601String(),
        'deleted_at': null,
      }, SetOptions(merge: true));
      final oldAcl = await _db.collection('share_acl').where('item_id', isEqualTo: ref.id).get();
      for (final doc in oldAcl.docs) {
        await doc.reference.delete();
      }
    } else {
      ref = _db.collection('shared_items').doc();
      await ref.set({
        'owner_id': me,
        'type': type.name,
        'source_local_id': sourceLocalId,
        'payload': payload,
        'updated_at': DateTime.now().toIso8601String(),
        'deleted_at': null,
      });
    }
    final meProfile = await _readProfile(me);
    for (final viewer in viewers) {
      await _db.collection('share_acl').doc(ShareAccess.aclId(ref.id, viewer)).set({
        'item_id': ref.id,
        'viewer_id': viewer,
        'created_at': DateTime.now().toIso8601String(),
      });
      await _notify(
        viewer,
        type == SharedKind.diary ? 'share_diary' : 'share_schedule',
        me,
        targetId: ref.id,
        title: type == SharedKind.diary ? '日記が共有されました' : '予定が共有されました',
        body: '${meProfile.displayName} が「${payload['title'] ?? ''}」を共有しました。',
      );
    }
  }

  @override
  Future<void> revokeShareBySource(SharedKind type, String sourceLocalId) async {
    final me = _uid();
    final snap = await _db.collection('shared_items').where('owner_id', isEqualTo: me).get();
    for (final doc in snap.docs) {
      if (doc.data()['type'] != type.name || doc.data()['source_local_id'] != sourceLocalId) continue;
      await doc.reference.update({'deleted_at': DateTime.now().toIso8601String()});
      final acls = await _db.collection('share_acl').where('item_id', isEqualTo: doc.id).get();
      for (final acl in acls.docs) {
        await acl.reference.delete();
      }
    }
  }

  @override
  Future<SharedItem?> findMyShare(SharedKind type, String sourceLocalId) async {
    final me = _uid();
    final snap = await _db.collection('shared_items').where('owner_id', isEqualTo: me).get();
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['type'] != type.name || data['source_local_id'] != sourceLocalId || data['deleted_at'] != null) {
        continue;
      }
      final acls = await _db.collection('share_acl').where('item_id', isEqualTo: doc.id).get();
      return SharedItem(
        id: doc.id,
        ownerId: me,
        type: type,
        sourceLocalId: sourceLocalId,
        payload: Map<String, dynamic>.from(data['payload'] as Map? ?? {}),
        updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ?? DateTime.now(),
        owner: await _readProfile(me),
        viewerIds: [for (final acl in acls.docs) acl.data()['viewer_id'] as String? ?? ''],
      );
    }
    return null;
  }

  @override
  Future<List<SharedItem>> listSharedWithMe({SharedKind? type, int limit = 20}) async {
    final me = _uid();
    final acls = await _db.collection('share_acl').where('viewer_id', isEqualTo: me).get();
    final items = <SharedItem>[];
    for (final acl in acls.docs) {
      final itemId = acl.data()['item_id'] as String? ?? '';
      final snap = await _db.collection('shared_items').doc(itemId).get();
      final data = snap.data();
      if (data == null) continue;
      final kind = sharedKindFrom(data['type'] as String? ?? 'diary');
      if (type != null && kind != type) continue;
      final ownerId = data['owner_id'] as String? ?? '';
      if (!ShareAccess.viewerCanRead(
        viewerId: me,
        ownerId: ownerId,
        deleted: data['deleted_at'] != null,
        aclDocId: acl.id,
        aclItemId: itemId,
        aclViewerId: acl.data()['viewer_id'] as String? ?? '',
        friends: await _areFriends(me, ownerId),
        blocked: await _blockedPair(me, ownerId),
        aclGrantedAt: DateTime.tryParse(acl.data()['created_at'] as String? ?? ''),
        friendshipStartedAt: await _friendshipStartedAt(me, ownerId),
      )) {
        continue;
      }
      items.add(
        SharedItem(
          id: snap.id,
          ownerId: ownerId,
          type: kind,
          sourceLocalId: data['source_local_id'] as String? ?? '',
          payload: Map<String, dynamic>.from(data['payload'] as Map? ?? {}),
          updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ?? DateTime.now(),
          owner: await _readProfile(ownerId),
        ),
      );
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items.take(limit).toList();
  }

  @override
  Future<void> markFriendNoticeRead(String id) async {
    await _db.collection('notifications').doc(id).set(
      {'read_at': DateTime.now().toIso8601String()},
      SetOptions(merge: true),
    );
  }
}
