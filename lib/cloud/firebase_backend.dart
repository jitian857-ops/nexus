import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cloud_backend.dart';
import 'cloud_models.dart';
import 'password.dart';

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

  Future<void> _writeProfile(User user, {required String displayName, required String occupation}) {
    return _user(user.uid).set(
      {
        'email': user.email,
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
}
