import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../cloud/cloud_models.dart';
import '../../cloud/friend_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_bits.dart';

class FriendGroupEditPage extends StatefulWidget {
  const FriendGroupEditPage({super.key, this.existing});

  final FriendGroup? existing;

  @override
  State<FriendGroupEditPage> createState() => _FriendGroupEditPageState();
}

class _FriendGroupEditPageState extends State<FriendGroupEditPage> {
  late final TextEditingController _name;
  var _friends = <FriendProfile>[];
  var _selected = <String>{};
  var _loading = true;
  var _error = '';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _selected = {...(widget.existing?.memberIds ?? const [])};
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final friends = await CloudScope.of(context).listFriends();
      if (!mounted) return;
      setState(() {
        _friends = friends;
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

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showNexusToast(context, 'グループ名を入力してください');
      return;
    }
    final store = AppScope.of(context);
    final members = [
      for (final friend in _friends)
        if (_selected.contains(friend.uid)) friend.uid,
    ];
    final existing = widget.existing;
    if (existing == null) {
      store.addFriendGroup(name: name, memberIds: members);
    } else {
      store.updateFriendGroup(existing.copyWith(name: name, memberIds: members));
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return Scaffold(
      backgroundColor: NexusColors.background,
      body: PageScaffold(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: NexusColors.text),
                ),
                Expanded(
                  child: Text(
                    existing == null ? 'グループを作る' : 'グループを編集',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            GlassCard(
              child: TextField(
                controller: _name,
                style: TextStyle(color: NexusColors.text),
                decoration: const InputDecoration(labelText: 'グループ名'),
              ),
            ),
            const SizedBox(height: 12),
            Text('メンバー', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error.isNotEmpty)
              Text(_error, style: TextStyle(color: NexusColors.expense))
            else if (_friends.isEmpty)
              Text('先にフレンドを追加してください', style: TextStyle(color: NexusColors.textMuted))
            else
              GlassCard(
                child: Column(
                  children: [
                    for (final friend in _friends)
                      CheckboxListTile(
                        value: _selected.contains(friend.uid),
                        contentPadding: EdgeInsets.zero,
                        title: Text(friend.displayName),
                        subtitle: Text(
                          friend.friendCode,
                          style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                        ),
                        onChanged: (on) {
                          setState(() {
                            if (on == true) {
                              _selected.add(friend.uid);
                            } else {
                              _selected.remove(friend.uid);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('保存')),
            if (existing != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  AppScope.of(context).deleteFriendGroup(existing.id);
                  Navigator.pop(context, true);
                },
                child: Text('削除', style: TextStyle(color: NexusColors.expense)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
