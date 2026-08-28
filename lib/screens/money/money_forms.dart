import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../widgets/ui_bits.dart';

Future<void> openAddIncome(BuildContext context, AppStore store) {
  return openIncomeForm(context, store);
}

Future<void> openIncomeForm(BuildContext context, AppStore store, {IncomeEntry? existing}) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final amount = TextEditingController(text: existing == null ? '' : '${existing.amount}');
  final memo = TextEditingController(text: existing?.memo ?? '');
  var deposited = existing?.depositedAt ?? store.moneyEntryDate;
  var useYear = existing?.useYear ?? nextUseMonth(deposited).year;
  var useMonth = existing?.useMonth ?? nextUseMonth(deposited).month;
  final saved = await showNexusSheet<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing == null ? '収入を追加' : '収入を編集', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                TextField(
                  controller: name,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '収入名'),
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '金額'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: deposited,
                      firstDate: DateTime(deposited.year - 1),
                      lastDate: DateTime(deposited.year + 2),
                    );
                    if (picked != null) {
                      setSheet(() {
                        deposited = picked;
                        if (existing == null) {
                          final next = nextUseMonth(picked);
                          useYear = next.year;
                          useMonth = next.month;
                        }
                      });
                    }
                  },
                  child: Text('入金日  ${jpDate(deposited)}'),
                ),
                const SizedBox(height: 8),
                Text('何月分として使うか', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        value: useYear,
                        dropdownColor: NexusColors.card,
                        isExpanded: true,
                        items: [
                          for (var y = deposited.year - 1; y <= deposited.year + 1; y++)
                            DropdownMenuItem(value: y, child: Text('$y年')),
                          if (useYear < deposited.year - 1 || useYear > deposited.year + 1)
                            DropdownMenuItem(value: useYear, child: Text('$useYear年')),
                        ],
                        onChanged: (v) => setSheet(() => useYear = v ?? useYear),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<int>(
                        value: useMonth,
                        dropdownColor: NexusColors.card,
                        isExpanded: true,
                        items: [
                          for (var m = 1; m <= 12; m++)
                            DropdownMenuItem(value: m, child: Text('$m月')),
                        ],
                        onChanged: (v) => setSheet(() => useMonth = v ?? useMonth),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: memo,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: 'メモ（任意）'),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
              ],
            ),
          );
        },
      );
    },
  );
  final value = int.tryParse(amount.text.replaceAll(',', ''));
  if (saved == true && name.text.trim().isNotEmpty && value != null && value > 0) {
    if (existing == null) {
      store.addIncome(
        name: name.text.trim(),
        amount: value,
        depositedAt: deposited,
        useYear: useYear,
        useMonth: useMonth,
        memo: memo.text.trim(),
      );
    } else {
      store.updateIncome(
        existing.copyWith(
          name: name.text.trim(),
          amount: value,
          depositedAt: deposited,
          useYear: useYear,
          useMonth: useMonth,
          memo: memo.text.trim(),
        ),
      );
    }
    if (context.mounted) {
      nexusHaptic();
      showNexusToast(context, store.lastToast);
    }
  }
  name.dispose();
  amount.dispose();
  memo.dispose();
}

Future<void> openAddBox(BuildContext context, AppStore store) async {
  final kind = await showNexusSheet<BoxKind>(
    context: context,
    builder: (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ボックスの種類', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(context, BoxKind.budget),
            child: const Text('予算ボックス'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, BoxKind.savings),
            child: Text('貯蓄ボックス'),
          ),
          const SizedBox(height: 8),
          Text(
            '予算は毎月リセット、貯蓄は残高を持ち越します。',
            style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
          ),
        ],
      );
    },
  );
  if (kind == null || !context.mounted) return;
  if (kind == BoxKind.budget) {
    await _openBudgetBoxForm(context, store);
  } else {
    await _openSavingsBoxForm(context, store);
  }
}

Future<void> openEditBox(BuildContext context, AppStore store, BudgetBox box) {
  if (box.isSavings) return _openSavingsBoxForm(context, store, existing: box);
  return _openBudgetBoxForm(context, store, existing: box);
}

