import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus/cloud/cloud_models.dart';
import 'package:nexus/cloud/friend_models.dart';
import 'package:nexus/cloud/local_backend.dart';
import 'package:nexus/cloud/share_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ACL ID は item_id と viewer_id の連結だけを正規とする', () {
    expect(ShareAccess.aclId('item1', 'bob'), 'item1_bob');
    expect(
      ShareAccess.aclMatches(docId: 'item1_bob', itemId: 'item1', viewerId: 'bob'),
      isTrue,
    );
    expect(
      ShareAccess.aclMatches(docId: 'forged', itemId: 'item1', viewerId: 'bob'),
      isFalse,
    );
  });

  test('所有者は変わらず、再フレンドだけでは旧ACLを復活させない', () {
    expect(
      ShareAccess.ownerImmutable(existingOwnerId: 'alice', requestedOwnerId: 'bob'),
      isFalse,
    );
    expect(
      ShareAccess.grantSurvivesRefriend(
        aclGrantedAt: DateTime(2026, 1, 1),
        friendshipStartedAt: DateTime(2026, 9, 1),
      ),
      isFalse,
    );
    expect(
      ShareAccess.grantSurvivesRefriend(
        aclGrantedAt: DateTime(2026, 9, 2),
        friendshipStartedAt: DateTime(2026, 9, 1),
      ),
      isTrue,
    );
  });

  test('Aが共有しBは閲覧でき、Cと無承認・偽装ACLは拒否される', () async {
    final cloud = LocalBackend();
    await cloud.init();
    final alice = await _signUp(cloud, 'alice@example.com', 'アリス');
    final aliceCode = (await cloud.ensureFriendCode()).friendCode;
    await cloud.signOut();

    final bob = await _signUp(cloud, 'bob@example.com', 'ボブ');
    await cloud.signOut();
    final carol = await _signUp(cloud, 'carol@example.com', 'キャロル');
    await cloud.signOut();

    await _befriend(cloud, ownerEmail: 'alice@example.com', otherEmail: 'bob@example.com', ownerCode: aliceCode);

    await cloud.signIn(email: 'alice@example.com', password: 'secret123');
    await cloud.shareItem(
      type: SharedKind.schedule,
      sourceLocalId: 's1',
      payload: {'title': '勉強会'},
      viewerIds: [bob.uid],
    );
    final item = await cloud.findMyShare(SharedKind.schedule, 's1');
    expect(item, isNotNull);
    expect(
      () => cloud.debugAttemptChangeOwner(item!.id, bob.uid),
      throwsA(isA<CloudException>()),
    );
    await cloud.signOut();

    await cloud.signIn(email: 'bob@example.com', password: 'secret123');
    expect(await cloud.listSharedWithMe(), isEmpty);
    final pending = await cloud.listSharedWithMe(pendingOnly: true);
    expect(pending.single.title, '勉強会');
    await cloud.respondShare(pending.single.aclId, accept: true);
    expect((await cloud.listSharedWithMe()).single.title, '勉強会');
    await cloud.signOut();

    await cloud.signIn(email: 'carol@example.com', password: 'secret123');
    expect(await cloud.listSharedWithMe(), isEmpty);
    cloud.debugPutAcl(itemId: item!.id, viewerId: carol.uid);
    expect(await cloud.listSharedWithMe(), isEmpty, reason: '無承認の関係では読めない');
    cloud.debugPutAcl(itemId: item.id, viewerId: carol.uid, docId: 'forged');
    expect(await cloud.listSharedWithMe(), isEmpty, reason: 'ACL偽装は拒否');
    await cloud.signOut();

    await cloud.signIn(email: 'alice@example.com', password: 'secret123');
    expect(
      () => cloud.shareItem(
        type: SharedKind.schedule,
        sourceLocalId: 's2',
        payload: {'title': '秘密'},
        viewerIds: [carol.uid],
      ),
      throwsA(isA<CloudException>()),
    );
    expect(alice.uid, isNot(bob.uid));
  });

  test('解除後はACLが残っても読めず、再フレンドでも自動復活しない', () async {
    final cloud = LocalBackend();
    await cloud.init();
    await _signUp(cloud, 'alice@example.com', 'アリス');
    final aliceCode = (await cloud.ensureFriendCode()).friendCode;
    await cloud.signOut();
    final bob = await _signUp(cloud, 'bob@example.com', 'ボブ');
    await cloud.signOut();

    await _befriend(cloud, ownerEmail: 'alice@example.com', otherEmail: 'bob@example.com', ownerCode: aliceCode);

    await cloud.signIn(email: 'alice@example.com', password: 'secret123');
    await cloud.shareItem(
      type: SharedKind.schedule,
      sourceLocalId: 's1',
      payload: {'title': '勉強会'},
      viewerIds: [bob.uid],
    );
    final item = (await cloud.findMyShare(SharedKind.schedule, 's1'))!;
    cloud.debugSkipAclRevoke = true;
    await cloud.removeFriend(bob.uid);
    cloud.debugSkipAclRevoke = false;
    await cloud.signOut();

    await cloud.signIn(email: 'bob@example.com', password: 'secret123');
    expect(await cloud.listSharedWithMe(), isEmpty, reason: '解除後はACL掃除失敗でも読めない');
    await cloud.signOut();

    await _befriend(cloud, ownerEmail: 'alice@example.com', otherEmail: 'bob@example.com', ownerCode: aliceCode);

    await cloud.signIn(email: 'bob@example.com', password: 'secret123');
    expect(await cloud.listSharedWithMe(), isEmpty, reason: '再フレンドでも旧ACLは復活しない');
    await cloud.signOut();

    await cloud.signIn(email: 'alice@example.com', password: 'secret123');
    await cloud.shareItem(
      type: SharedKind.schedule,
      sourceLocalId: 's1',
      payload: {'title': '勉強会'},
      viewerIds: [bob.uid],
    );
    await cloud.signOut();

    await cloud.signIn(email: 'bob@example.com', password: 'secret123');
    final reshared = await cloud.listSharedWithMe(pendingOnly: true);
    expect(reshared.single.title, '勉強会');
    await cloud.respondShare(reshared.single.aclId, accept: true);
    expect((await cloud.listSharedWithMe()).single.title, '勉強会');

    await cloud.signIn(email: 'alice@example.com', password: 'secret123');
    await cloud.revokeShareBySource(SharedKind.schedule, 's1');
    cloud.debugPutAcl(
      itemId: item.id,
      viewerId: bob.uid,
      createdAt: DateTime.now().add(const Duration(days: 1)),
    );
    await cloud.signOut();
    await cloud.signIn(email: 'bob@example.com', password: 'secret123');
    expect(await cloud.listSharedWithMe(), isEmpty, reason: '削除済み共有は旧IDでも読めない');
  });
}

Future<CloudSession> _signUp(LocalBackend cloud, String email, String name) {
  return cloud.signUp(
    email: email,
    password: 'secret123',
    displayName: name,
    occupation: '',
  );
}

Future<void> _befriend(
  LocalBackend cloud, {
  required String ownerEmail,
  required String otherEmail,
  required String ownerCode,
}) async {
  await cloud.signIn(email: otherEmail, password: 'secret123');
  final found = await cloud.lookupFriend(ownerCode);
  await cloud.sendFriendRequest(found!.uid);
  await cloud.signOut();

  await cloud.signIn(email: ownerEmail, password: 'secret123');
  final incoming = await cloud.incomingFriendRequests();
  await cloud.respondFriendRequest(incoming.single.id, accept: true);
  await cloud.signOut();
}
