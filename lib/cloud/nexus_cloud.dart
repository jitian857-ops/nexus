import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/motion.dart';
import '../config/firebase_options.dart';
import 'cloud_backend.dart';
import 'cloud_models.dart';
import 'firebase_backend.dart';
import 'friend_models.dart';
import 'local_backend.dart';

class NexusCloud extends ChangeNotifier {
  NexusCloud();

  static const _guestFlag = 'nexus_guest_v1';

  CloudBackend _backend = LocalBackend();
  CloudBackend? _hosted;
  var ready = false;
  var busy = false;
  var firebaseBootFailed = false;
  var _generation = 0;
  String lastError = '';
  String lastNotice = '';
  String? localIssuedCode;

  CloudBackend get backend => _backend;

  CloudSession? get session => _backend.currentSession;

  bool get isSignedIn => session != null;

  bool get emailVerified => session?.emailVerified ?? false;

  bool get usesFirebase => _backend.usesFirebase;

  bool get isGuest => session?.uid == 'guest';

  String get uid => session?.uid ?? '';

  int get generation => _generation;

  SessionIdentity get identity => SessionIdentity.fromSession(session, _generation);

  int unreadMail = 0;

  @visibleForTesting
  Future<void> Function()? debugStallPull;

  @visibleForTesting
  Future<void> Function()? debugStallPush;

  /// Firebase が設定されているときは初期化失敗でもローカル認証へ切り替えない。
  static bool useLocalAccounts({
    required bool firebaseConfigured,
    required bool widgetTest,
  }) {
    if (widgetTest) return true;
    return !firebaseConfigured;
  }

  void _bumpGeneration() {
    _generation++;
  }

