import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus/app/app.dart';
import 'package:nexus/cloud/friend_models.dart';
import 'package:nexus/cloud/local_backend.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/screens/friends/chat_page.dart';
import 'package:nexus/screens/friends/circle_detail_page.dart';
import 'package:nexus/screens/friends/friends_page.dart';
import 'package:nexus/screens/friends/memory_album_page.dart';
import 'package:nexus/widgets/nexus_nav_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ハイフン付きコードでもフレンドを探せる', () async {
    final cloud = LocalBackend();
    await cloud.init();
    await cloud.signUp(
      email: 'alice@example.com',
      password: 'secret123',
      displayName: 'アリス',
      occupation: '',
    );
    final code = (await cloud.ensureFriendCode()).friendCode;
    expect(code, hasLength(8));
    await cloud.signOut();

    await cloud.signUp(
      email: 'bob@example.com',
      password: 'secret123',
      displayName: 'ボブ',
      occupation: '',
    );
    final hyphenated = '${code.substring(0, 4)}-${code.substring(4)}';
    expect(await cloud.lookupFriend(hyphenated), isNotNull);
    expect((await cloud.lookupFriend(hyphenated))?.displayName, 'アリス');
    expect((await cloud.lookupFriend(' $code ')), isNotNull);
    expect(await cloud.lookupFriend('not-a-code'), isNull);
  });

  test('日記はすぐ見え、予定は承認後に見え、リアクションと返信ができる', () async {
    final cloud = LocalBackend();
    await cloud.init();
    final alice = await cloud.signUp(
      email: 'alice@example.com',
      password: 'secret123',
      displayName: 'アリス',
      occupation: '',
    );
    final aliceCode = (await cloud.ensureFriendCode()).friendCode;
    await cloud.signOut();
    final bob = await cloud.signUp(
      email: 'bob@example.com',
      password: 'secret123',
      displayName: 'ボブ',
      occupation: '',
    );
    await cloud.signOut();

    await cloud.signIn(email: 'bob@example.com', password: 'secret123');
    await cloud.sendFriendRequest((await cloud.lookupFriend(aliceCode))!.uid);
    await cloud.signOut();
    await cloud.signIn(email: 'alice@example.com', password: 'secret123');
    await cloud.respondFriendRequest((await cloud.incomingFriendRequests()).single.id, accept: true);

    await cloud.shareItem(
      type: SharedKind.diary,
      sourceLocalId: 'd1',
      payload: {'title': '今日', 'body': '晴れ'},
      viewerIds: [bob.uid],
    );
    await cloud.shareItem(
      type: SharedKind.schedule,
      sourceLocalId: 's1',
      payload: {'title': '勉強会', 'start_at': DateTime(2026, 9, 12, 18).toIso8601String()},
      viewerIds: [bob.uid],
    );
    await cloud.signOut();

    await cloud.signIn(email: 'bob@example.com', password: 'secret123');
    expect((await cloud.listSharedWithMe(type: SharedKind.diary)).single.body, '晴れ');
    expect(await cloud.listSharedWithMe(type: SharedKind.schedule), isEmpty);
    final pending = await cloud.listSharedWithMe(pendingOnly: true);
    expect(pending.single.title, '勉強会');
    await cloud.respondShare(pending.single.aclId, accept: true);
    expect((await cloud.listSharedWithMe(type: SharedKind.schedule)).single.title, '勉強会');

    final diary = (await cloud.listSharedWithMe(type: SharedKind.diary)).single;
    await cloud.reactToShare(diary.id, '🔥');
    await cloud.replyToShare(diary.id, 'いいね');
    expect((await cloud.listReactions(diary.id)).single.emoji, '🔥');
    expect((await cloud.listReplies(diary.id)).single.body, 'いいね');
    expect(alice.uid, isNot(bob.uid));
  });

  test('サークルの投票・やりたいことと思い出アルバムができる', () async {
    final cloud = LocalBackend();
    await cloud.init();
    await cloud.signUp(
      email: 'alice@example.com',
      password: 'secret123',
      displayName: 'アリス',
      occupation: '',
    );
    final circle = await cloud.createCircle(name: '大学の友だち', memberIds: const []);
    final poll = await cloud.createPoll(
      circleId: circle.id,
      title: 'いつ集まる？',
      options: const ['土曜', '日曜'],
    );
    await cloud.votePoll(poll.id, 1);
    expect((await cloud.listPolls(circle.id)).single.counts, [0, 1]);
    final want = await cloud.addWant(circleId: circle.id, title: 'カフェに行く');
    await cloud.toggleWant(want.id);
    expect((await cloud.listWants(circle.id)).single.done, isTrue);

    final album = await cloud.createAlbum(title: '夏の思い出', participantIds: const []);
    await cloud.addMemoryPhoto(
      albumId: album.id,
      day: DateTime(2026, 8, 10),
      dataB64: 'Zm9v',
    );
    final photos = await cloud.listMemoryPhotos(album.id);
    expect(photos, hasLength(1));
    expect(photos.single.day.day, 10);
    expect(photos.single.src, contains('base64'));
    await cloud.addPhotoComment(albumId: album.id, photoId: photos.single.id, body: '最高');
    expect((await cloud.listPhotoComments(albumId: album.id, photoId: photos.single.id)).single.body, '最高');
    await cloud.updateAlbum(album.copyWith(title: '夏の記録'));
    expect((await cloud.listAlbums()).single.title, '夏の記録');
  });

  test('アイコンとトークができる', () async {
    final cloud = LocalBackend();
    await cloud.init();
    final alice = await cloud.signUp(
      email: 'alice@example.com',
      password: 'secret123',
      displayName: 'アリス',
      occupation: '',
    );
    await cloud.updateProfile(displayName: 'アリス', occupation: '', photoUrl: 'data:image/png;base64,Zm9v');
    final aliceCode = (await cloud.ensureFriendCode()).friendCode;
    expect((await cloud.ensureFriendCode()).photoUrl, 'data:image/png;base64,Zm9v');
    await cloud.signOut();

    final bob = await cloud.signUp(
      email: 'bob@example.com',
      password: 'secret123',
      displayName: 'ボブ',
      occupation: '',
    );
    await cloud.sendFriendRequest((await cloud.lookupFriend(aliceCode))!.uid);
    await cloud.signOut();
    await cloud.signIn(email: 'alice@example.com', password: 'secret123');
    await cloud.respondFriendRequest((await cloud.incomingFriendRequests()).single.id, accept: true);
    await cloud.signOut();

    await cloud.signIn(email: 'bob@example.com', password: 'secret123');
    expect((await cloud.listFriends()).single.photoUrl, 'data:image/png;base64,Zm9v');
    final chatId = await cloud.ensureDmChat(alice.uid);
    await cloud.sendMessage(chatId, body: '今空いてる？');
    expect((await cloud.listMessages(chatId)).single.body, '今空いてる？');
    final uploaded = await cloud.uploadMedia([1, 2, 3], mime: 'image/png');
    expect(uploaded, startsWith('data:image/png;base64,'));
    await cloud.sendMessage(chatId, imageUrl: uploaded);
    expect((await cloud.listMessages(chatId)).last.imageUrl, uploaded);

    final circle = await cloud.createCircle(name: '大学の友だち', memberIds: [alice.uid]);
    final groupId = await cloud.ensureCircleChat(circle);
    await cloud.sendMessage(groupId, body: '集合ね');
    expect((await cloud.listMessages(groupId)).single.body, '集合ね');
    expect(bob.uid, isNot(alice.uid));
  });

  test('共有予定は同じsourceなら二重に入らない', () {
    final store = AppStore.seed();
    final start = DateTime(2026, 9, 12, 18);
    store.addSchedule(title: '勉強会', startAt: start, endAt: DateTime(2026, 9, 12, 20), source: 'shared:item1');
    store.addSchedule(title: '勉強会', startAt: start, source: 'shared:item1');
    expect(store.schedules.where((item) => item.source == 'shared:item1'), hasLength(1));
  });

  testWidgets('Friendタブから追加・グループ・思い出を開ける', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NexusApp());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('今日の予定').evaluate().isNotEmpty) break;
    }
    expect(find.text('今日の予定'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(NexusNavBar), matching: find.text('Friend')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('friend-add')));
    await tester.pumpAndSettle();
    expect(find.byType(FriendAddPage), findsOneWidget);
    expect(find.text('フレンドコード'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(FriendAddPage), matching: find.byIcon(Icons.close_rounded)));
    await tester.pumpAndSettle();
    expect(find.byType(FriendAddPage), findsNothing);

    await tester.tap(find.text('作る'));
    await tester.pumpAndSettle();
    expect(find.text('グループを作る'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '大学の友だち');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('大学の友だち'), findsWidgets);

    await tester.tap(find.text('大学の友だち').first);
    await tester.pumpAndSettle();
    expect(find.byType(ChatPage), findsOneWidget);
    await tester.tap(find.text('詳細'));
    await tester.pumpAndSettle();
    expect(find.byType(CircleDetailPage), findsOneWidget);
    await tester.enterText(
      find.descendant(of: find.byType(CircleDetailPage), matching: find.byType(TextField)),
      'カフェに行く',
    );
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('カフェに行く'), findsOneWidget);
    await tester.tap(find.text('投票を作る'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(find.descendant(of: dialog, matching: find.text('日程投票')), findsOneWidget);
    await tester.enterText(find.descendant(of: dialog, matching: find.byType(TextField)).at(0), 'いつ集まる？');
    await tester.enterText(find.descendant(of: dialog, matching: find.byType(TextField)).at(1), '土曜');
    await tester.enterText(find.descendant(of: dialog, matching: find.byType(TextField)).at(2), '日曜');
    await tester.tap(find.descendant(of: dialog, matching: find.text('作る')));
    await tester.pumpAndSettle();
    expect(find.text('いつ集まる？'), findsOneWidget);
    await tester.tap(find.text('投票').first);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('アルバムを作る'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryCreatePage), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '夏の思い出');
    await tester.tap(find.descendant(of: find.byType(MemoryCreatePage), matching: find.text('作る')));
    await tester.pumpAndSettle();
    expect(find.text('夏の思い出'), findsOneWidget);
    await tester.tap(find.text('夏の思い出'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryAlbumPage), findsOneWidget);
    expect(find.text('写真を追加するには日付をタップ'), findsOneWidget);
  });
}
