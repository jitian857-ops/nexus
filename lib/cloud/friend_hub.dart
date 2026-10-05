import 'cloud_backend.dart';
import 'friend_models.dart';

Future<List<T>> _softList<T>(Future<List<T>> Function() load) async {
  try {
    return await load();
  } catch (_) {
    return <T>[];
  }
}

/// Friendタブ用。独立した5本の待ちを同時に走らせ、日記と予定承認は一覧から振り分ける。
Future<FriendHubSnapshot> fetchFriendHub(CloudBackend backend) async {
  late List<FriendProfile> friends;
  late List<SharedItem> accepted;
  late List<SharedItem> pending;
  late List<FriendCircle> circles;
  late List<MemoryAlbum> albums;
  await Future.wait([
    () async {
      friends = await _softList(backend.listFriends);
    }(),
    () async {
      accepted = await _softList(() => backend.listSharedWithMe(type: SharedKind.diary, limit: 40));
    }(),
    () async {
      pending = await _softList(
        () => backend.listSharedWithMe(type: SharedKind.schedule, pendingOnly: true, limit: 40),
      );
    }(),
    () async {
      circles = await _softList(backend.listCircles);
    }(),
    () async {
      albums = await _softList(backend.listAlbums);
    }(),
  ]);
  return FriendHubSnapshot(
    friends: friends,
    diaries: [
      for (final item in accepted)
        if (item.diaryShareVisible()) item,
    ],
    pendingSchedules: pending,
    circles: circles,
    albums: albums,
  );
}