  Future<void> boot() async {
    firebaseBootFailed = false;
    final widgetTest = NexusMotion.inWidgetTest;
    final configured = DefaultFirebaseOptions.isConfigured;
    if (!useLocalAccounts(firebaseConfigured: configured, widgetTest: widgetTest)) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        }
        _backend = FirebaseBackend();
        await _backend.init();
        _hosted = _backend;
      } catch (error) {
        debugPrint('Firebase を起動できません: $error');
        firebaseBootFailed = true;
        lastError = '接続の準備ができませんでした';
        _backend = FirebaseBackend();
        _hosted = _backend;
      }
    } else {
      _backend = LocalBackend();
      await _backend.init();
      _hosted = _backend;
    }
    if (widgetTest) {
      await enterTestSession();
    } else if (!firebaseBootFailed && await _guestFlagOn()) {
      await _applyGuest();
    }
    await _refreshMailBadge();
    ready = true;
    notifyListeners();
  }

  Future<void> enterTestSession() async {
    _hosted ??= _backend;
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
    _bumpGeneration();
  }

  Future<bool> _guestFlagOn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_guestFlag) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setGuestFlag(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_guestFlag, value);
    } catch (_) {}
  }

  Future<void> _applyGuest() async {
    _hosted ??= _backend;
    final local = LocalBackend();
    await local.init();
    local.enterMemorySession(
      const CloudSession(
        uid: 'guest',
        email: 'guest@nexus.local',
        displayName: 'ゲスト',
        occupation: '',
        emailVerified: true,
        usesFirebase: false,
      ),
    );
    _backend = local;
    await _setGuestFlag(true);
    _bumpGeneration();
  }

  Future<void> enterGuestSession() {
    return _run(() async {
      await _applyGuest();
      lastNotice = 'ゲストで入りました';
    });
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
      _bumpGeneration();
      lastNotice = '認証メールを送りました';
    });
  }

  Future<void> signIn({required String email, required String password}) {
    return _run(() async {
      await _backend.signIn(email: email, password: password);
      _bumpGeneration();
    });
  }

  Future<void> signOut() {
    return _run(() async {
      await _backend.signOut();
      unreadMail = 0;
      localIssuedCode = null;
      await _setGuestFlag(false);
      final hosted = _hosted;
      if (hosted != null && !identical(_backend, hosted)) {
        _backend = hosted;
        await _backend.init();
      }
      _bumpGeneration();
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
    final started = identity;
    if (!started.isBound) return null;
    final backend = _backend;
    final stall = debugStallPull;
    if (stall != null) await stall();
    if (!identity.sameAs(started)) return null;
    return backend.pullLive(started.uid);
  }

  Future<void> pushLive(Map<String, dynamic> bundle) async {
    final started = identity;
    if (!started.isBound) return;
    final bundleUid = bundle['uid'] as String?;
    if (bundleUid != null && bundleUid.isNotEmpty && bundleUid != started.uid) return;
    final destUid = started.uid;
    final backend = _backend;
    final stall = debugStallPush;
    if (stall != null) await stall();
    try {
      await backend.pushLive(destUid, bundle);
    } catch (_) {}
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

  Future<FriendProfile> ensureFriendCode({bool regenerate = false}) {
    return _run(() => _backend.ensureFriendCode(regenerate: regenerate));
  }

  Future<FriendProfile?> lookupFriend(String query) => _backend.lookupFriend(query);

  Future<void> sendFriendRequest(String toUid) {
    return _run(() => _backend.sendFriendRequest(toUid));
  }

  Future<void> respondFriendRequest(String requestId, {required bool accept}) {
    return _run(() => _backend.respondFriendRequest(requestId, accept: accept));
  }

  Future<void> cancelFriendRequest(String requestId) {
    return _run(() => _backend.cancelFriendRequest(requestId));
  }

  Future<List<FriendRequestItem>> incomingFriendRequests() => _backend.incomingFriendRequests();

  Future<List<FriendRequestItem>> outgoingFriendRequests() => _backend.outgoingFriendRequests();

  Future<List<FriendProfile>> listFriends() => _backend.listFriends();

  Future<void> removeFriend(String uid) => _run(() => _backend.removeFriend(uid));

  Future<void> blockUser(String uid) => _run(() => _backend.blockUser(uid));

  Future<List<FriendProfile>> listBlocked() => _backend.listBlocked();

  Future<void> reportUser({required String targetId, required String reason}) {
    return _run(() => _backend.reportUser(targetId: targetId, reason: reason));
  }

  Future<void> shareItem({
    required SharedKind type,
    required String sourceLocalId,
    required Map<String, dynamic> payload,
    required List<String> viewerIds,
  }) {
    return _run(
      () => _backend.shareItem(
        type: type,
        sourceLocalId: sourceLocalId,
        payload: payload,
        viewerIds: viewerIds,
      ),
    );
  }

  Future<void> revokeShareBySource(SharedKind type, String sourceLocalId) {
    return _run(() => _backend.revokeShareBySource(type, sourceLocalId));
  }

  Future<SharedItem?> findMyShare(SharedKind type, String sourceLocalId) {
    return _backend.findMyShare(type, sourceLocalId);
  }

  Future<List<SharedItem>> listSharedWithMe({SharedKind? type, int limit = 20}) {
    return _backend.listSharedWithMe(type: type, limit: limit);
  }

  Future<void> _refreshMailBadge() async {
    if (uid.isEmpty) {
      unreadMail = 0;
      return;
    }
    try {
      final mail = await _backend.listMail(uid);
      unreadMail = mail.where((m) => !m.read).length;
    } catch (_) {
      unreadMail = 0;
    }
  }
}

class CloudScope extends InheritedNotifier<NexusCloud> {
  const CloudScope({
    super.key,
    required NexusCloud cloud,
    required super.child,
  }) : super(notifier: cloud);

  static NexusCloud? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CloudScope>()?.notifier;
  }

  static NexusCloud of(BuildContext context) {
    final cloud = maybeOf(context);
    assert(cloud != null, 'CloudScope が見つかりません');
    return cloud!;
  }
}
