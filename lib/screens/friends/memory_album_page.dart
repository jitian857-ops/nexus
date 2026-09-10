import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../cloud/cloud_models.dart';
import '../../cloud/friend_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../widgets/friend_avatar.dart';
import '../../widgets/ui_bits.dart';

class MemoryCreatePage extends StatefulWidget {
  const MemoryCreatePage({super.key, required this.friends, required this.circles});

  final List<FriendProfile> friends;
  final List<FriendCircle> circles;

  @override
  State<MemoryCreatePage> createState() => _MemoryCreatePageState();
}

class _MemoryCreatePageState extends State<MemoryCreatePage> {
  final _title = TextEditingController();
  final _pickedFriends = <String>{};
  var _withCircle = '';

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showNexusToast(context, 'タイトルを入力してください');
      return;
    }
    try {
      final participants = <String>{..._pickedFriends};
      FriendCircle? circle;
      if (_withCircle.isNotEmpty) {
        for (final item in widget.circles) {
          if (item.id == _withCircle) circle = item;
        }
        if (circle != null) participants.addAll(circle.memberIds);
      }
      await CloudScope.of(context).createAlbum(
        title: title,
        participantIds: participants.toList(),
        circleId: _withCircle.isEmpty ? null : _withCircle,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showNexusToast(context, cloudErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('思い出アルバム'),
        actions: [TextButton(onPressed: _save, child: const Text('作る'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'タイトル', hintText: '2026夏、大学の友だち'),
          ),
          const SizedBox(height: 16),
          Text('メンバー', style: TextStyle(color: NexusColors.textMuted)),
          const SizedBox(height: 8),
          if (widget.friends.isEmpty)
            Text('フレンドを追加すると、一緒に残す人を選べます', style: TextStyle(color: NexusColors.textMuted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final friend in widget.friends)
                  FilterChip(
                    avatar: FriendAvatar(name: friend.displayName, photoUrl: friend.photoUrl, radius: 12),
                    label: Text(friend.displayName),
                    selected: _pickedFriends.contains(friend.uid),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _pickedFriends.add(friend.uid);
                      } else {
                        _pickedFriends.remove(friend.uid);
                      }
                    }),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Text('グループからも追加', style: TextStyle(color: NexusColors.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('指定しない'),
                selected: _withCircle.isEmpty,
                onSelected: (_) => setState(() => _withCircle = ''),
              ),
              for (final circle in widget.circles)
                ChoiceChip(
                  label: Text(circle.name),
                  selected: _withCircle == circle.id,
                  onSelected: (_) => setState(() => _withCircle = circle.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class MemoryAlbumPage extends StatefulWidget {
  const MemoryAlbumPage({super.key, required this.album, this.friends = const []});

  final MemoryAlbum album;
  final List<FriendProfile> friends;

  @override
  State<MemoryAlbumPage> createState() => _MemoryAlbumPageState();
}

class _MemoryAlbumPageState extends State<MemoryAlbumPage> {
  late MemoryAlbum _album;
  late DateTime _month;
  var _photos = <MemoryPhoto>[];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _album = widget.album;
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  FriendProfile _profileOf(String uid) {
    final store = AppScope.of(context);
    final me = CloudScope.of(context).uid;
    if (uid == me) {
      return FriendProfile(
        uid: uid,
        displayName: store.userName,
        friendCode: '',
        photoUrl: store.photoUrl,
      );
    }
    for (final friend in widget.friends) {
      if (friend.uid == uid) return friend;
    }
    return FriendProfile(uid: uid, displayName: 'メンバー', friendCode: '');
  }

  List<FriendProfile> get _members {
    final ids = <String>{_album.ownerId, ..._album.participantIds};
    return [for (final id in ids) _profileOf(id)];
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final photos = await CloudScope.of(context).listMemoryPhotos(_album.id);
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNexusToast(context, cloudErrorMessage(error));
    }
  }

  List<MemoryPhoto> _onDay(DateTime day) {
    return _photos.where((photo) {
      return photo.day.year == day.year &&
          photo.day.month == day.month &&
          photo.day.day == day.day;
    }).toList();
  }

  Future<void> _addPhotos(DateTime day, {required ImageSource source}) async {
    final urls = await pickAndUploadMediaList(context, source: source);
    if (urls.isEmpty || !mounted) return;
    final cloud = CloudScope.of(context);
    try {
      for (final url in urls) {
        await cloud.addMemoryPhoto(albumId: _album.id, day: day, url: url);
      }
      await _reload();
    } catch (error) {
      if (mounted) showNexusToast(context, cloudErrorMessage(error));
    }
  }

  Future<void> _editMembers() async {
    final cloud = CloudScope.of(context);
    if (_album.ownerId != cloud.uid) return;
    final selected = <String>{..._album.participantIds};
    final saved = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('メンバーを編集', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final friend in widget.friends)
                        FilterChip(
                          avatar: FriendAvatar(name: friend.displayName, photoUrl: friend.photoUrl, radius: 12),
                          label: Text(friend.displayName),
                          selected: selected.contains(friend.uid),
                          onSelected: (on) => setSheet(() {
                            if (on) {
                              selected.add(friend.uid);
                            } else {
                              selected.remove(friend.uid);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, selected),
                    child: const Text('保存'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (saved == null || !mounted) return;
    try {
      final next = _album.copyWith(participantIds: saved.toList());
      await cloud.updateAlbum(next);
      if (!mounted) return;
      setState(() => _album = next);
    } catch (error) {
      if (mounted) showNexusToast(context, cloudErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = jpMonth(_month);
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday % 7;
    final owner = CloudScope.of(context).uid == _album.ownerId;
    return Scaffold(
      appBar: AppBar(
        title: Text(_album.title),
        actions: [
          if (owner)
            TextButton(onPressed: _editMembers, child: const Text('メンバー')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('メンバー', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final member in _members)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FriendAvatar(name: member.displayName, photoUrl: member.photoUrl, radius: 14),
                          const SizedBox(width: 6),
                          Text(member.displayName),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(child: Center(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)))),
                    IconButton(
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final d in ['日', '月', '火', '水', '木', '金', '土'])
                      Expanded(
                        child: Center(
                          child: Text(d, style: TextStyle(color: NexusColors.textMuted, fontSize: 11)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: leading + daysInMonth,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemBuilder: (context, index) {
                    if (index < leading) return const SizedBox.shrink();
                    final day = DateTime(_month.year, _month.month, index - leading + 1);
                    final photos = _onDay(day);
                    return InkWell(
                      onTap: () => _showDay(day, photos),
                      borderRadius: BorderRadius.circular(8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: photos.isEmpty ? NexusColors.surface : NexusColors.cyan.withValues(alpha: 0.18),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (photos.isNotEmpty)
                              Text('${photos.length}', style: TextStyle(color: NexusColors.cyan, fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text('日付をタップして、同じ日に何枚でも写真を追加できます', style: TextStyle(color: NexusColors.textMuted)),
              ],
            ),
    );
  }

  Future<void> _showDay(DateTime day, List<MemoryPhoto> initial) async {
    var photos = [...initial];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            Future<void> addMore() async {
              final source = await pickImageSource(this.context);
              if (source == null) return;
              await _addPhotos(day, source: source);
              if (!this.context.mounted) return;
              setSheet(() => photos = _onDay(day));
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.58,
              minChildSize: 0.36,
              maxChildSize: 0.94,
              builder: (context, scroll) {
                return ListView(
                  controller: scroll,
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(sheetContext).bottom),
                  children: [
                    Text('${day.month}月${day.day}日', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(
                      photos.isEmpty ? 'まだ写真がありません' : '${photos.length}枚  ·  同じ日に何枚でも追加できます',
                      style: TextStyle(color: NexusColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    if (photos.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: photos.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          final photo = photos[index];
                          return GestureDetector(
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await Navigator.of(this.context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PhotoCommentsPage(album: _album, photo: photo),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: NexusImage(src: photo.src),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: addMore,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('写真を追加'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class PhotoCommentsPage extends StatefulWidget {
  const PhotoCommentsPage({super.key, required this.album, required this.photo});

  final MemoryAlbum album;
  final MemoryPhoto photo;

  @override
  State<PhotoCommentsPage> createState() => _PhotoCommentsPageState();
}

class _PhotoCommentsPageState extends State<PhotoCommentsPage> {
  final _text = TextEditingController();
  var _comments = <PhotoComment>[];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final comments = await CloudScope.of(context).listPhotoComments(
        albumId: widget.album.id,
        photoId: widget.photo.id,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNexusToast(context, cloudErrorMessage(error));
    }
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    try {
      await CloudScope.of(context).addPhotoComment(
        albumId: widget.album.id,
        photoId: widget.photo.id,
        body: body,
      );
      _text.clear();
      await _reload();
    } catch (error) {
      if (mounted) showNexusToast(context, cloudErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('写真')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: NexusImage(src: widget.photo.src),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(child: Text('コメントはまだありません', style: TextStyle(color: NexusColors.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FriendAvatar(
                                  name: comment.author?.displayName ?? '',
                                  photoUrl: comment.author?.photoUrl ?? '',
                                  radius: 14,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        comment.author?.displayName ?? 'メンバー',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      Text(comment.body),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration: const InputDecoration(hintText: 'コメントを書く'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: Icon(Icons.send_rounded, color: NexusColors.cyan),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
