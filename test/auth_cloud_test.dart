import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus/cloud/cloud_models.dart';
import 'package:nexus/cloud/friend_models.dart';
import 'package:nexus/cloud/local_backend.dart';
import 'package:nexus/cloud/nexus_cloud.dart';
import 'package:nexus/cloud/password.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('メールとパスワードで登録し、認証できる', () async {
    final cloud = LocalBackend();
    await cloud.init();
    await cloud.signUp(
      email: 'yu@example.com',
      password: 'secret123',
      displayName: '蒼井 ユウ',
      occupation: '学生',
    );
    expect(cloud.currentSession?.emailVerified, isFalse);
    await cloud.sendVerification();
    await cloud.confirmVerification();
    expect(cloud.currentSession?.emailVerified, isTrue);
    expect(cloud.currentSession?.occupation, '学生');
  });

  test('パスワード再設定ができる', () async {
    final cloud = LocalBackend();
    await cloud.init();
    await cloud.signUp(
      email: 'yu@example.com',
      password: 'secret123',
      displayName: 'ユウ',
      occupation: '',
    );
    await cloud.signOut();
    await cloud.sendPasswordReset('yu@example.com');
    final code = cloud.lastIssuedCode!;
    await cloud.confirmPasswordReset(
      email: 'yu@example.com',
      code: code,
      newPassword: 'newpass12',
    );
    final session = await cloud.signIn(email: 'yu@example.com', password: 'newpass12');
    expect(session.email, 'yu@example.com');
  });

  test('保管庫は追加できて上書きできない', () async {
    final cloud = LocalBackend();
    await cloud.init();
    final session = await cloud.signUp(
      email: 'yu@example.com',
      password: 'secret123',
      displayName: 'ユウ',
      occupation: '',
    );
    await cloud.sealVault(session.uid, '初回', {'userName': 'ユウ', 'n': 1});
    await cloud.sealVault(session.uid, '手動', {'userName': 'ユウ', 'n': 2});
    final list = await cloud.listVault(session.uid);
    expect(list, hasLength(2));
    final first = await cloud.readVault(
      session.uid,
      list.firstWhere((item) => item.reason == '初回').id,
    );
    final second = await cloud.readVault(
      session.uid,
      list.firstWhere((item) => item.reason == '手動').id,
    );
    expect(first?.data?['n'], 1);
    expect(second?.data?['n'], 2);
  });

  test('別セッションでも live データが戻る', () async {
    SharedPreferences.setMockInitialValues({});
    final a = LocalBackend();
    await a.init();
    final session = await a.signUp(
      email: 'yu@example.com',
      password: 'secret123',
      displayName: 'ユウ',
      occupation: '学生',
    );
    await a.pushLive(session.uid, {'userName': '蒼井 ユウ', 'occupation': '学生'});
    await a.signOut();

    final b = LocalBackend();
    await b.init();
    await b.signIn(email: 'yu@example.com', password: 'secret123');
    final live = await b.pullLive(session.uid);
    expect(live?['userName'], '蒼井 ユウ');
    expect(live?['occupation'], '学生');
  });

  test('アカウント削除で live は消える', () async {
    final cloud = LocalBackend();
    await cloud.init();
    final session = await cloud.signUp(
      email: 'yu@example.com',
      password: 'secret123',
      displayName: 'ユウ',
      occupation: '',
    );
    await cloud.pushLive(session.uid, {'userName': 'ユウ'});
    await cloud.deleteAccount(password: 'secret123');
    expect(cloud.currentSession, isNull);
    final again = LocalBackend();
    await again.init();
    expect(
      () => again.signIn(email: 'yu@example.com', password: 'secret123'),
      throwsA(isA<CloudException>()),
    );
  });

  test('学習データはJSONにして戻せる', () {
    final store = AppStore.seed();
    final math = store.addSubject(name: '数学');
    store.addStudySession(subjectId: math.id, minutes: 30, focus: StudyFocus.four);
    store.setOccupation('学生');
    final map = store.toCloudMap();
    final other = AppStore.seed();
    other.applyCloudMap(map);
    expect(other.occupation, '学生');
    expect(other.sessions, hasLength(1));
    expect(other.subjects.single.name, '数学');
  });

  test('ゲストログインは認証済みで入れ、ログアウトできる', () async {
    final cloud = NexusCloud();
    await cloud.enterGuestSession();
    expect(cloud.isGuest, isTrue);
    expect(cloud.isSignedIn, isTrue);
    expect(cloud.emailVerified, isTrue);
    expect(cloud.session?.displayName, 'ゲスト');
    await cloud.signOut();
    expect(cloud.isSignedIn, isFalse);
    expect(cloud.isGuest, isFalse);
  });

  test('フレンド申請を承認すると双方の一覧に入る', () async {
    SharedPreferences.setMockInitialValues({});
    final cloud = LocalBackend();
    await cloud.init();
    await cloud.signUp(
      email: 'alice@example.com',
      password: 'secret123',
      displayName: 'アリス',
      occupation: '',
    );
    final alice = cloud.currentSession!;
    final code = (await cloud.ensureFriendCode()).friendCode;
    await cloud.signOut();

    await cloud.signUp(
      email: 'bob@example.com',
      password: 'secret123',
      displayName: 'ボブ',
      occupation: '',
    );
    final bob = cloud.currentSession!;
    final hyphenated = '${code.substring(0, 4)}-${code.substring(4)}';
    final found = await cloud.lookupFriend(hyphenated);
    expect(found?.displayName, 'アリス');
    expect((await cloud.lookupFriend(friendQrPayload(code)))?.uid, found?.uid);
    await cloud.sendFriendRequest(found!.uid);
    await cloud.signOut();

    await cloud.signIn(email: 'alice@example.com', password: 'secret123');
    final incoming = await cloud.incomingFriendRequests();
    expect(incoming, hasLength(1));
    await cloud.respondFriendRequest(incoming.single.id, accept: true);
    expect((await cloud.listFriends()).single.uid, bob.uid);

    await cloud.shareItem(
      type: SharedKind.schedule,
      sourceLocalId: 's1',
      payload: {'title': '勉強会', 'start_at': DateTime(2026, 9, 5, 18).toIso8601String()},
      viewerIds: [bob.uid],
    );
    await cloud.signOut();

    await cloud.signIn(email: 'bob@example.com', password: 'secret123');
    expect((await cloud.listFriends()).single.uid, alice.uid);
    final pending = await cloud.listSharedWithMe(type: SharedKind.schedule, pendingOnly: true);
    expect(pending.single.title, '勉強会');
    await cloud.respondShare(pending.single.aclId, accept: true);
    final shared = await cloud.listSharedWithMe(type: SharedKind.schedule);
    expect(shared.single.title, '勉強会');
  });

  test('フレンドコードはハイフンや全角でも同じ8桁に揃える', () {
    expect(normalizeFriendQuery('ab2c-3d4e'), 'AB2C3D4E');
    expect(normalizeFriendQuery('  AB2C 3D4E '), 'AB2C3D4E');
    expect(normalizeFriendQuery('ＡＢ２Ｃ３Ｄ４Ｅ'), 'AB2C3D4E');
    expect(friendCodeFromScan('NEXUS.FRIEND:AB2C-3D4E'), 'AB2C3D4E');
  });

  test('フレンドQRはコードを読み取れる', () {
    expect(friendCodeFromScan('NEXUS.FRIEND:AB2C3D4E'), 'AB2C3D4E');
    expect(friendCodeFromScan('ab2c3d4e'), 'AB2C3D4E');
    expect(friendCodeFromScan('https://example.com/?c=AB2C3D4E'), 'AB2C3D4E');
    expect(friendCodeFromScan('random-text'), isNull);
    expect(friendQrPayload('ab2c3d4e'), 'NEXUS.FRIEND:AB2C3D4E');
  });

  test('パスワードのハッシュは同じ塩で一致する', () {
    const salt = 'abc';
    expect(PasswordHash.matches('secret123', salt, PasswordHash.hash('secret123', salt)), isTrue);
    expect(PasswordHash.matches('other', salt, PasswordHash.hash('secret123', salt)), isFalse);
  });

  test('クラウドエラーは日本語で分かる', () {
    expect(cloudErrorMessage(CloudException('この操作は許可されていません')), 'この操作は許可されていません');
    expect(cloudErrorMessage(Exception('permission-denied')), 'この操作は許可されていません');
    expect(cloudErrorMessage(Exception('[cloud_firestore/permission-denied] PERMISSION_DENIED')), 'この操作は許可されていません');
    expect(cloudErrorMessage(Exception('email-already-in-use')), 'このメールアドレスはすでに登録されています');
    expect(
      cloudErrorMessage(Exception('operation-not-allowed')),
      'この認証方法はまだ有効になっていません。Firebase の Email/Password を確認してください',
    );
    expect(
      cloudErrorMessage(Exception('unauthorized-continue-uri')),
      '認証メールのリンク先が許可されていません。Firebase の Authorized domains を確認してください',
    );
  });
}
