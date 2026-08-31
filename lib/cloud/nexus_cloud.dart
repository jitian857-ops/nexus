import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../app/motion.dart';
import '../config/firebase_options.dart';
import 'cloud_backend.dart';
import 'cloud_models.dart';
import 'firebase_backend.dart';
import 'local_backend.dart';

class NexusCloud extends ChangeNotifier {
  NexusCloud();

  CloudBackend _backend = LocalBackend();
  var ready = false;
  var busy = false;
  String lastError = '';
  String lastNotice = '';
  String? localIssuedCode;

  CloudBackend get backend => _backend;

  CloudSession? get session => _backend.currentSession;

  bool get isSignedIn => session != null;

  bool get emailVerified => session?.emailVerified ?? false;

  bool get usesFirebase => _backend.usesFirebase;

  String get uid => session?.uid ?? '';

  int unreadMail = 0;

  Future<void> boot() async {
    if (DefaultFirebaseOptions.isConfigured && !NexusMotion.inWidgetTest) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        }
        _backend = FirebaseBackend();
      } catch (error) {
        debugPrint('Firebase を起動できません: $error');
        _backend = LocalBackend();
      }
    } else {
      _backend = LocalBackend();
    }
    await _backend.init();
    if (NexusMotion.inWidgetTest) {
      await enterTestSession();
    }
    await _refreshMailBadge();
    ready = true;
    notifyListeners();
  }

  Future<void> enterTestSession() async {
    final local = LocalBackend();
    await local.init();
    local.enterMemorySession(
      const CloudSession(
        uid: 'test',
        email: 'test@nexus.local',
        displayName: '蒼井 ユウ',
        occupation: '',
        emailVerified: true,
        usesFirebase: false,
      ),
    );
    _backend = local;
  }

  Future<T> _run<T>(Future<T> Function() task) async {
    busy = true;
    lastError = '';
    notifyListeners();
    try {
      final result = await task();
      await _refreshMailBadge();
      notifyListeners();
      return result;
    } catch (error) {
      lastError = cloudErrorMessage(error);
      notifyListeners();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String occupation,
  }) {
    return _run(() async {
      await _backend.signUp(
        email: email,
        password: password,
        displayName: displayName,
        occupation: occupation,
      );
      if (!_backend.usesFirebase) {
        await _backend.sendVerification();
        if (_backend is LocalBackend) {
          localIssuedCode = (_backend as LocalBackend).lastIssuedCode;
        }
      }
      lastNotice = '認証メールを送りました';
    });
  }

  Future<void> signIn({required String email, required String password}) {
    return _run(() => _backend.signIn(email: email, password: password));
  }

  Future<void> signOut() {
    return _run(() async {
      await _backend.signOut();
      unreadMail = 0;
    });
  }

  Future<void> sendVerification() {
    return _run(() async {
      await _backend.sendVerification();
      lastNotice = '認証メールを送りました';
    });
  }

  Future<void> confirmVerification({String? code}) {
    return _run(() => _backend.confirmVerification(code: code));
  }

  Future<String?> sendPasswordReset(String email) {
    return _run(() async {
      await _backend.sendPasswordReset(email);
      lastNotice = usesFirebase ? '再設定用のメールを送りました' : '再設定コードを発行しました';
      if (_backend is LocalBackend) {
        localIssuedCode = (_backend as LocalBackend).lastIssuedCode;
      }
      return localIssuedCode;
    });
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _run(
      () => _backend.confirmPasswordReset(email: email, code: code, newPassword: newPassword),
    );
  }

  Future<void> updateProfile({required String displayName, required String occupation}) {
    return _run(
      () => _backend.updateProfile(displayName: displayName, occupation: occupation),
    );
  }

  Future<void> deleteAccount({required String password}) {
    return _run(() => _backend.deleteAccount(password: password));
  }

  Future<Map<String, dynamic>?> pullLive() async {
    final id = uid;
    if (id.isEmpty) return null;
    return _backend.pullLive(id);
  }

  Future<void> pushLive(Map<String, dynamic> bundle) async {
    final id = uid;
    if (id.isEmpty) return;
    await _backend.pushLive(id, bundle);
  }

  Future<void> sealVault(String reason, Map<String, dynamic> bundle) async {
    final id = uid;
    if (id.isEmpty) return;
    await _backend.sealVault(id, reason, bundle);
    await _backend.addMail(
      id,
      MailItem(
        id: 'v${DateTime.now().microsecondsSinceEpoch}',
        title: 'データを保管しました',
        body: 'アプリからは変更・削除できない保管庫へ、この時点のデータを収めました（$reason）。',
        at: DateTime.now(),
        kind: 'vault',
      ),
    );
    await _refreshMailBadge();
    notifyListeners();
  }

  Future<List<VaultRecord>> listVault() async {
    if (uid.isEmpty) return const [];
    return _backend.listVault(uid);
  }

  Future<VaultRecord?> readVault(String id) async {
    if (uid.isEmpty) return null;
    return _backend.readVault(uid, id);
  }

  Future<List<MailItem>> listMail() async {
    if (uid.isEmpty) return const [];
    return _backend.listMail(uid);
  }

  Future<void> markMailRead(String id) async {
    if (uid.isEmpty) return;
    await _backend.markMailRead(uid, id);
    await _refreshMailBadge();
    notifyListeners();
  }

  Future<void> _refreshMailBadge() async {
    if (uid.isEmpty) {
      unreadMail = 0;
      return;
    }
    final mail = await _backend.listMail(uid);
    unreadMail = mail.where((m) => !m.read).length;
  }
}

class CloudScope extends InheritedNotifier<NexusCloud> {
  const CloudScope({
    super.key,
    required NexusCloud cloud,
    required super.child,
  }) : super(notifier: cloud);

  static NexusCloud of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CloudScope>();
    assert(scope != null, 'CloudScope が見つかりません');
    return scope!.notifier!;
  }
}
