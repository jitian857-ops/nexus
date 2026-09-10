import 'package:flutter/material.dart';

import '../../cloud/cloud_models.dart';
import '../../cloud/friend_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../widgets/friend_avatar.dart';
import '../../widgets/ui_bits.dart';

const _kReactions = ['❤️', '👍', '🔥', '😊', '😢', '👏'];

class DiaryStoryPage extends StatefulWidget {
  const DiaryStoryPage({super.key, required this.items, required this.initialIndex});

  final List<SharedItem> items;
  final int initialIndex;

  @override
  State<DiaryStoryPage> createState() => _DiaryStoryPageState();
}

class _DiaryStoryPageState extends State<DiaryStoryPage> {
  late final PageController _pages;
  var _index = 0;
  var _reactions = <ShareReaction>[];
  var _replies = <ShareReply>[];
  var _loading = true;
  final _reply = TextEditingController();

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.isEmpty ? 0 : widget.items.length - 1);
    _pages = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSide());
  }

  @override
  void dispose() {
    _pages.dispose();
    _reply.dispose();
    super.dispose();
  }

  SharedItem get _item => widget.items[_index];

  Future<void> _loadSide() async {
    if (widget.items.isEmpty) return;
    final cloud = CloudScope.of(context);
    setState(() => _loading = true);
    try {
      final reactions = await cloud.listReactions(_item.id);
      final replies = await cloud.listReplies(_item.id);
      if (!mounted) return;
      setState(() {
        _reactions = reactions;
        _replies = replies;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _react(String emoji) async {
    try {
      await CloudScope.of(context).reactToShare(_item.id, emoji);
      await _loadSide();
    } catch (error) {
      if (mounted) showNexusToast(context, cloudErrorMessage(error));
    }
  }

  Future<void> _sendReply() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    try {
      await CloudScope.of(context).replyToShare(_item.id, text);
      _reply.clear();
      await _loadSide();
    } catch (error) {
      if (mounted) showNexusToast(context, cloudErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Scaffold(body: Center(child: Text('日記がありません')));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  for (var i = 0; i < widget.items.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: LinearProgressIndicator(
                          value: i < _index ? 1 : i == _index ? 1 : 0,
                          minHeight: 3,
                          backgroundColor: Colors.white24,
                          color: i <= _index ? Colors.white : Colors.white24,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: widget.items.length,
                onPageChanged: (value) {
                  setState(() => _index = value);
                  _loadSide();
                },
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final body = item.payload['body'] as String? ?? item.payload['content'] as String? ?? '';
                  return GestureDetector(
                    onTapUp: (details) {
                      final width = MediaQuery.sizeOf(context).width;
                      if (details.globalPosition.dx > width * 0.65 && index < widget.items.length - 1) {
                        _pages.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
                      } else if (details.globalPosition.dx < width * 0.35 && index > 0) {
                        _pages.previousPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.owner?.displayName ?? '友だち',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.title,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    body.isEmpty && item.imageUrls.isEmpty ? '（本文なし）' : body,
                                    style: const TextStyle(color: Colors.white, fontSize: 20, height: 1.5),
                                  ),
                                  if (item.imageUrls.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    for (final url in item.imageUrls) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: NexusImage(src: url, height: 220),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final emoji in _kReactions)
                    InkWell(
                      onTap: () => _react(emoji),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                ],
              ),
            ),
            if (!_loading && _reactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  _reactions.map((r) => r.emoji).join(' '),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            if (_replies.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final reply in _replies.take(4))
                      Text(
                        '${reply.author?.displayName ?? '友だち'}: ${reply.body}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reply,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'ひとこと返信',
                        hintStyle: TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _sendReply(),
                    ),
                  ),
                  IconButton(
                    onPressed: _sendReply,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
