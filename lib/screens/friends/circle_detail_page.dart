import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../cloud/cloud_models.dart';
import '../../cloud/friend_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_bits.dart';

class CircleEditPage extends StatefulWidget {
  const CircleEditPage({super.key, this.existing});

  final FriendCircle? existing;

  @override
  State<CircleEditPage> createState() => _CircleEditPageState();
}

class _CircleEditPageState extends State<CircleEditPage> {
  late final TextEditingController _name;
  var _friends = <FriendProfile>[];
  final _selected = <String>{};
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _selected.addAll(widget.existing?.memberIds ?? const []);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final friends = await CloudScope.of(context).listFriends();
    if (!mounted) return;
    setState(() {
      _friends = friends;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showNexusToast(context, 'グループ名を入力してください');
      return;
    }
    final cloud = CloudScope.of(context);
    try {
      if (widget.existing == null) {
        await cloud.createCircle(name: name, memberIds: _selected.toList());
      } else {
        await cloud.updateCircle(
          widget.existing!.copyWith(name: name, memberIds: _selected.toList()),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showNexusToast(context, cloudErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'グループを作る' : 'グループを編集'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'グループ名',
                    hintText: '大学の友だち、バイト仲間…',
                  ),
                ),
                const SizedBox(height: 16),
                Text('メンバー', style: TextStyle(color: NexusColors.textMuted)),
                const SizedBox(height: 8),
                for (final friend in _friends)
                  CheckboxListTile(
                    value: _selected.contains(friend.uid),
                    title: Text(friend.displayName),
                    subtitle: Text(friend.friendCode),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(friend.uid);
                        } else {
                          _selected.remove(friend.uid);
                        }
                      });
                    },
                  ),
              ],
            ),
    );
  }
}

class CircleDetailPage extends StatefulWidget {
  const CircleDetailPage({super.key, required this.circle});

  final FriendCircle circle;

  @override
  State<CircleDetailPage> createState() => _CircleDetailPageState();
}

class _CircleDetailPageState extends State<CircleDetailPage> {
  late FriendCircle _circle;
  var _polls = <CirclePoll>[];
  var _wants = <CircleWant>[];
  var _loading = true;
  final _want = TextEditingController();

  @override
  void initState() {
    super.initState();
    _circle = widget.circle;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _want.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final cloud = CloudScope.of(context);
    setState(() => _loading = true);
    try {
      final polls = await cloud.listPolls(_circle.id);
      final wants = await cloud.listWants(_circle.id);
      if (!mounted) return;
      setState(() {
        _polls = polls;
        _wants = wants;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNexusToast(context, cloudErrorMessage(error));
    }
  }

  Future<void> _addWant() async {
    final title = _want.text.trim();
    if (title.isEmpty) return;
    try {
      await CloudScope.of(context).addWant(circleId: _circle.id, title: title);
      _want.clear();
      await _reload();
    } catch (error) {
      if (mounted) showNexusToast(context, cloudErrorMessage(error));
    }
  }

  Future<void> _createPoll() async {
    final title = TextEditingController();
    final o1 = TextEditingController();
    final o2 = TextEditingController();
    final o3 = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('日程投票'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: '何の予定？')),
            TextField(controller: o1, decoration: const InputDecoration(labelText: '候補1')),
            TextField(controller: o2, decoration: const InputDecoration(labelText: '候補2')),
            TextField(controller: o3, decoration: const InputDecoration(labelText: '候補3（任意）')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('やめる')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('作る')),
        ],
      ),
    );
    if (created != true || !mounted) return;
    final options = [o1.text, o2.text, o3.text].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (title.text.trim().isEmpty || options.length < 2) {
      showNexusToast(context, 'タイトルと候補を2つ以上入れてください');
      return;
    }
    try {
      await CloudScope.of(context).createPoll(
        circleId: _circle.id,
        title: title.text.trim(),
        options: options,
      );
      await _reload();
    } catch (error) {
      if (mounted) showNexusToast(context, cloudErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_circle.name),
        actions: [
          IconButton(
            tooltip: '編集',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => CircleEditPage(existing: _circle)),
              );
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('このグループでは日記や予定をまとめて共有できます', style: TextStyle(color: NexusColors.textMuted)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Text('日程投票', style: TextStyle(fontWeight: FontWeight.w800))),
                    TextButton(onPressed: _createPoll, child: const Text('投票を作る')),
                  ],
                ),
                if (_polls.isEmpty)
                  Text('まだ投票はありません', style: TextStyle(color: NexusColors.textMuted))
                else
                  for (final poll in _polls)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(poll.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            for (var i = 0; i < poll.options.length; i++)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(poll.options[i]),
                                subtitle: Text('${poll.votes.values.where((v) => v == i).length}票'),
                                trailing: FilledButton.tonal(
                                  onPressed: cloud.busy
                                      ? null
                                      : () async {
                                          try {
                                            await cloud.votePoll(poll.id, i);
                                            await _reload();
                                          } catch (error) {
                                            if (!context.mounted) return;
                                            showNexusToast(context, cloudErrorMessage(error));
                                          }
                                        },
                                  child: const Text('投票'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 16),
                const Text('やりたいことリスト', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _want,
                        decoration: const InputDecoration(hintText: 'やりたいことを追加'),
                        onSubmitted: (_) => _addWant(),
                      ),
                    ),
                    IconButton(onPressed: _addWant, icon: const Icon(Icons.add_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final want in _wants)
                  CheckboxListTile(
                    value: want.done,
                    title: Text(
                      want.title,
                      style: TextStyle(decoration: want.done ? TextDecoration.lineThrough : null),
                    ),
                    onChanged: cloud.busy
                        ? null
                        : (_) async {
                            try {
                              await cloud.toggleWant(want.id);
                              await _reload();
                            } catch (error) {
                              if (!context.mounted) return;
                              showNexusToast(context, cloudErrorMessage(error));
                            }
                          },
                  ),
              ],
            ),
    );
  }
}
