import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../cloud/cloud_models.dart';
import '../../cloud/friend_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../widgets/friend_avatar.dart';
import '../../widgets/ui_bits.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.chatId,
    required this.title,
    this.detailBuilder,
  });

  final String chatId;
  final String title;
  final WidgetBuilder? detailBuilder;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  var _messages = <TalkMessage>[];
  var _loading = true;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final messages = await CloudScope.of(context).listMessages(widget.chatId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      _jumpToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNexusToast(context, cloudErrorMessage(error));
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send({String imageUrl = ''}) async {
    final body = _text.text.trim();
    if (body.isEmpty && imageUrl.isEmpty) return;
    setState(() => _sending = true);
    try {
      await CloudScope.of(context).sendMessage(widget.chatId, body: body, imageUrl: imageUrl);
      _text.clear();
      await _reload();
    } catch (error) {
      if (mounted) showNexusToast(context, cloudErrorMessage(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPhoto() async {
    final url = await pickAndUploadMedia(context);
    if (url == null || !mounted) return;
    await _send(imageUrl: url);
  }

  @override
  Widget build(BuildContext context) {
    final me = CloudScope.of(context).uid;
    return Scaffold(
      key: const Key('chat-page'),
      backgroundColor: NexusColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.detailBuilder != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: widget.detailBuilder!),
                );
              },
              child: const Text('詳細'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text('まだメッセージはありません', style: TextStyle(color: NexusColors.textMuted)),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final mine = message.authorId == me;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                              children: [
                                if (!mine) ...[
                                  FriendAvatar(
                                    name: message.author?.displayName ?? '',
                                    photoUrl: message.author?.photoUrl ?? '',
                                    radius: 14,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                    decoration: BoxDecoration(
                                      color: mine
                                          ? NexusColors.cyan.withValues(alpha: 0.22)
                                          : NexusColors.surface,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!mine)
                                          Text(
                                            message.author?.displayName ?? '',
                                            style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
                                          ),
                                        if (message.imageUrl.isNotEmpty) ...[
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: NexusImage(src: message.imageUrl, width: 180, height: 180),
                                          ),
                                          if (message.body.isNotEmpty) const SizedBox(height: 6),
                                        ],
                                        if (message.body.isNotEmpty)
                                          Text(message.body, style: const TextStyle(height: 1.35)),
                                      ],
                                    ),
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
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _sending ? null : _sendPhoto,
                    icon: Icon(Icons.photo_outlined, color: NexusColors.cyan),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(hintText: 'メッセージ'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
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
