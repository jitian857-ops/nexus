import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../cloud/friend_models.dart';
import '../core/format.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import '../voice/voice_intent.dart';
import 'ui_bits.dart';

Future<VoiceIntent?> confirmVoiceIntent({
  required BuildContext context,
  required VoiceIntent intent,
  required AppStore store,
}) {
  if (!intent.needsConfirm) return Future.value(intent);
  return showNexusSheet<VoiceIntent>(
    context: context,
    builder: (_) => VoiceConfirmSheet(intent: intent, store: store),
  );
}

class VoiceConfirmSheet extends StatefulWidget {
  const VoiceConfirmSheet({super.key, required this.intent, required this.store});

  final VoiceIntent intent;
  final AppStore store;

  @override
  State<VoiceConfirmSheet> createState() => _VoiceConfirmSheetState();
}

class _VoiceConfirmSheetState extends State<VoiceConfirmSheet> {
  late VoiceIntent _intent;
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _body;

  @override
  void initState() {
    super.initState();
    _intent = widget.intent;
    _title = TextEditingController(text: _initialTitle);
    _amount = TextEditingController(text: _initialAmount);
    _body = TextEditingController(text: _intent is SetDiaryIntent ? (_intent as SetDiaryIntent).text : '');
  }

  String get _initialTitle {
    return switch (_intent) {
      CreateScheduleIntent(:final title) => title,
      CreateSpendIntent(:final title) => title,
      CreateIncomeIntent(:final name) => name,
      CreateAssignmentIntent(:final title) => title,
      CreateExamIntent(:final title) => title,
      _ => '',
    };
  }