Future<void> _openBudgetBoxForm(BuildContext context, AppStore store, {BudgetBox? existing}) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final budget = TextEditingController(text: existing == null ? '30000' : '${existing.monthlyBudget}');
  final memo = TextEditingController(text: existing?.memo ?? '');
  final tag = TextEditingController();
  var icon = existing?.icon ?? Icons.restaurant_rounded;
  var color = existing?.color ?? const Color(0xFF3DA9FC);
  var tags = [...(existing?.tags ?? const ['その他'])];
  final saved = await showNexusSheet<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing == null ? '予算ボックス' : '予算ボックスを編集', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: name,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: 'ボックス名'),
                ),
                TextField(
                  controller: budget,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '月間予算'),
                ),
                BoxLookPicker(
                  icon: icon,
                  color: color,
                  onIcon: (value) => setSheet(() => icon = value),
                  onColor: (value) => setSheet(() => color = value),
                ),
                Text('タグ', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final t in tags)
                      Chip(
                        label: Text(t),
                        onDeleted: t == 'その他'
                            ? null
                            : () => setSheet(() => tags = [...tags]..remove(t)),
                      ),
                    ActionChip(
                      label: const Text('＋タグを追加'),
                      onPressed: () async {
                        final text = await promptTagName(context);
                        if (text == null || tags.contains(text)) return;
                        setSheet(() => tags = [...tags, text]);
                      },
                    ),
                  ],
                ),
                TextField(
                  controller: tag,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '新しいタグ名'),
                  onSubmitted: (value) {
                    final text = value.trim();
                    if (text.isEmpty || tags.contains(text)) return;
                    setSheet(() {
                      tags = [...tags, text];
                      tag.clear();
                    });
                  },
                ),
                TextField(
                  controller: memo,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: 'メモ'),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(existing == null ? '作成' : '保存')),
              ],
          );
        },
      );
    },
  );
  final value = int.tryParse(budget.text.replaceAll(',', ''));
  if (saved == true && name.text.trim().isNotEmpty && value != null && value >= 0) {
    if (existing == null) {
      store.addBudgetBox(
        name: name.text.trim(),
        icon: icon,
        color: color,
        monthlyBudget: value,
        tags: tags,
        memo: memo.text.trim(),
      );
    } else {
      store.updateBox(
        existing.copyWith(
          name: name.text.trim(),
          icon: icon,
          color: color,
          monthlyBudget: value,
          tags: tags,
          memo: memo.text.trim(),
        ),
      );
    }
    if (context.mounted) showNexusToast(context, store.lastToast);
  }
  name.dispose();
  budget.dispose();
  memo.dispose();
  tag.dispose();
}

Future<void> _openSavingsBoxForm(BuildContext context, AppStore store, {BudgetBox? existing}) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final target = TextEditingController(text: existing == null ? '150000' : '${existing.targetAmount}');
  final current = TextEditingController(text: existing == null ? '0' : '${existing.openingAmount}');
  final memo = TextEditingController(text: existing?.memo ?? '');
  final tag = TextEditingController();
  var icon = existing?.icon ?? Icons.savings_rounded;
  var color = existing?.color ?? const Color(0xFFFFC857);
  DateTime? targetDate = existing?.targetDate;
  var tags = [...(existing?.tags ?? const ['積立', 'その他'])];
  final saved = await showNexusSheet<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                Text(existing == null ? '貯蓄ボックス' : '貯蓄ボックスを編集', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: name,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: 'ボックス名'),
                ),
                TextField(
                  controller: target,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '目標金額'),
                ),
                TextField(
                  controller: current,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '現在金額'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: store.focusedDate.add(const Duration(days: 90)),
                      firstDate: store.focusedDate,
                      lastDate: DateTime(store.focusedDate.year + 5),
                    );
                    if (picked != null) setSheet(() => targetDate = picked);
                  },
                  child: Text(targetDate == null ? '目標日（任意）' : '目標日  ${jpDate(targetDate!)}'),
                ),
                BoxLookPicker(
                  icon: icon,
                  color: color,
                  onIcon: (value) => setSheet(() => icon = value),
                  onColor: (value) => setSheet(() => color = value),
                ),
                Text('タグ', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final t in tags)
                      Chip(
                        label: Text(t),
                        onDeleted: t == 'その他'
                            ? null
                            : () => setSheet(() => tags = [...tags]..remove(t)),
                      ),
                    ActionChip(
                      label: const Text('＋タグを追加'),
                      onPressed: () async {
                        final text = await promptTagName(context);
                        if (text == null || tags.contains(text)) return;
                        setSheet(() => tags = [...tags, text]);
                      },
                    ),
                  ],
                ),
                TextField(
                  controller: tag,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '新しいタグ名'),
                  onSubmitted: (value) {
                    final text = value.trim();
                    if (text.isEmpty || tags.contains(text)) return;
                    setSheet(() {
                      tags = [...tags, text];
                      tag.clear();
                    });
                  },
                ),
                TextField(
                  controller: memo,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: 'メモ'),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(existing == null ? '作成' : '保存')),
              ],
          );
        },
      );
    },
  );
  final goal = int.tryParse(target.text.replaceAll(',', ''));
  final now = int.tryParse(current.text.replaceAll(',', '')) ?? 0;
  if (saved == true && name.text.trim().isNotEmpty && goal != null && goal > 0) {
    if (existing == null) {
      store.addSavingsBox(
        name: name.text.trim(),
        icon: icon,
        color: color,
        targetAmount: goal,
        openingAmount: now,
        targetDate: targetDate,
        tags: tags,
        memo: memo.text.trim(),
      );
    } else {
      store.updateBox(
        existing.copyWith(
          name: name.text.trim(),
          icon: icon,
          color: color,
          targetAmount: goal,
          openingAmount: now,
          targetDate: targetDate,
          tags: tags,
          memo: memo.text.trim(),
        ),
      );
    }
    if (context.mounted) showNexusToast(context, store.lastToast);
  }
  name.dispose();
  target.dispose();
  current.dispose();
  memo.dispose();
  tag.dispose();
}

