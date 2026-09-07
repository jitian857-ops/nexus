import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../cloud/friend_models.dart';
import '../cloud/nexus_cloud.dart';
import '../core/format.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import '../screens/friends/share_picker.dart';
import 'datetime_pills.dart';
import 'ui_bits.dart';

class ScheduleEditSheet extends StatefulWidget {
  const ScheduleEditSheet({super.key, this.initial, this.day});

  final ScheduleItem? initial;
  final DateTime? day;

  @override
  State<ScheduleEditSheet> createState() => _ScheduleEditSheetState();
}

class _ScheduleEditSheetState extends State<ScheduleEditSheet> {
  late final TextEditingController _title;
  late DateTime _startDay;
  late DateTime _endDay;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  var _allDay = false;
  var _tags = <String>[];
  var _shareWith = <String>[];
  var _shareLoaded = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    final fallback = dateOnly(widget.day ?? DateTime.now());
    _title = TextEditingController(text: item?.title ?? '');
    _startDay = item != null ? dateOnly(item.startAt) : fallback;
    _endDay = item != null ? dateOnly(item.endAt ?? item.startAt) : fallback;
    _startTime = item != null
        ? TimeOfDay(hour: item.startAt.hour, minute: item.startAt.minute)
        : const TimeOfDay(hour: 18, minute: 0);
    final end = item?.endAt;
    _endTime = end != null
        ? TimeOfDay(hour: end.hour, minute: end.minute)
        : TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);
    _allDay = item?.allDay ?? false;
    _tags = [...(item?.tags ?? const [])];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shareLoaded) return;
    _shareLoaded = true;
    final item = widget.initial;
    final cloud = CloudScope.maybeOf(context);
    if (item == null || cloud == null) return;
    cloud.findMyShare(SharedKind.schedule, item.id).then((existing) {
      if (!mounted || existing == null) return;
      setState(() => _shareWith = [...existing.viewerIds]);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime day, TimeOfDay time) {
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  void _ensureOrder() {
    if (_endDay.isBefore(_startDay)) _endDay = _startDay;
    if (_allDay) return;
    final start = _combine(_startDay, _startTime);
    var end = _combine(_endDay, _endTime);
    if (!end.isBefore(start)) return;
    end = start.add(const Duration(hours: 1));
    _endDay = dateOnly(end);
    _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
  }

  Future<void> _pickDay({required bool end}) async {
    final current = end ? _endDay : _startDay;
    final picked = await showDateReelSheet(context, initial: current);
    if (picked == null || !mounted) return;
    setState(() {
      if (end) {
        _endDay = dateOnly(picked);
      } else {
        _startDay = dateOnly(picked);
      }
      _ensureOrder();
    });
  }

  Future<void> _pickTime({required bool end}) async {
    final current = end ? _endTime : _startTime;
    final picked = await showTimeReelSheet(context, initial: current);
    if (picked == null || !mounted) return;
    setState(() {
      if (end) {
        _endTime = picked;
      } else {
        _startTime = picked;
      }
      _ensureOrder();
    });
  }

  Future<void> _pickShare() async {
    final picked = await pickShareViewers(context, selected: _shareWith);
    if (!mounted || picked == null) return;
    setState(() => _shareWith = picked);
  }

  Future<void> _addCustomTag() async {
    final text = await _promptScheduleTag(context);
    if (text == null || !mounted || _tags.contains(text)) return;
    setState(() => _tags = [..._tags, text]);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial == null ? '予定を追加' : '予定を編集',
            style: TextStyle(
              color: NexusColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            style: TextStyle(color: NexusColors.text),
            decoration: _input('タイトル'),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('終日', style: TextStyle(color: NexusColors.text, fontWeight: FontWeight.w600)),
            value: _allDay,
            onChanged: (v) => setState(() => _allDay = v),
          ),
          CompactDateTimeRow(
            label: '開始',
            day: _startDay,
            time: _allDay ? null : _startTime,
            onPickDate: () => _pickDay(end: false),
            onPickTime: _allDay ? null : () => _pickTime(end: false),
          ),
          const SizedBox(height: 8),
          CompactDateTimeRow(
            label: '終了',
            day: _endDay,
            time: _allDay ? null : _endTime,
            onPickDate: () => _pickDay(end: true),
            onPickTime: _allDay ? null : () => _pickTime(end: true),
          ),
          const SizedBox(height: 8),
          Text('タグ', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in kScheduleTagPresets)
                FilterChip(
                  label: Text(preset),
                  selected: _tags.contains(preset),
                  onSelected: (on) {
                    setState(() {
                      if (on) {
                        _tags = [..._tags, preset];
                      } else {
                        _tags = [..._tags]..remove(preset);
                      }
                    });
                  },
                ),
              for (final tag in _tags)
                if (!kScheduleTagPresets.contains(tag))
                  InputChip(
                    label: Text(tag),
                    onDeleted: () => setState(() => _tags = [..._tags]..remove(tag)),
                  ),
              ActionChip(
                avatar: Icon(Icons.add_rounded, size: 16, color: NexusColors.cyan),
                label: Text('タグを追加', style: TextStyle(color: NexusColors.cyan, fontWeight: FontWeight.w700)),
                onPressed: _addCustomTag,
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickShare,
            icon: const Icon(Icons.group_outlined, size: 18),
            label: Text(
              _shareWith.isEmpty ? 'フレンドに共有' : '${_shareWith.length}人に共有',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '選ばなければ自分のみ。共有先は閲覧だけで、編集はできません。',
            style: TextStyle(color: NexusColors.textMuted, fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              final title = _title.text.trim();
              if (title.isEmpty) return;
              var start = _allDay ? _startDay : _combine(_startDay, _startTime);
              var end = _allDay
                  ? DateTime(_endDay.year, _endDay.month, _endDay.day, 23, 59)
                  : _combine(_endDay, _endTime);
              if (end.isBefore(start)) {
                end = start.add(const Duration(hours: 1));
              }
              Navigator.pop(
                context,
                _ScheduleSave(
                  title: title,
                  startAt: start,
                  endAt: end,
                  allDay: _allDay,
                  tags: _tags,
                  shareWith: _shareWith,
                ),
              );
            },
            child: const Text('保存'),
          ),
          if (widget.initial != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, 'delete'),
              child: Text('削除', style: TextStyle(color: NexusColors.expense)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleSave {
  const _ScheduleSave({
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    required this.tags,
    required this.shareWith,
  });

  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final List<String> tags;
  final List<String> shareWith;
}

Future<String?> _promptScheduleTag(BuildContext context) async {
  final name = TextEditingController();
  final saved = await showNexusSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('タグを追加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: name,
            autofocus: true,
            style: TextStyle(color: NexusColors.text),
            decoration: _input('タグ名'),
            onSubmitted: (_) => Navigator.pop(sheet, true),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(sheet, true), child: const Text('追加')),
        ],
      );
    },
  );
  final text = name.text.trim();
  name.dispose();
  if (saved == true && text.isNotEmpty) return text;
  return null;
}

InputDecoration _input(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: NexusColors.textMuted),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: NexusColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: NexusColors.cyan),
      borderRadius: BorderRadius.circular(12),
    ),
  );
}

