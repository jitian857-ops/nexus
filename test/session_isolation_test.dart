import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus/cloud/cloud_models.dart';
import 'package:nexus/cloud/nexus_cloud.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/data/models.dart';
import 'package:nexus/data/nexus_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NexusPrefs.debugLoad = null;
    NexusPrefs.debugSave = null;
  });

  tearDown(() {
    NexusPrefs.debugLoad = null;
    NexusPrefs.debugSave = null;
  });

  Future<NexusCloud> signedCloud({
    required String email,
    required String name,
  }) async {
    final cloud = NexusCloud();
    await cloud.signUp(
      email: email,
      password: 'secret123',
      displayName: name,
      occupation: '',
    );
    await cloud.confirmVerification();
    return cloud;
  }

  Map<String, dynamic> ownedBundle(String uid) {
    return {
      'uid': uid,
      'updatedAt': 1,
      'userName': 'ユーザーA',
      'sessions': [
        {
          'id': 's-a',
          'subjectId': 'sub-a',
          'minutes': 30,
          'focus': 'high',
          'at': DateTime(2026, 9, 1, 10).toIso8601String(),
        },
      ],
      'friendGroups': [
        {'id': 'g-a', 'name': 'A組', 'memberIds': <String>[]},
      ],
      'sleepStartedAt': DateTime(2026, 9, 1, 23).toIso8601String(),
    };
  }

  test('遅延したAの読込はBへ適用されない', () async {
    final cloud = await signedCloud(email: 'a@example.com', name: 'A');
    final uidA = cloud.uid;
    final holdA = Completer<PrefsLoadResult>();
    NexusPrefs.debugLoad = (uid) {
      if (uid == uidA) return holdA.future;
      return Future.value(const PrefsLoadResult.missing());
    };

    final store = AppStore.seed();
    final attachA = store.attachCloud(cloud);

    await cloud.signOut();
    store.detachCloud();
    await cloud.signUp(
      email: 'b@example.com',
      password: 'secret123',
      displayName: 'B',
      occupation: '',
    );
    await cloud.confirmVerification();
    final uidB = cloud.uid;
    await store.attachCloud(cloud);

    holdA.complete(PrefsLoadResult.found(ownedBundle(uidA)));
    await attachA;

    expect(store.dataUid, uidB);
    expect(store.sessions, isEmpty);
    expect(store.friendGroups, isEmpty);
    expect(store.sleepStartedAt, isNull);
    expect(store.userName, 'B');
  });

  test('Aからゲスト、ゲストからBへ切り替えても混在しない', () async {
    final cloud = await signedCloud(email: 'a2@example.com', name: 'A');
    final uidA = cloud.uid;
    final store = AppStore.seed();
    NexusPrefs.debugLoad = (uid) async {
      if (uid == uidA) return PrefsLoadResult.found(ownedBundle(uidA));
      return const PrefsLoadResult.missing();
    };
    await store.attachCloud(cloud);
    expect(store.friendGroups, isNotEmpty);
    expect(store.sleepStartedAt, isNotNull);

    await cloud.enterGuestSession();
    await store.attachCloud(cloud);
    expect(cloud.isGuest, isTrue);
    expect(store.dataUid, 'guest');
    expect(store.sessions, isEmpty);
    expect(store.friendGroups, isEmpty);
    expect(store.sleepStartedAt, isNull);

    await cloud.signOut();
    store.detachCloud();
    await cloud.signUp(
      email: 'b2@example.com',
      password: 'secret123',
      displayName: 'B',
      occupation: '',
    );
    await cloud.confirmVerification();
    await store.attachCloud(cloud);
    expect(store.dataUid, cloud.uid);
    expect(store.sessions, isEmpty);
    expect(store.friendGroups, isEmpty);
    expect(store.sleepStartedAt, isNull);
    expect(store.userName, 'B');
  });

  test('再ログインでも別ユーザーの記録が残らない', () async {
    final cloud = await signedCloud(email: 'a3@example.com', name: 'A');
    final uidA = cloud.uid;
    final store = AppStore.seed();
    NexusPrefs.debugLoad = (uid) async {
      if (uid == uidA) return PrefsLoadResult.found(ownedBundle(uidA));
      return const PrefsLoadResult.missing();
    };
    await store.attachCloud(cloud);
    await cloud.signOut();
    store.detachCloud();
    await cloud.signIn(email: 'a3@example.com', password: 'secret123');
    await store.attachCloud(cloud);
    expect(store.dataUid, uidA);
    expect(store.sessions.single.id, 's-a');

    await cloud.signOut();
    store.detachCloud();
    await cloud.signUp(
      email: 'b3@example.com',
      password: 'secret123',
      displayName: 'B',
      occupation: '',
    );
    await cloud.confirmVerification();
    await store.attachCloud(cloud);
    expect(store.sessions, isEmpty);
    expect(store.friendGroups, isEmpty);
    expect(store.sleepStartedAt, isNull);
  });

  test('古い保存は新UIDへ送られない', () async {
    final cloud = await signedCloud(email: 'a4@example.com', name: 'A');
    final uidA = cloud.uid;
    final writes = <MapEntry<String, Map<String, dynamic>>>[];
    final holdA = Completer<void>();
    var holding = false;
    NexusPrefs.debugLoad = (_) async => const PrefsLoadResult.missing();
    NexusPrefs.debugSave = (uid, bundle) async {
      if (uid == uidA && !holding) {
        holding = true;
        await holdA.future;
      }
      writes.add(MapEntry(uid, bundle));
    };

    final store = AppStore.seed();
    await store.attachCloud(cloud);
    store.addStudySession(subjectId: 'sub', minutes: 10, focus: StudyFocus.four);

    await cloud.signOut();
    store.detachCloud();
    await cloud.signUp(
      email: 'b4@example.com',
      password: 'secret123',
      displayName: 'B',
      occupation: '',
    );
    await cloud.confirmVerification();
    final uidB = cloud.uid;
    await store.attachCloud(cloud);
    holdA.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(writes.where((item) => item.key == uidB), isNotEmpty);
    for (final item in writes.where((entry) => entry.key == uidB)) {
      final sessions = (item.value['sessions'] as List?) ?? const [];
      expect(sessions.where((row) => row is Map && row['minutes'] == 10), isEmpty);
    }
  });

  test('開始済みの同期は切替後も元UIDへ固定し新UIDへは書かない', () async {
    final cloud = await signedCloud(email: 'a5@example.com', name: 'A');
    final uidA = cloud.uid;
    final holdPush = Completer<void>();
    var stalled = false;
    cloud.debugStallPush = () async {
      if (stalled) return;
      stalled = true;
      await holdPush.future;
    };

    final store = AppStore.seed();
    NexusPrefs.debugLoad = (_) async => const PrefsLoadResult.missing();
    await store.attachCloud(cloud);
    store.addStudySession(subjectId: 'sub', minutes: 15, focus: StudyFocus.four);
    await Future<void>.delayed(const Duration(milliseconds: 450));

    await cloud.signOut();
    store.detachCloud();
    await cloud.signUp(
      email: 'b5@example.com',
      password: 'secret123',
      displayName: 'B',
      occupation: '',
    );
    await cloud.confirmVerification();
    final uidB = cloud.uid;
    await store.attachCloud(cloud);
    holdPush.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final liveB = await cloud.backend.pullLive(uidB);
    final liveA = await cloud.backend.pullLive(uidA);
    final bSessions = (liveB?['sessions'] as List?) ?? const [];
    expect(bSessions.where((item) => item is Map && (item['minutes'] as int?) == 15), isEmpty);
    expect(liveA, isNotNull);
  });

  test('読込失敗を新規として空上書きしない', () async {
    final cloud = await signedCloud(email: 'a6@example.com', name: 'A');
    final uidA = cloud.uid;
    final bundle = ownedBundle(uidA);
    SharedPreferences.setMockInitialValues({
      NexusPrefs.keyFor(uidA)!: jsonEncode(bundle),
    });
    NexusPrefs.debugLoad = (_) async => const PrefsLoadResult.failed();
    final saved = <String>[];
    NexusPrefs.debugSave = (uid, data) async => saved.add(uid);

    final store = AppStore.seed();
    await store.attachCloud(cloud);
    store.addStudySession(subjectId: 'x', minutes: 5, focus: StudyFocus.four);
    expect(saved, isEmpty);

    NexusPrefs.debugLoad = null;
    NexusPrefs.debugSave = null;
    final disk = await NexusPrefs.loadBundle(uidA);
    expect(disk.hasData, isTrue);
    expect((disk.data?['friendGroups'] as List).single['name'], 'A組');
  });

  test('所有者不明の旧キーは新規ユーザーへ適用しない', () async {
    SharedPreferences.setMockInitialValues({
      NexusPrefs.legacyKey: jsonEncode(ownedBundle('legacy-owner')),
    });
    final cloud = await signedCloud(email: 'b7@example.com', name: 'B');
    final store = AppStore.seed();
    await store.attachCloud(cloud);
    expect(store.sessions, isEmpty);
    expect(store.friendGroups, isEmpty);
    expect(store.sleepStartedAt, isNull);
    expect(await NexusPrefs.loadUnownedLegacy(), isNotNull);
  });

  test('Firebase設定時は初期化失敗でもローカル認証へ切り替えない', () {
    expect(
      NexusCloud.useLocalAccounts(firebaseConfigured: true, widgetTest: false),
      isFalse,
    );
    expect(
      NexusCloud.useLocalAccounts(firebaseConfigured: false, widgetTest: false),
      isTrue,
    );
    expect(
      NexusCloud.useLocalAccounts(firebaseConfigured: true, widgetTest: true),
      isTrue,
    );
  });

  test('ゲストは明示選択で入り、セッション世代が変わる', () async {
    final cloud = await signedCloud(email: 'a8@example.com', name: 'A');
    final before = cloud.identity;
    await cloud.enterGuestSession();
    expect(cloud.isGuest, isTrue);
    expect(cloud.identity.mode, AuthMode.guest);
    expect(cloud.identity.sameAs(before), isFalse);
  });
}