Future<void> openAddCard(BuildContext context, AppStore store, {String? boxId}) async {
  final picker = store.visibleBoxes;
  if (picker.isEmpty) return;
  var selected = boxId ?? picker.first.id;
  if (!picker.any((b) => b.id == selected)) selected = picker.first.id;
  final title = TextEditingController();
  final amount = TextEditingController();
  final memo = TextEditingController();
  var at = store.moneyEntryDate;
  var tag = '';
  var saveIn = true;
  var fromBalance = false;
  final saved = await showNexusSheet<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          final box = store.boxById(selected);
          final tags = box?.tags ?? const <String>[];
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('カードを追加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                DropdownButton<String>(
                  value: selected,
                  dropdownColor: NexusColors.card,
                  isExpanded: true,
                  items: [
                    for (final b in store.visibleBoxes)
                      DropdownMenuItem(value: b.id, child: Text('${b.name}${b.isSavings ? '（貯蓄）' : ''}')),
                  ],
                  onChanged: (v) => setSheet(() {
                    selected = v ?? selected;
                    tag = '';
                  }),
                ),
                if (box?.isSavings == true) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('預ける'),
                        selected: saveIn,
                        onSelected: (_) => setSheet(() {
                          saveIn = true;
                          fromBalance = false;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('貯蓄から出す'),
                        selected: !saveIn && !fromBalance,
                        onSelected: (_) => setSheet(() {
                          saveIn = false;
                          fromBalance = false;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('残高から出す'),
                        selected: !saveIn && fromBalance,
                        onSelected: (_) => setSheet(() {
                          saveIn = false;
                          fromBalance = true;
                        }),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      saveIn
                          ? '残高が減り、貯蓄ボックスが増えます。'
                          : fromBalance
                              ? '残高だけ減ります。貯蓄の中身は変わりません。'
                              : '貯蓄ボックスの中だけ減ります。残高は変わりません。',
                      style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
                    ),
                  ),
                ],
                TextField(
                  controller: title,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '内容（任意）'),
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '金額'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: at,
                      firstDate: DateTime(at.year - 1),
                      lastDate: DateTime(at.year + 1),
                    );
                    if (picked != null) setSheet(() => at = picked);
                  },
                  child: Text('日付  ${jpDate(at)}'),
                ),
                Text('タグ', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final t in tags)
                      ChoiceChip(
                        label: Text(t),
                        selected: tag == t,
                        onSelected: (_) => setSheet(() => tag = t),
                      ),
                    ActionChip(
                      label: const Text('＋タグを追加'),
                      onPressed: () async {
                        await openAddTag(context, store, selected);
                        setSheet(() {});
                      },
                    ),
                  ],
                ),
                TextField(
                  controller: memo,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: 'メモ（任意）'),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
              ],
            ),
          );
        },
      );
    },
  );
  final value = int.tryParse(amount.text.replaceAll(',', ''));
  final box = store.boxById(selected);
  if (saved == true && value != null && value > 0 && box != null) {
    store.addMoneyCard(
      boxId: selected,
      title: title.text.trim(),
      amount: value,
      at: at,
      tag: tag,
      memo: memo.text.trim(),
      kind: box.isSavings
          ? (saveIn
              ? MoneyCardKind.saveIn
              : fromBalance
                  ? MoneyCardKind.spend
                  : MoneyCardKind.saveOut)
          : MoneyCardKind.spend,
    );
    if (context.mounted) showNexusToast(context, store.lastToast);
  }
  title.dispose();
  amount.dispose();
  memo.dispose();
}

