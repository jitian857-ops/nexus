import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../cloud/cloud_models.dart';
import '../../cloud/friend_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../core/format.dart';
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
    final draft = await showDialog<({String title, List<String> options, DateTime deadline})>(
      context: context,
      builder: (context) => const _CreatePollDialog(),
    );
    if (draft == null || !mounted) return;
    try {
      await CloudScope.of(context).createPoll(
        circleId: _circle.id,
        title: draft.title,
        options: draft.options,
        deadline: draft.deadline,
      );
      await _reload();
    } catch (error) {
      if (mounted) showNexusToast(context, cloudErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    final current = [
      for (final poll in _polls)
        if (poll.stage() != PollStage.archived) poll,
    ];
    final past = [
      for (final poll in _polls)
        if (poll.stage() == PollStage.archived) poll,
    ];
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
                if (current.isEmpty && past.isEmpty)
                  Text('まだ投票はありません', style: TextStyle(color: NexusColors.textMuted))
                else
                  for (final poll in current)
                    _PollCard(poll: poll, onChanged: _reload),
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('過去の投票', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final poll in past) _PollCard(poll: poll, onChanged: _reload),
                ],
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
                  _WantTile(want: want, busy: cloud.busy, onChanged: _reload),
              ],
            ),
    );
  }
}

class _CreatePollDialog extends StatefulWidget {
  const _CreatePollDialog();

  @override
  State<_CreatePollDialog> createState() => _CreatePollDialogState();
}

class _CreatePollDialogState extends State<_CreatePollDialog> {
  final _title = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  late DateTime _deadline;

  @override
  void initState() {
    super.initState();
    _deadline = dateOnly(DateTime.now()).add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _title.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('日程投票'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _title, decoration: const InputDecoration(labelText: '何の予定？')),
              for (var i = 0; i < _options.length; i++)
                TextField(
                  controller: _options[i],
                  decoration: InputDecoration(labelText: '候補${i + 1}'),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _options.length >= 12
                      ? null
                      : () => setState(() => _options.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: const Text('候補を追加'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('期限'),
                subtitle: Text(jpDate(_deadline)),
                trailing: const Icon(Icons.event_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _deadline,
                    firstDate: dateOnly(DateTime.now()),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _deadline = dateOnly(picked));
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('やめる')),
        FilledButton(
          onPressed: () {
            final options = [
              for (final option in _options)
                if (option.text.trim().isNotEmpty) option.text.trim(),
            ];
            if (_title.text.trim().isEmpty || options.length < 2) {
              showNexusToast(context, 'タイトルと候補を2つ以上入れてください');
              return;
            }
            Navigator.pop(context, (title: _title.text.trim(), options: options, deadline: _deadline));
          },
          child: const Text('作る'),
        ),
      ],
    );
  }
}

class _PollCard extends StatefulWidget {
  const _PollCard({required this.poll, required this.onChanged});

  final CirclePoll poll;
  final Future<void> Function() onChanged;

  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    final poll = widget.poll;
    final open = poll.stage() == PollStage.voting;
    final label = poll.remainingLabel();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(poll.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  if (label.isNotEmpty)
                    Text(
                      label,
                      style: TextStyle(
                        color: open ? NexusColors.gold : NexusColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              for (var i = 0; i < poll.options.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(poll.options[i]),
                  subtitle: Text('${poll.counts[i]}票'),
                  trailing: open
                      ? FilledButton.tonal(
                          onPressed: cloud.busy
                              ? null
                              : () async {
                                  try {
                                    await cloud.votePoll(poll.id, i);
                                    await widget.onChanged();
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    showNexusToast(context, cloudErrorMessage(error));
                                  }
                                },
                          child: const Text('投票'),
                        )
                      : null,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WantTile extends StatelessWidget {
  const _WantTile({required this.want, required this.busy, required this.onChanged});

  final CircleWant want;
  final bool busy;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    final me = cloud.uid;
    final mine = want.answers[me];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Column(
            children: [
              Text(want.scoreLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  _ChoiceChip(
                    label: 'Yes',
                    selected: mine == true,
                    onTap: busy
                        ? null
                        : () async {
                            try {
                              await cloud.answerWant(want.id, yes: true);
                              await onChanged();
                            } catch (error) {
                              if (!context.mounted) return;
                              showNexusToast(context, cloudErrorMessage(error));
                            }
                          },
                  ),
                  const SizedBox(width: 4),
                  _ChoiceChip(
                    label: 'No',
                    selected: mine == false,
                    onTap: busy
                        ? null
                        : () async {
                            try {
                              await cloud.answerWant(want.id, yes: false);
                              await onChanged();
                            } catch (error) {
                              if (!context.mounted) return;
                              showNexusToast(context, cloudErrorMessage(error));
                            }
                          },
                  ),
                ],
              ),
            ],
          ),
          Checkbox(
            value: want.done,
            onChanged: busy
                ? null
                : (_) async {
                    try {
                      await cloud.toggleWant(want.id);
                      await onChanged();
                    } catch (error) {
                      if (!context.mounted) return;
                      showNexusToast(context, cloudErrorMessage(error));
                    }
                  },
          ),
          Expanded(
            child: Text(
              want.title,
              style: TextStyle(decoration: want.done ? TextDecoration.lineThrough : null),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? NexusColors.cyan.withValues(alpha: 0.22) : NexusColors.surface,
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
