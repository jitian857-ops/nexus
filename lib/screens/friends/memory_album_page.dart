import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../cloud/cloud_models.dart';
import '../../cloud/friend_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../core/format.dart';
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
  var _withFriend = '';
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
      final participants = <String>{};
      if (_withFriend.isNotEmpty) participants.add(_withFriend);
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
          Text('友だちと', style: TextStyle(color: NexusColors.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('指定しない'),
                selected: _withFriend.isEmpty,
                onSelected: (_) => setState(() => _withFriend = ''),
              ),
              for (final friend in widget.friends)
                ChoiceChip(
                  label: Text(friend.displayName),
                  selected: _withFriend == friend.uid,
                  onSelected: (_) => setState(() => _withFriend = friend.uid),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('グループと', style: TextStyle(color: NexusColors.textMuted)),
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
  const MemoryAlbumPage({super.key, required this.album});

  final MemoryAlbum album;

  @override
  State<MemoryAlbumPage> createState() => _MemoryAlbumPageState();
}

class _MemoryAlbumPageState extends State<MemoryAlbumPage> {
  late DateTime _month;
  var _photos = <MemoryPhoto>[];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final photos = await CloudScope.of(context).listMemoryPhotos(widget.album.id);
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

  Future<void> _addPhoto(DateTime day, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 72,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 900 * 1024) {
      showNexusToast(context, '画像が大きすぎます。もう少し小さい写真にしてください');
      return;
    }
    try {
      await CloudScope.of(context).addMemoryPhoto(
        albumId: widget.album.id,
        day: day,
        dataB64: base64Encode(bytes),
        mime: file.mimeType ?? 'image/jpeg',
      );
      await _reload();
    } catch (error) {
      if (mounted) showNexusToast(context, cloudErrorMessage(error));
    }
  }

  Future<void> _pickSource(DateTime day) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('アルバムから選ぶ'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('カメラで撮る'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _addPhoto(day, source);
  }

  @override
  Widget build(BuildContext context) {
    final label = jpMonth(_month);
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday % 7;
    return Scaffold(
      appBar: AppBar(title: Text(widget.album.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                Text('写真を追加するには日付をタップ', style: TextStyle(color: NexusColors.textMuted)),
              ],
            ),
    );
  }

  Future<void> _showDay(DateTime day, List<MemoryPhoto> photos) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${day.month}月${day.day}日', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              if (photos.isEmpty)
                Text('まだ写真がありません', style: TextStyle(color: NexusColors.textMuted))
              else
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final bytes = _decode(photos[index].dataB64);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: bytes == null
                            ? const SizedBox(width: 120, child: Center(child: Text('画像なし')))
                            : Image.memory(bytes, width: 120, height: 160, fit: BoxFit.cover),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickSource(day);
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('写真を追加'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Uint8List? _decode(String data) {
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }
}