Future<void> openEditCard(BuildContext context, AppStore store, MoneyCard card) async {
  var boxId = card.boxId;
  final title = TextEditingController(text: card.title);
  final amount = TextEditingController(text: '${card.amount}');
  final memo = TextEditingController(text: card.memo);
  var at = card.at;
  var tag = card.tag;
  var kind = card.kind;
  final saved = await showNexusSheet<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          final box = store.boxById(boxId);
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('カードを編集', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                DropdownButton<String>(
                  value: boxId,
                  dropdownColor: NexusColors.card,
                  isExpanded: true,
                  items: [
                    for (final b in [
                      ...store.visibleBoxes,
                      if (store.boxById(boxId) != null &&
                          !store.visibleBoxes.any((x) => x.id == boxId))
                        store.boxById(boxId)!,
                    ])
                      DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ],
                  onChanged: (v) => setSheet(() {
                    boxId = v ?? boxId;
                    final next = store.boxById(boxId);
                    kind = next?.isSavings == true
                        ? (kind == MoneyCardKind.spend ? MoneyCardKind.saveOut : kind)
                        : MoneyCardKind.spend;
                    tag = '';
                  }),
                ),
                TextField(
                  controller: title,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '内容（任意）'),
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '金額'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: at,
                      firstDate: DateTime(at.year - 1),
                      lastDate: DateTime(at.year + 1),
                    );
                    if (picked != null) setSheet(() => at = picked);
                  },
                  child: Text('日付  ${jpDate(at)}'),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final t in box?.tags ?? const <String>[])
                      ChoiceChip(
                        label: Text(t),
                        selected: tag == t,
                        onSelected: (_) => setSheet(() => tag = t),
                      ),
                  ],
                ),
                TextField(
                  controller: memo,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: 'メモ'),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
              ],
            ),
          );
        },
      );
    },
  );
  final value = int.tryParse(amount.text.replaceAll(',', ''));
  if (saved == true && value != null && value > 0) {
    store.updateMoneyCard(
      card.copyWith(
        boxId: boxId,
        title: title.text.trim(),
        amount: value,
        at: at,
        tag: tag,
        memo: memo.text.trim(),
        kind: kind,
      ),
    );
    if (context.mounted) showNexusToast(context, store.lastToast);
  }
  title.dispose();
  amount.dispose();
  memo.dispose();
}

Future<String?> promptTagName(BuildContext context) async {
  final name = TextEditingController();
  final saved = await showNexusSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('タグを追加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          TextField(
            controller: name,
            autofocus: true,
            style: TextStyle(color: NexusColors.text),
            decoration: const InputDecoration(labelText: 'タグ名'),
            onSubmitted: (_) => Navigator.pop(context, true),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('追加')),
        ],
      );
    },
  );
  final text = name.text.trim();
  name.dispose();
  if (saved == true && text.isNotEmpty) return text;
  return null;
}

Future<void> openAddTag(BuildContext context, AppStore store, String boxId) async {
  final text = await promptTagName(context);
  if (text != null) store.addBoxTag(boxId, text);
}

Future<void> openAddPayment(BuildContext context, AppStore store) async {
  final title = TextEditingController();
  final amount = TextEditingController();
  final memo = TextEditingController();
  var due = store.moneyEntryDate.add(const Duration(days: 10));
  final picker = store.visibleBoxes;
  String? boxId = picker.any((b) => b.id == 'box-unassigned')
      ? 'box-unassigned'
      : (picker.isEmpty ? null : picker.first.id);
  var repeat = PaymentRepeat.none;
  final saved = await showNexusSheet<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('支払予定を追加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                TextField(
                  controller: title,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '支払い名'),
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: '金額'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: due,
                      firstDate: store.focusedDate,
                      lastDate: DateTime(store.focusedDate.year + 3),
                    );
                    if (picked != null) setSheet(() => due = picked);
                  },
                  child: Text('支払予定日  ${jpDate(due)}'),
                ),
                DropdownButton<String?>(
                  value: boxId,
                  dropdownColor: NexusColors.card,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('支払い元なし')),
                    for (final b in store.visibleBoxes)
                      DropdownMenuItem(value: b.id, child: Text('支払い元：${b.name}')),
                  ],
                  onChanged: (v) => setSheet(() => boxId = v),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in PaymentRepeat.values)
                      ChoiceChip(
                        label: Text(switch (r) {
                          PaymentRepeat.none => 'なし',
                          PaymentRepeat.monthly => '毎月',
                          PaymentRepeat.yearly => '毎年',
                        }),
                        selected: repeat == r,
                        onSelected: (_) => setSheet(() => repeat = r),
                      ),
                  ],
                ),
                TextField(
                  controller: memo,
                  style: TextStyle(color: NexusColors.text),
                  decoration: const InputDecoration(labelText: 'メモ'),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
              ],
            ),
          );
        },
      );
    },
  );
  final value = int.tryParse(amount.text.replaceAll(',', ''));
  if (saved == true && title.text.trim().isNotEmpty && value != null && value > 0) {
    store.addPaymentPlan(
      title: title.text.trim(),
      amount: value,
      dueAt: due,
      boxId: boxId,
      repeat: repeat,
      memo: memo.text.trim(),
    );
    if (context.mounted) showNexusToast(context, store.lastToast);
  }
  title.dispose();
  amount.dispose();
  memo.dispose();
}
