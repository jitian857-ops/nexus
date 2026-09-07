import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../cloud/friend_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../widgets/datetime_pills.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/schedule_sheet.dart';
import '../../widgets/ui_bits.dart';
import '../friends/share_picker.dart';

Future<void> openBulkScheduleShare(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const ScheduleBulkSharePage(),
    ),
  );
}

class ScheduleBulkSharePage extends StatefulWidget {
  const ScheduleBulkSharePage({super.key});

  @override
  State<ScheduleBulkSharePage> createState() => _ScheduleBulkSharePageState();
}

class _ScheduleBulkSharePageState extends State<ScheduleBulkSharePage> {
  final _query = TextEditingController();
  String? _tag;
  DateTime? _from;
  DateTime? _to;
  final _selected = <String>{};
  var _sharing = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<ScheduleItem> _filtered(AppStore store) {
    final q = _query.text;
    final items = [
      for (final item in store.schedules)
        if (item.matchesFilters(query: q, tag: _tag, from: _from, to: _to)) item,
    ]..sort((a, b) => b.startAt.compareTo(a.startAt));
    return items;
  }

  Set<String> _availableTags(AppStore store) {
    return {
      for (final item in store.schedules) ...item.tags,
    };
  }

  Future<void> _pickBound({required bool end}) async {
    final current = end ? (_to ?? _from ?? DateTime.now()) : (_from ?? _to ?? DateTime.now());
    final picked = await showDateReelSheet(context, initial: current);
    if (picked == null || !mounted) return;
    setState(() {
      if (end) {
        _to = dateOnly(picked);
        if (_from != null && _to!.isBefore(_from!)) _from = _to;
      } else {
        _from = dateOnly(picked);
        if (_to != null && _to!.isBefore(_from!)) _to = _from;
      }
    });
  }

  Future<void> _confirm(List<ScheduleItem> visible) async {
    final chosen = [for (final item in visible) if (_selected.contains(item.id)) item];
    if (chosen.isEmpty) {
      showNexusToast(context, '共有する予定を選んでください');
      return;
    }
    final viewers = await pickShareViewers(context, requireSelection: true);
    if (!mounted || viewers == null || viewers.isEmpty) return;
    setState(() => _sharing = true);
    final cloud = CloudScope.of(context);
    var ok = 0;
    for (final item in chosen) {
      try {
        await cloud.shareItem(
          type: SharedKind.schedule,
          sourceLocalId: item.id,
          payload: scheduleSharePayload(item),
          viewerIds: viewers,
        );
        ok++;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _sharing = false);
    showNexusToast(context, '$ok件の予定を共有しました');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final tags = _availableTags(store).toList()..sort();
    final visible = _filtered(store);
    final selectedCount = visible.where((item) => _selected.contains(item.id)).length;

    return Scaffold(
      backgroundColor: NexusColors.background,
      body: PageScaffold(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _sharing ? null : () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: NexusColors.text),
                  ),
                  const Expanded(
                    child: Text('予定を一括共有', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _query,
                          onChanged: (_) => setState(() {}),
                          style: TextStyle(color: NexusColors.text),
                          decoration: InputDecoration(
                            hintText: '予定を検索',
                            hintStyle: TextStyle(color: NexusColors.textMuted),
                            prefixIcon: Icon(Icons.search_rounded, color: NexusColors.textMuted),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: NexusColors.border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: NexusColors.cyan),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('タグ', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('すべて'),
                              selected: _tag == null,
                              onSelected: (_) => setState(() => _tag = null),
                            ),
                            for (final tag in tags)
                              FilterChip(
                                label: Text(tag),
                                selected: _tag == tag,
                                onSelected: (on) => setState(() => _tag = on ? tag : null),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('期間', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            CompactGrayPill(
                              label: _from == null ? '開始日' : jpDateWeekday(_from!),
                              muted: _from == null,
                              onTap: () => _pickBound(end: false),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text('〜', style: TextStyle(color: NexusColors.textMuted)),
                            ),
                            CompactGrayPill(
                              label: _to == null ? '終了日' : jpDateWeekday(_to!),
                              muted: _to == null,
                              onTap: () => _pickBound(end: true),
                            ),
                          ],
                        ),
                        if (_from != null || _to != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => setState(() {
                                _from = null;
                                _to = null;
                              }),
                              child: const Text('期間をクリア'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (store.schedules.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('共有できる予定はありません', style: TextStyle(color: NexusColors.textMuted)),
                      ),
                    )
                  else if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('条件に合う予定はありません', style: TextStyle(color: NexusColors.textMuted)),
                      ),
                    )
                  else
                    GlassCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < visible.length; i++) ...[
                            if (i > 0) const SizedBox(height: 4),
                            CheckboxListTile(
                              value: _selected.contains(visible[i].id),
                              contentPadding: EdgeInsets.zero,
                              title: Text(visible[i].title),
                              subtitle: Text(
                                [
                                  visible[i].whenLabel(),
                                  if (visible[i].tags.isNotEmpty) visible[i].tags.join(' · '),
                                ].join('  '),
                                style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                              ),
                              onChanged: _sharing
                                  ? null
                                  : (on) {
                                      setState(() {
                                        if (on == true) {
                                          _selected.add(visible[i].id);
                                        } else {
                                          _selected.remove(visible[i].id);
                                        }
                                      });
                                    },
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _sharing ? null : () => _confirm(visible),
                    child: Text(
                      _sharing
                          ? '共有しています...'
                          : (selectedCount == 0 ? '決定' : '$selectedCount件を決定'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
