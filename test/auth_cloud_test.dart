import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus/cloud/cloud_models.dart';
import 'package:nexus/cloud/local_backend.dart';
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
    store.addStudySession(subjectId: math.id, minutes: 30, focus: StudyFocus.high);
    store.setOccupation('学生');
    final map = store.toCloudMap();
    final other = AppStore.seed();
    other.applyCloudMap(map);
    expect(other.occupation, '学生');
    expect(other.sessions, hasLength(1));
    expect(other.subjects.single.name, '数学');
  });

  test('パスワードのハッシュは同じ塩で一致する', () {
    const salt = 'abc';
    expect(PasswordHash.matches('secret123', salt, PasswordHash.hash('secret123', salt)), isTrue);
    expect(PasswordHash.matches('other', salt, PasswordHash.hash('secret123', salt)), isFalse);
  });
}
