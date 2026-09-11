import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/image_compress.dart';
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
    } on FirebaseAuthException {
      await user.sendEmailVerification();
    }
  }

  Future<void> _bindUser(User user) async {
    await user.getIdToken();
    _session = await _sessionFrom(user);
  }

  Future<void> _writeProfileReady(User user, {required String displayName, required String occupation}) async {
    await user.getIdToken(true);
    try {
      await _writeProfile(user, displayName: displayName, occupation: occupation);
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await user.getIdToken(true);
      await _writeProfile(user, displayName: displayName, occupation: occupation);
    }
  }

  Future<CloudSession> _completeSignUp(
    User user, {
    required String displayName,
    required String occupation,
  }) async {
    final name = displayName.trim();
    final job = occupation.trim();
    try {
      await user.updateDisplayName(name);
    } catch (_) {}
    try {
      await _writeProfileReady(user, displayName: name, occupation: job);
    } catch (_) {}
    try {
      await _bindUser(user);
    } catch (_) {
      _session = CloudSession(
        uid: user.uid,
        email: user.email ?? '',
        displayName: name.isEmpty ? (user.displayName ?? '') : name,
        occupation: job,
        emailVerified: user.emailVerified,
        usesFirebase: true,
      );
    }
    try {
      await _sendVerificationEmail(user);
    } catch (_) {}
    try {
      await ensureFriendCode();
    } catch (_) {}
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
  }

  Future<CloudSession> _recoverExistingAuthUser({
    required String email,
    required String password,
    required String displayName,
    required String occupation,
  }) async {
    final current = _auth.currentUser;
    if (current != null && _sameEmail(current.email, email)) {
      return _completeSignUp(current, displayName: displayName, occupation: occupation);
    }
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = cred.user;
      if (user == null) throw CloudException('このメールアドレスはすでに登録されています');
      return _completeSignUp(user, displayName: displayName, occupation: occupation);
    } on FirebaseAuthException {
      throw CloudException('このメールアドレスはすでに登録されています');
    }
  }

  bool _sameEmail(String? left, String right) =>
      (left ?? '').trim().toLowerCase() == right.trim().toLowerCase();

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
    final trimmed = email.trim();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: trimmed,
        password: password,
      );
      final user = cred.user;
      if (user == null) throw CloudException('登録できませんでした');
      return _completeSignUp(user, displayName: displayName, occupation: occupation);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        return _recoverExistingAuthUser(
          email: trimmed,
          password: password,
          displayName: displayName,
          occupation: occupation,
        );
      }
      throw CloudException(cloudErrorMessage(error));
    } catch (error) {
      if (error is CloudException) rethrow;
      final current = _auth.currentUser;
      if (current != null && _sameEmail(current.email, trimmed)) {
        try {
          return _completeSignUp(current, displayName: displayName, occupation: occupation);
        } catch (_) {}
      }
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
      await _bindUser(user);
      try {
        await ensureFriendCode();
      } catch (_) {}
      return _session!;
    } catch (error) {
      throw CloudException(cloudErrorMessage(error));
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
    Map<String, dynamic> data = {};
    try {
      final snap = await _user(user.uid).get();
      data = snap.data() ?? {};
    } catch (error) {
      if (!_denied(error)) rethrow;
    }
    return CloudSession(
      uid: user.uid,
      email: user.email ?? '',
      displayName: (data['displayName'] as String?) ?? user.displayName ?? '',
      occupation: data['occupation'] as String? ?? '',
      emailVerified: user.emailVerified,
      usesFirebase: true,
    );
  }

  Future<void> _writeProfile(
    User user, {
    required String displayName,
    required String occupation,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{
      'email': user.email,
      'displayName': displayName,
      'occupation': occupation,
      'updatedAt': FieldValue.serverTimestamp(),
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
    await _user(user.uid).set(data, SetOptions(merge: true));
    await _db.collection('profiles').doc(user.uid).set(
      {
        'uid': user.uid,
        'displayName': displayName,
        'occupation': occupation,
        'updatedAt': FieldValue.serverTimestamp(),
        if (photoUrl != null) 'photoUrl': photoUrl,
      },
      SetOptions(merge: true),
    );
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
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw CloudException('ログインしてください');
    if (displayName.trim().isEmpty) throw CloudException('名前を入力してください');
    await user.updateDisplayName(displayName.trim());
    await _writeProfile(
      user,
      displayName: displayName.trim(),
      occupation: occupation.trim(),
      photoUrl: photoUrl,
    );
    _session = (await _sessionFrom(user)).copyWith(
      displayName: displayName.trim(),
      occupation: occupation.trim(),
    );
    return _session!;
  }

  @override
  Future<String> uploadMedia(List<int> bytes, {String mime = 'image/jpeg', bool avatar = false}) async {
    final me = _uid();
    if (bytes.isEmpty) throw CloudException('写真を選べませんでした');
    final packed = await compressForFirestoreAsync(bytes, avatar: avatar, mime: mime);
    try {
      final ref = _db.collection('media').doc();
      await ref.set({
        'owner_id': me,
        'mime': packed.mime,
        'data_b64': base64Encode(packed.bytes),
        'created_at': DateTime.now().toIso8601String(),
      });
      return 'nexus-media:${ref.id}';
    } catch (error) {
      throw CloudException(cloudErrorMessage(error));
    }
  }

  @override
  Future<String> readMedia(String src) async {
    if (src.startsWith('data:') || src.startsWith('http://') || src.startsWith('https://')) {
      return src;
    }
    const prefix = 'nexus-media:';
    if (!src.startsWith(prefix)) return src;
    final snap = await _safeGet(_db.collection('media').doc(src.substring(prefix.length)));
    final data = snap?.data();
    if (data == null) return src;
    final b64 = data['data_b64'] as String? ?? '';
    final mime = data['mime'] as String? ?? 'image/jpeg';
    if (b64.isEmpty) return src;
    return 'data:$mime;base64,$b64';
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
    try {
      final snap = await _user(uid).collection('live').doc('current').get();
      return snap.data();
    } catch (error) {
      if (_denied(error)) return null;
      rethrow;
    }
  }

  @override
  Future<void> pushLive(String uid, Map<String, dynamic> bundle) async {
    try {
      await _user(uid).collection('live').doc('current').set(bundle);
    } catch (error) {
      if (_denied(error)) return;
      rethrow;
    }
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
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _user(uid).collection('vault').orderBy('at', descending: true).get();
    } catch (error) {
      if (_querySkipped(error)) return const [];
      rethrow;
    }
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
    final snap = await _safeGet(_user(uid).collection('vault').doc(id));
    final data = snap?.data();
    if (data == null) return null;
    final payload = data['data'];
    return VaultRecord(
      id: snap?.id ?? id,
      at: DateTime.tryParse(data['at'] as String? ?? '') ?? DateTime.now(),
      reason: data['reason'] as String? ?? '',
      bytes: data['bytes'] as int? ?? 0,
      data: payload is Map ? Map<String, dynamic>.from(payload) : null,
    );
  }

  @override
  Future<List<MailItem>> listMail(String uid) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _user(uid).collection('mail').orderBy('at', descending: true).get();
    } catch (error) {
      if (_querySkipped(error)) return const [];
      rethrow;
    }
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
    try {
      await _user(uid).collection('mail').doc(id).set({'read': true}, SetOptions(merge: true));
    } catch (error) {
      if (!_denied(error)) rethrow;
    }
  }

  String _uid() {
    final uid = _auth.currentUser?.uid ?? _session?.uid;
    if (uid == null || uid.isEmpty) throw CloudException('ログインしてください');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _profile(String uid) => _db.collection('profiles').doc(uid);

  Future<FriendProfile> _readProfile(String uid) async {
    try {
      final snap = await _profile(uid).get();
      final data = snap.data() ?? {};
      return FriendProfile(
        uid: uid,
        displayName: data['displayName'] as String? ?? 'ユーザー',
        friendCode: data['friendCode'] as String? ?? '',
        occupation: data['occupation'] as String? ?? '',
        photoUrl: data['photoUrl'] as String? ?? data['photo_url'] as String? ?? '',
      );
    } catch (error) {
      if (_denied(error)) {
        return FriendProfile(uid: uid, displayName: 'ユーザー', friendCode: '', occupation: '');
      }
      rethrow;
    }
  }

  bool _denied(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') return true;
    final text = error.toString();
    return text.contains('permission-denied') || text.contains('PERMISSION_DENIED');
  }

  bool _querySkipped(Object error) {
    if (_denied(error)) return true;
    if (error is FirebaseException &&
        (error.code == 'failed-precondition' || error.code == 'unimplemented')) {
      return true;
    }
    final text = error.toString();
    return text.contains('FAILED_PRECONDITION') || text.contains('requires an index');
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _safeGet(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return await ref.get();
    } catch (error) {
      if (_denied(error)) return null;
      rethrow;
    }
  }

  Future<void> _safeDelete(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      await ref.delete();
    } catch (error) {
      if (!_denied(error)) rethrow;
    }
  }

  Future<bool> _blockedPair(String a, String b) async {
    try {
      final one = await _db.collection('blocks').doc('${a}_$b').get();
      if (one.exists) return true;
      final two = await _db.collection('blocks').doc('${b}_$a').get();
      return two.exists;
    } catch (error) {
      if (_denied(error)) return false;
      rethrow;
    }
  }

  Future<bool> _areFriends(String a, String b) async {
    try {
      final snap = await _db.collection('friendships').doc(_pairKey(a, b)).get();
      return snap.exists;
    } catch (error) {
      if (_denied(error)) return false;
      rethrow;
    }
  }

  Future<DateTime?> _friendshipStartedAt(String a, String b) async {
    try {
      final snap = await _db.collection('friendships').doc(_pairKey(a, b)).get();
      return DateTime.tryParse(snap.data()?['created_at'] as String? ?? '');
    } catch (error) {
      if (_denied(error)) return null;
      rethrow;
    }
  }

  String _pairKey(String a, String b) {
    final first = a.compareTo(b) < 0 ? a : b;
    final second = first == a ? b : a;
    return '${first}_$second';
  }

  Future<void> _notify(String userId, String type, String actorId, {String? targetId, String? title, String? body}) async {
    try {
      await _db.collection('notifications').add({
        'user_id': userId,
        'type': type,
        'actor_id': actorId,
        'target_id': targetId,
        'title': title,
        'body': body,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  @override
  Future<FriendProfile> ensureFriendCode({bool regenerate = false}) async {
    final uid = _uid();
    Map<String, dynamic>? data;
    try {
      data = (await _profile(uid).get()).data();
    } catch (error) {
      if (!_denied(error)) rethrow;
    }
    final current = data?['friendCode'] as String? ?? '';
    if (!regenerate && current.isNotEmpty) {
      return _readProfile(uid);
    }
    if (current.isNotEmpty) {
      try {
        await _db.collection('friend_codes').doc(current).delete();
      } catch (_) {}
    }
    String code = generateFriendCode();
    for (var i = 0; i < 8; i++) {
      try {
        final exists = await _db.collection('friend_codes').doc(code).get();
        if (!exists.exists) break;
      } catch (error) {
        if (_denied(error)) break;
        rethrow;
      }
      code = generateFriendCode();
    }
    Future<void> write() async {
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
    }

    try {
      await write();
    } catch (error) {
      if (!_denied(error)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _auth.currentUser?.getIdToken(true);
      await write();
    }
    return _readProfile(uid);
  }

  @override
  Future<FriendProfile?> lookupFriend(String query) async {
    final me = _uid();
    final q = friendCodeFromScan(query) ?? normalizeFriendQuery(query);
    if (q.isEmpty) return null;
    String? uid;
    if (q.length == 8) {
      final code = await _safeGet(_db.collection('friend_codes').doc(q));
      uid = code?.data()?['uid'] as String?;
      if (uid == null || uid.isEmpty) return null;
    } else {
      uid = query.trim();
    }
    if (uid.isEmpty) return null;
    if (uid == me) throw CloudException('自分は追加できません');
    if (await _blockedPair(me, uid)) return null;
    final snap = await _safeGet(_profile(uid));
    if (snap == null || !snap.exists) return null;
    return _readProfile(uid);
  }

  @override
  Future<void> sendFriendRequest(String toUid) async {
    final me = _uid();
    if (me == toUid) throw CloudException('自分は追加できません');
    if (await _blockedPair(me, toUid)) throw CloudException('申請できません');
    if (await _areFriends(me, toUid)) throw CloudException('すでにフレンドです');
    final mine = await _safeQuery(_db.collection('friend_requests').where('sender_id', isEqualTo: me));
    final theirs = await _safeQuery(_db.collection('friend_requests').where('receiver_id', isEqualTo: me));
    for (final doc in [...mine, ...theirs]) {
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

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeQuery(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return (await query.get()).docs;
    } catch (error) {
      if (_querySkipped(error)) return const [];
      rethrow;
    }
  }

  @override
  Future<List<FriendRequestItem>> incomingFriendRequests() async {
    final me = _uid();
    final docs = await _safeQuery(_db.collection('friend_requests').where('receiver_id', isEqualTo: me));
    final items = [
      for (final doc in docs)
        if (doc.data()['status'] == 'pending') _requestFrom(doc),
    ];
    return _fillRequestProfiles(items);
  }

  @override
  Future<List<FriendRequestItem>> outgoingFriendRequests() async {
    final me = _uid();
    final docs = await _safeQuery(_db.collection('friend_requests').where('sender_id', isEqualTo: me));
    final items = [
      for (final doc in docs)
        if (doc.data()['status'] == 'pending') _requestFrom(doc),
    ];
    return _fillRequestProfiles(items);
  }

  @override
  Future<List<FriendProfile>> listFriends() async {
    final me = _uid();
    final a = await _safeQuery(_db.collection('friendships').where('user_a', isEqualTo: me));
    final b = await _safeQuery(_db.collection('friendships').where('user_b', isEqualTo: me));
    final others = <String>{};
    for (final doc in [...a, ...b]) {
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
    await _safeDelete(_db.collection('friendships').doc(_pairKey(me, uid)));
    await _revokeAclsBetween(me, uid);
  }

  Future<void> _revokeAclsBetween(String a, String b) async {
    final mine = await _safeQuery(_db.collection('share_acl').where('owner_id', isEqualTo: a));
    for (final doc in mine) {
      if (doc.data()['viewer_id'] != b) continue;
      await _safeDelete(doc.reference);
    }
    final theirs = await _safeQuery(_db.collection('share_acl').where('viewer_id', isEqualTo: a));
    for (final doc in theirs) {
      if (doc.data()['owner_id'] != b) continue;
      await _safeDelete(doc.reference);
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
    await _safeDelete(_db.collection('friendships').doc(_pairKey(me, uid)));
    await _revokeAclsBetween(me, uid);
  }

  @override
  Future<List<FriendProfile>> listBlocked() async {
    final me = _uid();
    final docs = await _safeQuery(_db.collection('blocks').where('blocker_id', isEqualTo: me));
    return [
      for (final doc in docs) await _readProfile(doc.data()['blocked_id'] as String? ?? ''),
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
    final existing = await _safeQuery(_db.collection('shared_items').where('owner_id', isEqualTo: me));
    DocumentReference<Map<String, dynamic>> ref;
    final match = existing.where(
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
      final oldAcl = await _safeQuery(_db.collection('share_acl').where('owner_id', isEqualTo: me));
      for (final doc in oldAcl) {
        if (doc.data()['item_id'] != ref.id) continue;
        await _safeDelete(doc.reference);
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
        'owner_id': me,
        'status': shareStatusForNew(type),
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
    final snap = await _safeQuery(_db.collection('shared_items').where('owner_id', isEqualTo: me));
    final acls = await _safeQuery(_db.collection('share_acl').where('owner_id', isEqualTo: me));
    for (final doc in snap) {
      if (doc.data()['type'] != type.name || doc.data()['source_local_id'] != sourceLocalId) continue;
      try {
        await doc.reference.update({'deleted_at': DateTime.now().toIso8601String()});
      } catch (error) {
        if (!_denied(error)) rethrow;
        continue;
      }
      for (final acl in acls) {
        if (acl.data()['item_id'] != doc.id) continue;
        await _safeDelete(acl.reference);
      }
    }
  }

  @override
  Future<SharedItem?> findMyShare(SharedKind type, String sourceLocalId) async {
    final me = _uid();
    final snap = await _safeQuery(_db.collection('shared_items').where('owner_id', isEqualTo: me));
    final acls = await _safeQuery(_db.collection('share_acl').where('owner_id', isEqualTo: me));
    for (final doc in snap) {
      final data = doc.data();
      if (data['type'] != type.name || data['source_local_id'] != sourceLocalId || data['deleted_at'] != null) {
        continue;
      }
      return SharedItem(
        id: doc.id,
        ownerId: me,
        type: type,
        sourceLocalId: sourceLocalId,
        payload: Map<String, dynamic>.from(data['payload'] as Map? ?? {}),
        updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ?? DateTime.now(),
        owner: await _readProfile(me),
        viewerIds: [
          for (final acl in acls)
            if (acl.data()['item_id'] == doc.id) acl.data()['viewer_id'] as String? ?? '',
        ],
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
    final me = _uid();
    final acls = await _safeQuery(_db.collection('share_acl').where('viewer_id', isEqualTo: me));
    final items = <SharedItem>[];
    for (final acl in acls) {
      final status = shareStatusFrom(acl.data()['status'] as String?);
      if (pendingOnly) {
        if (status != ShareStatus.pending) continue;
      } else if (status != ShareStatus.accepted) {
        continue;
      }
      final itemId = acl.data()['item_id'] as String? ?? '';
      final snap = await _safeGet(_db.collection('shared_items').doc(itemId));
      final data = snap?.data();
      if (data == null) continue;
      final kind = sharedKindFrom(data['type'] as String? ?? 'diary');
      if (type != null && kind != type) continue;
      final ownerId = data['owner_id'] as String? ?? '';
      final updatedAt = DateTime.tryParse(data['updated_at'] as String? ?? '') ?? DateTime.now();
      if (kind == SharedKind.diary &&
          !SharedItem(
            id: snap?.id ?? itemId,
            ownerId: ownerId,
            type: kind,
            sourceLocalId: data['source_local_id'] as String? ?? '',
            payload: const {},
            updatedAt: updatedAt,
          ).diaryShareVisible()) {
        continue;
      }
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
          id: snap?.id ?? itemId,
          ownerId: ownerId,
          type: kind,
          sourceLocalId: data['source_local_id'] as String? ?? '',
          payload: Map<String, dynamic>.from(data['payload'] as Map? ?? {}),
          updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ?? DateTime.now(),
          owner: await _readProfile(ownerId),
          aclId: acl.id,
          shareStatus: status,
        ),
      );
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items.take(limit).toList();
  }

  @override
  Future<void> respondShare(String aclId, {required bool accept}) async {
    final me = _uid();
    final ref = _db.collection('share_acl').doc(aclId);
    final snap = await _safeGet(ref);
    final data = snap?.data();
    if (data == null || data['viewer_id'] != me) throw CloudException('共有が見つかりません');
    if (accept) {
      await ref.set({'status': 'accepted'}, SetOptions(merge: true));
    } else {
      await _safeDelete(ref);
    }
  }

  @override
  Future<void> reactToShare(String itemId, String emoji) async {
    final me = _uid();
    await _db.collection('shared_items').doc(itemId).collection('reactions').doc(me).set({
      'item_id': itemId,
      'uid': me,
      'emoji': emoji,
    });
  }

  @override
  Future<List<ShareReaction>> listReactions(String itemId) async {
    try {
      final snap = await _db.collection('shared_items').doc(itemId).collection('reactions').get();
      return [
        for (final doc in snap.docs)
          ShareReaction(
            itemId: itemId,
            uid: doc.data()['uid'] as String? ?? doc.id,
            emoji: doc.data()['emoji'] as String? ?? '',
          ),
      ];
    } catch (error) {
      if (_denied(error)) return const [];
      rethrow;
    }
  }

  @override
  Future<void> replyToShare(String itemId, String body) async {
    final text = body.trim();
    if (text.isEmpty) throw CloudException('ひとことを入力してください');
    final me = _uid();
    await _db.collection('shared_items').doc(itemId).collection('replies').add({
      'item_id': itemId,
      'author_id': me,
      'body': text,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<ShareReply>> listReplies(String itemId) async {
    try {
      final snap = await _db.collection('shared_items').doc(itemId).collection('replies').get();
      final items = [
        for (final doc in snap.docs)
          ShareReply(
            id: doc.id,
            itemId: itemId,
            authorId: doc.data()['author_id'] as String? ?? '',
            body: doc.data()['body'] as String? ?? '',
            createdAt: DateTime.tryParse(doc.data()['created_at'] as String? ?? '') ?? DateTime.now(),
            author: await _readProfile(doc.data()['author_id'] as String? ?? ''),
          ),
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    } catch (error) {
      if (_denied(error)) return const [];
      rethrow;
    }
  }

  FriendCircle _circleFrom(String id, Map<String, dynamic> data) {
    return FriendCircle(
      id: id,
      name: data['name'] as String? ?? '',
      ownerId: data['owner_id'] as String? ?? '',
      memberIds: [
        for (final id in (data['member_ids'] as List? ?? const []))
          if (id is String && id.isNotEmpty) id,
      ],
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<FriendCircle> createCircle({required String name, required List<String> memberIds}) async {
    final me = _uid();
    final text = name.trim();
    if (text.isEmpty) throw CloudException('グループ名を入力してください');
    final members = <String>{me, ...memberIds.where((id) => id != me)};
    final ref = _db.collection('circles').doc();
    await ref.set({
      'name': text,
      'owner_id': me,
      'member_ids': members.toList(),
      'created_at': DateTime.now().toIso8601String(),
    });
    return _circleFrom(ref.id, (await ref.get()).data() ?? {'name': text, 'owner_id': me, 'member_ids': members.toList()});
  }

  @override
  Future<void> updateCircle(FriendCircle circle) async {
    final me = _uid();
    final members = <String>{me, ...circle.memberIds};
    await _db.collection('circles').doc(circle.id).set({
      'name': circle.name.trim(),
      'owner_id': me,
      'member_ids': members.toList(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteCircle(String id) async {
    await _db.collection('circles').doc(id).delete();
  }

  @override
  Future<List<FriendCircle>> listCircles() async {
    final me = _uid();
    final owned = await _safeQuery(_db.collection('circles').where('owner_id', isEqualTo: me));
    final member = await _safeQuery(_db.collection('circles').where('member_ids', arrayContains: me));
    final map = <String, FriendCircle>{};
    for (final doc in [...owned, ...member]) {
      map[doc.id] = _circleFrom(doc.id, doc.data());
    }
    return map.values.toList();
  }

  @override
  Future<CirclePoll> createPoll({
    required String circleId,
    required String title,
    required List<String> options,
    DateTime? deadline,
  }) async {
    final cleaned = [for (final o in options) if (o.trim().isNotEmpty) o.trim()];
    if (title.trim().isEmpty || cleaned.length < 2) throw CloudException('日程の候補を2つ以上入れてください');
    final due = deadline == null ? null : DateTime(deadline.year, deadline.month, deadline.day);
    final ref = _db.collection('circles').doc(circleId).collection('polls').doc();
    await ref.set({
      'circle_id': circleId,
      'title': title.trim(),
      'options': cleaned,
      'votes': <String, dynamic>{},
      'created_at': DateTime.now().toIso8601String(),
      'deadline': due?.toIso8601String(),
    });
    return CirclePoll(
      id: ref.id,
      circleId: circleId,
      title: title.trim(),
      options: cleaned,
      votes: const {},
      createdAt: DateTime.now(),
      deadline: due,
    );
  }

  CirclePoll _pollFrom(String circleId, String id, Map<String, dynamic> data) {
    return CirclePoll(
      id: id,
      circleId: circleId,
      title: data['title'] as String? ?? '',
      options: [
        for (final o in (data['options'] as List? ?? const []))
          if (o is String) o,
      ],
      votes: {
        for (final e in (data['votes'] as Map? ?? {}).entries)
          e.key.toString(): (e.value as num?)?.toInt() ?? 0,
      },
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
      deadline: DateTime.tryParse(data['deadline'] as String? ?? data['deadline_at'] as String? ?? ''),
    );
  }

  @override
  Future<void> votePoll(String pollId, int optionIndex) async {
    final me = _uid();
    final circles = await listCircles();
    for (final circle in circles) {
      final snap = await _safeGet(_db.collection('circles').doc(circle.id).collection('polls').doc(pollId));
      if (snap == null || !snap.exists) continue;
      final poll = _pollFrom(circle.id, snap.id, snap.data() ?? {});
      if (poll.stage() != PollStage.voting) throw CloudException('投票期間が終了しています');
      final votes = Map<String, dynamic>.from(snap.data()?['votes'] as Map? ?? {});
      votes[me] = optionIndex;
      await snap.reference.set({'votes': votes}, SetOptions(merge: true));
      return;
    }
    throw CloudException('投票が見つかりません');
  }

  @override
  Future<List<CirclePoll>> listPolls(String circleId) async {
    try {
      final snap = await _db.collection('circles').doc(circleId).collection('polls').get();
      final list = [
        for (final doc in snap.docs) _pollFrom(circleId, doc.id, doc.data()),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (error) {
      if (_denied(error)) return const [];
      rethrow;
    }
  }

  @override
  Future<CircleWant> addWant({required String circleId, required String title}) async {
    final me = _uid();
    final text = title.trim();
    if (text.isEmpty) throw CloudException('やりたいことを入力してください');
    final ref = _db.collection('circles').doc(circleId).collection('wants').doc();
    await ref.set({
      'circle_id': circleId,
      'title': text,
      'done': false,
      'creator_id': me,
    });
    return CircleWant(
      id: ref.id,
      circleId: circleId,
      title: text,
      done: false,
      creatorId: me,
    );
  }

  Map<String, bool> _wantAnswers(Map<String, dynamic>? data) {
    final answers = <String, bool>{};
    final raw = data?['answers'];
    if (raw is Map) {
      for (final e in raw.entries) {
        answers[e.key.toString()] = e.value == true;
      }
    }
    return answers;
  }

  @override
  Future<void> toggleWant(String wantId) async {
    final circles = await listCircles();
    for (final circle in circles) {
      final snap = await _safeGet(_db.collection('circles').doc(circle.id).collection('wants').doc(wantId));
      if (snap == null || !snap.exists) continue;
      await snap.reference.set({'done': !(snap.data()?['done'] as bool? ?? false)}, SetOptions(merge: true));
      return;
    }
  }

  @override
  Future<void> answerWant(String wantId, {required bool yes}) async {
    final me = _uid();
    final circles = await listCircles();
    for (final circle in circles) {
      final snap = await _safeGet(_db.collection('circles').doc(circle.id).collection('wants').doc(wantId));
      if (snap == null || !snap.exists) continue;
      final answers = Map<String, dynamic>.from(snap.data()?['answers'] as Map? ?? {});
      if (answers[me] == yes) {
        answers.remove(me);
      } else {
        answers[me] = yes;
      }
      await snap.reference.set({'answers': answers}, SetOptions(merge: true));
      return;
    }
  }

  @override
  Future<List<CircleWant>> listWants(String circleId) async {
    try {
      final snap = await _db.collection('circles').doc(circleId).collection('wants').get();
      return [
        for (final doc in snap.docs)
          CircleWant(
            id: doc.id,
            circleId: circleId,
            title: doc.data()['title'] as String? ?? '',
            done: doc.data()['done'] as bool? ?? false,
            creatorId: doc.data()['creator_id'] as String? ?? '',
            answers: _wantAnswers(doc.data()),
          ),
      ];
    } catch (error) {
      if (_denied(error)) return const [];
      rethrow;
    }
  }

  @override
  Future<MemoryAlbum> createAlbum({
    required String title,
    required List<String> participantIds,
    String? circleId,
  }) async {
    final me = _uid();
    final text = title.trim();
    if (text.isEmpty) throw CloudException('アルバム名を入力してください');
    final people = <String>{me, ...participantIds};
    final ref = _db.collection('memory_albums').doc();
    await ref.set({
      'title': text,
      'owner_id': me,
      'participant_ids': people.toList(),
      'circle_id': circleId,
      'created_at': DateTime.now().toIso8601String(),
    });
    return MemoryAlbum(
      id: ref.id,
      title: text,
      ownerId: me,
      participantIds: people.toList(),
      circleId: circleId,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<MemoryAlbum>> listAlbums() async {
    final me = _uid();
    final owned = await _safeQuery(_db.collection('memory_albums').where('owner_id', isEqualTo: me));
    final member = await _safeQuery(_db.collection('memory_albums').where('participant_ids', arrayContains: me));
    final map = <String, MemoryAlbum>{};
    for (final doc in [...owned, ...member]) {
      map[doc.id] = MemoryAlbum(
        id: doc.id,
        title: doc.data()['title'] as String? ?? '',
        ownerId: doc.data()['owner_id'] as String? ?? '',
        participantIds: [
          for (final id in (doc.data()['participant_ids'] as List? ?? const []))
            if (id is String && id.isNotEmpty) id,
        ],
        circleId: doc.data()['circle_id'] as String?,
        createdAt: DateTime.tryParse(doc.data()['created_at'] as String? ?? '') ?? DateTime.now(),
      );
    }
    return map.values.toList();
  }

  @override
  Future<void> updateAlbum(MemoryAlbum album) async {
    final me = _uid();
    final ref = _db.collection('memory_albums').doc(album.id);
    final snap = await ref.get();
    if (!snap.exists || snap.data()?['owner_id'] != me) {
      throw CloudException('アルバムを変えられません');
    }
    final people = <String>{me, ...album.participantIds};
    await ref.set(
      {
        'title': album.title.trim(),
        'participant_ids': people.toList(),
        'circle_id': album.circleId,
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> addMemoryPhoto({
    required String albumId,
    required DateTime day,
    String dataB64 = '',
    String url = '',
    String mime = 'image/jpeg',
  }) async {
    final me = _uid();
    var storedUrl = url.trim();
    if (storedUrl.isEmpty && dataB64.isNotEmpty) {
      storedUrl = await uploadMedia(base64Decode(dataB64), mime: mime);
    }
    if (storedUrl.isEmpty) throw CloudException('写真を選べませんでした');
    await _db.collection('memory_albums').doc(albumId).collection('photos').add({
      'album_id': albumId,
      'day': DateTime(day.year, day.month, day.day).toIso8601String(),
      'author_id': me,
      'url': storedUrl,
      'mime': mime,
    });
  }

  @override
  Future<List<MemoryPhoto>> listMemoryPhotos(String albumId) async {
    try {
      final snap = await _db.collection('memory_albums').doc(albumId).collection('photos').get();
      final list = [
        for (final doc in snap.docs)
          MemoryPhoto(
            id: doc.id,
            albumId: albumId,
            day: DateTime.tryParse(doc.data()['day'] as String? ?? '') ?? DateTime.now(),
            authorId: doc.data()['author_id'] as String? ?? '',
            dataB64: doc.data()['data_b64'] as String? ?? '',
            url: doc.data()['url'] as String? ?? '',
            mime: doc.data()['mime'] as String? ?? 'image/jpeg',
          ),
      ]..sort((a, b) => b.day.compareTo(a.day));
      return list;
    } catch (error) {
      if (_denied(error)) return const [];
      rethrow;
    }
  }

  @override
  Future<void> addPhotoComment({
    required String albumId,
    required String photoId,
    required String body,
  }) async {
    final text = body.trim();
    if (text.isEmpty) throw CloudException('コメントを入力してください');
    final me = _uid();
    await _db
        .collection('memory_albums')
        .doc(albumId)
        .collection('photos')
        .doc(photoId)
        .collection('comments')
        .add({
      'author_id': me,
      'body': text,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<PhotoComment>> listPhotoComments({
    required String albumId,
    required String photoId,
  }) async {
    try {
      final snap = await _db
          .collection('memory_albums')
          .doc(albumId)
          .collection('photos')
          .doc(photoId)
          .collection('comments')
          .get();
      final items = [
        for (final doc in snap.docs)
          PhotoComment(
            id: doc.id,
            photoId: photoId,
            authorId: doc.data()['author_id'] as String? ?? '',
            body: doc.data()['body'] as String? ?? '',
            createdAt: DateTime.tryParse(doc.data()['created_at'] as String? ?? '') ?? DateTime.now(),
            author: await _readProfile(doc.data()['author_id'] as String? ?? ''),
          ),
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    } catch (error) {
      if (_denied(error)) return const [];
      rethrow;
    }
  }

  @override
  Future<String> ensureDmChat(String otherUid) async {
    final me = _uid();
    if (otherUid.isEmpty || otherUid == me) throw CloudException('トーク相手が不明です');
    final id = 'dm_${_pairKey(me, otherUid)}';
    await _db.collection('chats').doc(id).set(
      {
        'type': 'dm',
        'member_ids': [me, otherUid],
        'updated_at': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
    return id;
  }

  @override
  Future<String> ensureCircleChat(FriendCircle circle) async {
    final me = _uid();
    if (circle.ownerId != me && !circle.memberIds.contains(me)) {
      throw CloudException('グループのメンバーではありません');
    }
    final id = 'circle_${circle.id}';
    final members = <String>{me, circle.ownerId, ...circle.memberIds};
    await _db.collection('chats').doc(id).set(
      {
        'type': 'circle',
        'circle_id': circle.id,
        'member_ids': members.toList(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
    return id;
  }

  @override
  Future<List<TalkMessage>> listMessages(String chatId) async {
    try {
      final snap = await _db.collection('chats').doc(chatId).collection('messages').get();
      final items = [
        for (final doc in snap.docs)
          TalkMessage(
            id: doc.id,
            chatId: chatId,
            authorId: doc.data()['author_id'] as String? ?? '',
            body: doc.data()['body'] as String? ?? '',
            imageUrl: doc.data()['image_url'] as String? ?? '',
            createdAt: DateTime.tryParse(doc.data()['created_at'] as String? ?? '') ?? DateTime.now(),
            author: await _readProfile(doc.data()['author_id'] as String? ?? ''),
          ),
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    } catch (error) {
      if (_denied(error)) return const [];
      rethrow;
    }
  }

  @override
  Future<void> sendMessage(String chatId, {String body = '', String imageUrl = ''}) async {
    final text = body.trim();
    if (text.isEmpty && imageUrl.isEmpty) throw CloudException('メッセージを入力してください');
    final me = _uid();
    final chat = await _db.collection('chats').doc(chatId).get();
    final members = [
      for (final id in (chat.data()?['member_ids'] as List? ?? const []))
        if (id is String) id,
    ];
    if (!chat.exists || !members.contains(me)) throw CloudException('トークのメンバーではありません');
    await chat.reference.collection('messages').add({
      'author_id': me,
      'body': text,
      'image_url': imageUrl,
      'created_at': DateTime.now().toIso8601String(),
    });
    await chat.reference.set(
      {
        'updated_at': DateTime.now().toIso8601String(),
        'last_text': text.isEmpty ? '写真' : text,
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> markFriendNoticeRead(String id) async {
    try {
      await _db.collection('notifications').doc(id).set(
        {'read_at': DateTime.now().toIso8601String()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}
