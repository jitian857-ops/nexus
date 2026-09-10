import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../cloud/cloud_models.dart';
import '../../cloud/friend_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../data/app_store.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_bits.dart';
import 'circle_detail_page.dart';
import 'diary_story_page.dart';
import 'friends_page.dart';
import 'memory_album_page.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  var _loading = true;
  var _error = '';
  var _friends = <FriendProfile>[];
  var _diaries = <SharedItem>[];
  var _pending = <SharedItem>[];
  var _acceptedSchedules = <SharedItem>[];
  var _circles = <FriendCircle>[];
  var _albums = <MemoryAlbum>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final cloud = CloudScope.of(context);
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await cloud.ensureFriendCode();
      final friends = await _loadList(cloud.listFriends);
      final diaries = await _loadList(() => cloud.listSharedWithMe(type: SharedKind.diary, limit: 40));
      final pending = await _loadList(() => cloud.listSharedWithMe(pendingOnly: true, limit: 40));
      final schedules = await _loadList(() => cloud.listSharedWithMe(type: SharedKind.schedule, limit: 40));
      final circles = await _loadList(cloud.listCircles);
      final albums = await _loadList(cloud.listAlbums);
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _diaries = diaries;
        _pending = pending.where((item) => item.type == SharedKind.schedule).toList();
        _acceptedSchedules = schedules;
        _circles = circles;
        _albums = albums;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = cloudErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<List<T>> _loadList<T>(Future<List<T>> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return <T>[];
    }
  }

  Future<void> _openAdd() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const FriendAddPage()),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              const Expanded(child: GradientTitle('Friend')),
              IconButton(
                key: const Key('friend-add'),
                tooltip: 'フレンドを追加',
                onPressed: _openAdd,
                icon: Icon(Icons.person_add_alt_1_rounded, color: NexusColors.cyan),
              ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text(_error, style: TextStyle(color: NexusColors.expense)),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _reload, child: const Text('再試行')),
                ],
              ),
            )
          else ...[
            _StoriesRow(
              diaries: _diaries,
              onOpen: (start) async {
                await Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DiaryStoryPage(items: _diaries, initialIndex: start),
                  ),
                );
                if (mounted) await _reload();
              },
            ),
            const SizedBox(height: 16),
            Text('共有された予定', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            if (_pending.isEmpty && _acceptedSchedules.isEmpty)
              Text('届いた予定はまだありません', style: TextStyle(color: NexusColors.textMuted))
            else ...[
              for (final item in _pending) _PendingScheduleCard(item: item, onChanged: _reload),
              for (final item in _acceptedSchedules) _AcceptedScheduleCard(item: item),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text('グループ・サークル', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () async {
                    await Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(builder: (_) => const CircleEditPage()),
                    );
                    if (mounted) await _reload();
                  },
                  child: const Text('作る'),
                ),
              ],
            ),
            if (_circles.isEmpty)
              Text('大学の友だち、バイト仲間などをまとめられます', style: TextStyle(color: NexusColors.textMuted))
            else
              for (final circle in _circles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () async {
                      await Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute<void>(builder: (_) => CircleDetailPage(circle: circle)),
                      );
                      if (mounted) await _reload();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: GlassCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(circle.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('${circle.memberIds.length}人', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: NexusColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text('思い出', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () async {
                    await Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MemoryCreatePage(friends: _friends, circles: _circles),
                      ),
                    );
                    if (mounted) await _reload();
                  },
                  child: const Text('アルバムを作る'),
                ),
              ],
            ),
            if (_albums.isEmpty)
              Text('友だちやグループとの写真をカレンダーに残せます', style: TextStyle(color: NexusColors.textMuted))
            else
              for (final album in _albums)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () async {
                      await Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute<void>(builder: (_) => MemoryAlbumPage(album: album)),
                      );
                      if (mounted) await _reload();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: GlassCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(album.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Icon(Icons.photo_library_outlined, color: NexusColors.cyan),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 18),
            Text('フレンド', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            if (_friends.isEmpty)
              Text('右上からコードやQRで追加できます', style: TextStyle(color: NexusColors.textMuted))
            else
              for (final friend in _friends)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () async {
                      await Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute<void>(builder: (_) => FriendDetailPage(friend: friend)),
                      );
                      if (mounted) await _reload();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: GlassCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(friend.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(friend.friendCode, style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: NexusColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _StoriesRow extends StatelessWidget {
  const _StoriesRow({required this.diaries, required this.onOpen});

  final List<SharedItem> diaries;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    if (diaries.isEmpty) {
      return GlassCard(
        child: Text(
          '友だちの日記が届くと、ここにストーリーのように並びます',
          style: TextStyle(color: NexusColors.textMuted, height: 1.4),
        ),
      );
    }
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: diaries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = diaries[index];
          return GestureDetector(
            onTap: () => onOpen(index),
            child: SizedBox(
              width: 72,
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [NexusColors.cyan, NexusColors.purple]),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      backgroundColor: NexusColors.surface,
                      child: Text(
                        _storyInitial(item.owner?.displayName ?? '?'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.owner?.displayName ?? '日記',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PendingScheduleCard extends StatelessWidget {
  const _PendingScheduleCard({required this.item, required this.onChanged});

  final SharedItem item;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('承認待ちの予定', style: TextStyle(color: NexusColors.gold, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('from ${item.owner?.displayName ?? ''}', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: cloud.busy
                      ? null
                      : () async {
                          try {
                            await cloud.respondShare(item.aclId, accept: true);
                            if (context.mounted) await onChanged();
                          } catch (error) {
                            if (context.mounted) showNexusToast(context, cloudErrorMessage(error));
                          }
                        },
                  child: const Text('承認'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: cloud.busy
                      ? null
                      : () async {
                          try {
                            await cloud.respondShare(item.aclId, accept: false);
                            if (context.mounted) await onChanged();
                          } catch (error) {
                            if (context.mounted) showNexusToast(context, cloudErrorMessage(error));
                          }
                        },
                  child: const Text('拒否'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptedScheduleCard extends StatelessWidget {
  const _AcceptedScheduleCard({required this.item});

  final SharedItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('予定', style: TextStyle(color: NexusColors.cyan, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('from ${item.owner?.displayName ?? ''}', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  final start = DateTime.tryParse(item.payload['start_at'] as String? ?? '');
                  if (start == null) return;
                  final end = DateTime.tryParse(item.payload['end_at'] as String? ?? '');
                  AppScope.of(context).addSchedule(
                    title: item.title,
                    startAt: start,
                    endAt: end,
                    allDay: item.payload['all_day'] as bool? ?? false,
                    tags: [
                      for (final tag in (item.payload['tags'] as List? ?? const []))
                        if (tag is String) tag,
                    ],
                    source: 'shared',
                  );
                  showNexusToast(context, '自分の予定に複製しました');
                },
                child: const Text('自分用に複製'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _storyInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCodes(trimmed.runes.take(1));
}