  String get _initialAmount {
    return switch (_intent) {
      CreateSpendIntent(:final amount) => '$amount',
      CreateIncomeIntent(:final amount) => '$amount',
      StartTimerIntent(:final minutes) => minutes > 0 ? '$minutes' : '',
      _ => '',
    };
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('内容を確認', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('保存する前に直してください', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        ..._fields(),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _canSave ? () => Navigator.pop(context, _intent) : null,
          child: Text(_primaryLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
      ],
    );
  }

  bool get _canSave {
    final intent = _intent;
    return switch (intent) {
      ToggleHabitIntent(:final alreadyDone, :final habitId) => !alreadyDone && habitId != null && habitId.isNotEmpty,
      CreateSpendIntent() => _canSaveSpend(intent),
      CreateIncomeIntent(:final amount, :final name) => amount > 0 && name.trim().isNotEmpty,
      CreateScheduleIntent(:final title) => title.trim().isNotEmpty,
      StartTimerIntent() => widget.store.visibleSubjects.isNotEmpty,
      ShareItemIntent(:final viewerId, :final viewerName) => viewerId.isNotEmpty && viewerName.trim().isNotEmpty,
      CreateAssignmentIntent(:final title) => title.trim().isNotEmpty && widget.store.visibleSubjects.isNotEmpty,
      CreateExamIntent(:final title) => title.trim().isNotEmpty,
      SetDiaryIntent(:final text) => text.trim().isNotEmpty,
      CheckInIntent() => true,
      FinishTimerIntent() => true,
      _ => true,
    };
  }

  bool _canSaveSpend(CreateSpendIntent intent) {
    final id = intent.boxId ?? (widget.store.visibleBoxes.length == 1 ? widget.store.visibleBoxes.first.id : null);
    if (intent.amount <= 0 || id == null) return false;
    final box = widget.store.boxById(id);
    if (box?.isSavings == true && intent.kind == null) return false;
    return true;
  }

  String get _primaryLabel {
    if (_intent is ShareItemIntent) return '共有する';
    if (_intent is StartTimerIntent) return '開始する';
    return '保存する';
  }

  List<Widget> _fields() {
    final intent = _intent;
    return switch (intent) {
      CreateScheduleIntent() => _scheduleFields(intent),
      CreateSpendIntent() => _spendFields(intent),
      CreateIncomeIntent() => _incomeFields(intent),
      StartTimerIntent() => _timerFields(intent),
      ToggleHabitIntent() => [
          Text('習慣: ${intent.habitName}'),
          if (intent.alreadyDone)
            Text('すでに記録されています。音声では取り消しません。', style: TextStyle(color: NexusColors.expense)),
        ],
      CheckInIntent() => [
          Text('気分 ${intent.mood == 0 ? '（未指定）' : intent.mood} / エネルギー ${intent.energy == 0 ? '（未指定）' : intent.energy}'),
          if (intent.tags.isNotEmpty) Text('タグ: ${intent.tags.join('、')}'),
          if (intent.diary.isNotEmpty) Text('ひとこと: ${intent.diary}'),
        ],
      SetDiaryIntent() => [
          TextField(
            controller: _body,
            minLines: 2,
            maxLines: 4,
            onChanged: (value) => setState(() => _intent = SetDiaryIntent(text: value)),
            decoration: const InputDecoration(labelText: '日記'),
          ),
        ],
      ShareItemIntent() => [
          Text(intent.kind == SharedKind.diary ? '日記を共有' : '予定を共有'),
          const SizedBox(height: 6),
          Text(
            intent.viewerId.isEmpty
                ? '相手「${intent.viewerName}」は表示名と完全一致しません。共有しません。'
                : '相手: ${intent.viewerName}',
            style: TextStyle(color: intent.viewerId.isEmpty ? NexusColors.expense : NexusColors.text),
          ),
          if (intent.title.isNotEmpty) Text('内容: ${intent.title}'),
          const SizedBox(height: 8),
          Text('共有は相手が閲覧できるだけです。', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
        ],
      CreateAssignmentIntent() => _assignmentFields(intent),
      CreateExamIntent() => [
          _titleField((value) {
            _intent = CreateExamIntent(title: value, examAt: intent.examAt);
          }),
          const SizedBox(height: 8),
          Text('日付  ${jpDate(intent.examAt)}'),
        ],
      FinishTimerIntent() => [const Text('計測を終了して記録します')],
      _ => [Text('$intent')],
    };
  }

  List<Widget> _scheduleFields(CreateScheduleIntent intent) {
    return [
      _titleField((value) {
        _intent = CreateScheduleIntent(
          title: value,
          startAt: intent.startAt,
          endAt: intent.endAt,
          allDay: intent.allDay,
          note: intent.note,
        );
      }),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('終日'),
        value: intent.allDay,
        onChanged: (value) {
          setState(() {
            _intent = CreateScheduleIntent(
              title: intent.title,
              startAt: value ? dateOnly(intent.startAt) : intent.startAt,
              endAt: intent.endAt,
              allDay: value,
              note: intent.note,
            );
          });
        },
      ),
      OutlinedButton(
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: dateOnly(intent.startAt),
            firstDate: DateTime(intent.startAt.year - 1),
            lastDate: DateTime(intent.startAt.year + 2),
          );
          if (picked == null) return;
          setState(() {
            _intent = CreateScheduleIntent(
              title: intent.title,
              startAt: DateTime(picked.year, picked.month, picked.day, intent.startAt.hour, intent.startAt.minute),
              endAt: intent.endAt,
              allDay: intent.allDay,
              note: intent.note,
            );
          });
        },
        child: Text(scheduleRangeLabel(start: intent.startAt, end: intent.endAt, allDay: intent.allDay)),
      ),
    ];
  }

  List<Widget> _spendFields(CreateSpendIntent intent) {
    final boxes = widget.store.visibleBoxes;
    final selected = intent.boxId ?? (boxes.length == 1 ? boxes.first.id : null);
    final box = selected == null ? null : widget.store.boxById(selected);
    return [
      if (boxes.isEmpty)
        Text('先にボックスを作ってください', style: TextStyle(color: NexusColors.expense))
      else
        DropdownButton<String>(
          value: selected != null && boxes.any((b) => b.id == selected) ? selected : null,
          hint: const Text('ボックス'),
          dropdownColor: NexusColors.card,
          isExpanded: true,
          items: [
            for (final box in boxes)
              DropdownMenuItem(value: box.id, child: Text('${box.name}${box.isSavings ? '（貯蓄）' : ''}')),
          ],
          onChanged: (value) {
            setState(() {
              _intent = CreateSpendIntent(
                amount: intent.amount,
                at: intent.at,
                boxId: value,
                boxQuery: intent.boxQuery,
                title: intent.title,
                memo: intent.memo,
                kind: widget.store.boxById(value ?? '')?.isSavings == true ? intent.kind : MoneyCardKind.spend,
              );
            });
          },
        ),
      TextField(
        keyboardType: TextInputType.number,
        controller: _amount,
        onChanged: (value) {
          setState(() {
            _intent = CreateSpendIntent(
              amount: int.tryParse(value.replaceAll(',', '')) ?? 0,
              at: intent.at,
              boxId: intent.boxId,
              boxQuery: intent.boxQuery,
              title: intent.title,
              memo: intent.memo,
              kind: intent.kind,
            );
          });
        },
        decoration: const InputDecoration(labelText: '金額'),
      ),
      _titleField((value) {
        _intent = CreateSpendIntent(
          amount: intent.amount,
          at: intent.at,
          boxId: intent.boxId,
          boxQuery: intent.boxQuery,
          title: value,
          memo: intent.memo,
          kind: intent.kind,
        );
      }),
      if (box?.isSavings == true) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('預ける'),
              selected: intent.kind == MoneyCardKind.saveIn,
              onSelected: (_) => setState(() {
                _intent = CreateSpendIntent(
                  amount: intent.amount,
                  at: intent.at,
                  boxId: intent.boxId,
                  boxQuery: intent.boxQuery,
                  title: intent.title,
                  memo: intent.memo,
                  kind: MoneyCardKind.saveIn,
                );
              }),
            ),
            ChoiceChip(
              label: const Text('貯蓄から出す'),
              selected: intent.kind == MoneyCardKind.saveOut,
              onSelected: (_) => setState(() {
                _intent = CreateSpendIntent(
                  amount: intent.amount,
                  at: intent.at,
                  boxId: intent.boxId,
                  boxQuery: intent.boxQuery,
                  title: intent.title,
                  memo: intent.memo,
                  kind: MoneyCardKind.saveOut,
                );
              }),
            ),
            ChoiceChip(
              label: const Text('残高から出す'),
              selected: intent.kind == MoneyCardKind.spend,
              onSelected: (_) => setState(() {
                _intent = CreateSpendIntent(
                  amount: intent.amount,
                  at: intent.at,
                  boxId: intent.boxId,
                  boxQuery: intent.boxQuery,
                  title: intent.title,
                  memo: intent.memo,
                  kind: MoneyCardKind.spend,
                );
              }),
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _incomeFields(CreateIncomeIntent intent) {
    return [
      _titleField((value) {
        _intent = CreateIncomeIntent(name: value, amount: intent.amount, depositedAt: intent.depositedAt);
      }, label: '収入名'),
      TextField(
        keyboardType: TextInputType.number,
        controller: _amount,
        onChanged: (value) {
          setState(() {
            _intent = CreateIncomeIntent(
              name: intent.name,
              amount: int.tryParse(value.replaceAll(',', '')) ?? 0,
              depositedAt: intent.depositedAt,
            );
          });
        },
        decoration: const InputDecoration(labelText: '金額'),
      ),
    ];
  }

  List<Widget> _timerFields(StartTimerIntent intent) {
    final subjects = widget.store.visibleSubjects;
    if (subjects.isEmpty) {
      return [Text('先に教科を追加してください', style: TextStyle(color: NexusColors.expense))];
    }
    final selected = intent.subjectId ?? widget.store.selectedTimerSubjectId ?? subjects.first.id;
    return [
      TextField(
        keyboardType: TextInputType.number,
        controller: _amount,
        onChanged: (value) {
          setState(() {
            _intent = StartTimerIntent(
              minutes: int.tryParse(value) ?? 0,
              subjectId: intent.subjectId,
              subjectQuery: intent.subjectQuery,
            );
          });
        },
        decoration: const InputDecoration(labelText: '分数'),
      ),
      DropdownButton<String>(
        value: subjects.any((s) => s.id == selected) ? selected : subjects.first.id,
        dropdownColor: NexusColors.card,
        isExpanded: true,
        items: [
          for (final subject in subjects) DropdownMenuItem(value: subject.id, child: Text(subject.name)),
        ],
        onChanged: (value) {
          setState(() {
            _intent = StartTimerIntent(
              minutes: intent.minutes,
              subjectId: value,
              subjectQuery: intent.subjectQuery,
            );
          });
        },
      ),
    ];
  }

  List<Widget> _assignmentFields(CreateAssignmentIntent intent) {
    final subjects = widget.store.visibleSubjects;
    final selected = intent.subjectId ?? (subjects.isEmpty ? null : subjects.first.id);
    return [
      _titleField((value) {
        _intent = CreateAssignmentIntent(
          title: value,
          dueAt: intent.dueAt,
          subjectId: intent.subjectId,
          subjectQuery: intent.subjectQuery,
        );
      }),
      if (subjects.isNotEmpty)
        DropdownButton<String>(
          value: selected,
          dropdownColor: NexusColors.card,
          isExpanded: true,
          items: [
            for (final subject in subjects) DropdownMenuItem(value: subject.id, child: Text(subject.name)),
          ],
          onChanged: (value) {
            setState(() {
              _intent = CreateAssignmentIntent(
                title: intent.title,
                dueAt: intent.dueAt,
                subjectId: value,
                subjectQuery: intent.subjectQuery,
              );
            });
          },
        ),
      Text('期限  ${jpDate(intent.dueAt)}'),
    ];
  }

  Widget _titleField(ValueChanged<String> onChanged, {String label = 'タイトル'}) {
    return TextField(
      controller: _title,
      onChanged: (value) => setState(() => onChanged(value)),
      decoration: InputDecoration(labelText: label),
    );
  }
}

Future<bool> confirmShareVoice({
  required BuildContext context,
  required ShareItemIntent intent,
}) async {
  final ok = await showNexusSheet<bool>(
    context: context,
    builder: (sheet) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('共有してよいですか？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            intent.kind == SharedKind.diary
                ? '${intent.viewerName}に今日の日記を共有します。相手は閲覧だけできます。'
                : '${intent.viewerName}に「${intent.title.isEmpty ? '予定' : intent.title}」を共有します。相手は閲覧だけできます。',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(sheet, true),
            child: const Text('共有する'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(sheet, false),
            child: const Text('やめる'),
          ),
        ],
      );
    },
  );
  return ok == true;
}