Map<String, dynamic> scheduleSharePayload(ScheduleItem saved) {
  return {
    'title': saved.title,
    'start_at': saved.startAt.toIso8601String(),
    'end_at': saved.endAt?.toIso8601String(),
    'all_day': saved.allDay,
    'note': saved.tags.join('、'),
    'tags': saved.tags,
  };
}

Future<void> openScheduleEditor(
  BuildContext context, {
  ScheduleItem? item,
  DateTime? day,
}) async {
  final store = AppScope.of(context);
  final cloud = CloudScope.of(context);
  final result = await showNexusSheet<Object>(
    context: context,
    builder: (_) => ScheduleEditSheet(initial: item, day: day),
  );
  if (result == 'delete' && item != null) {
    store.deleteSchedule(item.id);
    try {
      await cloud.revokeShareBySource(SharedKind.schedule, item.id);
    } catch (_) {}
    return;
  }
  if (result is _ScheduleSave) {
    late final ScheduleItem saved;
    if (item == null) {
      store.addSchedule(
        title: result.title,
        startAt: result.startAt,
        endAt: result.endAt,
        allDay: result.allDay,
        tags: result.tags,
      );
      saved = store.schedules.last;
    } else {
      saved = item.copyWith(
        title: result.title,
        startAt: result.startAt,
        endAt: result.endAt,
        allDay: result.allDay,
        tags: result.tags,
      );
      store.updateSchedule(saved);
    }
    try {
      if (result.shareWith.isEmpty) {
        await cloud.revokeShareBySource(SharedKind.schedule, saved.id);
      } else {
        await cloud.shareItem(
          type: SharedKind.schedule,
          sourceLocalId: saved.id,
          payload: scheduleSharePayload(saved),
          viewerIds: result.shareWith,
        );
      }
    } catch (_) {}
  }
}
