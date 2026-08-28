import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/format.dart';
import '../data/models.dart';
import '../data/app_store.dart';
import 'duration_picker.dart';
import 'ui_bits.dart';

class ScheduleEditSheet extends StatefulWidget {
  const ScheduleEditSheet({super.key, this.initial});

  final ScheduleItem? initial;

  @override
  State<ScheduleEditSheet> createState() => _ScheduleEditSheetState();
}

class _ScheduleEditSheetState extends State<ScheduleEditSheet> {
  late final TextEditingController _title;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    _title = TextEditingController(text: item?.title ?? '');
    final start = item?.startAt;
    _time = start != null
        ? TimeOfDay(hour: start.hour, minute: start.minute)
        : const TimeOfDay(hour: 18, minute: 0);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
          ClockTimePicker(
            time: _time,
            onChanged: (next) => setState(() => _time = next),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(context, (title, _time));
          },
          child: Text('保存'),
        ),
        if (widget.initial != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: Text('削除', style: TextStyle(color: NexusColors.expense)),
          ),
        ],
      ],
    );
  }
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

Future<void> openScheduleEditor(
  BuildContext context, {
  ScheduleItem? item,
  DateTime? day,
}) async {
  final store = AppScope.of(context);
  final result = await showNexusSheet<Object>(
    context: context,
    builder: (_) => ScheduleEditSheet(initial: item),
  );
  if (result == 'delete' && item != null) {
    store.deleteSchedule(item.id);
    return;
  }
  if (result is (String, TimeOfDay)) {
    final base = item != null
        ? dateOnly(item.startAt)
        : dateOnly(day ?? store.focusedDate);
    final start = DateTime(
      base.year,
      base.month,
      base.day,
      result.$2.hour,
      result.$2.minute,
    );
    if (item == null) {
      store.addSchedule(title: result.$1, startAt: start);
    } else {
      store.updateSchedule(item.copyWith(title: result.$1, startAt: start));
    }
  }
}
