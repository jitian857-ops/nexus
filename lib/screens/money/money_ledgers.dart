import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../widgets/datetime_pills.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_bits.dart';
import 'money_forms.dart';

Future<void> openIncomeLedger(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => const IncomeLedgerPage()),
  );
}

Future<void> openExpenseLedger(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => const ExpenseLedgerPage()),
  );
}

class IncomeLedgerPage extends StatefulWidget {
  const IncomeLedgerPage({super.key});

  @override
  State<IncomeLedgerPage> createState() => _IncomeLedgerPageState();
}

class _IncomeLedgerPageState extends State<IncomeLedgerPage> {
  final _query = TextEditingController();
  var _ready = false;
  late DateTime _from;
  late DateTime _to;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final month = AppScope.of(context).moneyMonth;
    _from = monthStart(month);
    _to = monthEnd(month);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final q = _query.text;
    final list = [
      for (final item in store.incomesInRange(_from, _to))
        if (queryMatches(q, [
          item.name,
          item.memo,
          yen(item.amount),
          '${item.amount}',
          '${item.useYear}年${item.useMonth}月',
          jpDate(item.depositedAt),
        ]))
          item,
    ];

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
                    '${dayRangeLabel(_from, _to)}の収入',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                _RangeChip(
                  onTap: () async {
                    final next = await pickSearchRange(context, from: _from, to: _to);
                    if (next == null || !mounted) return;
                    setState(() {
                      _from = next.$1;
                      _to = next.$2;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SearchField(
              controller: _query,
              hint: '名前・金額・メモで検索',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  store.incomesInRange(_from, _to).isEmpty ? 'この期間の収入はまだありません' : '一致する収入がありません',
                  style: TextStyle(color: NexusColors.textMuted),
                ),
              )
            else
              for (final item in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => openIncomeForm(context, store, existing: item),
                    borderRadius: BorderRadius.circular(16),
                    child: GlassCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  '${item.useYear}年${item.useMonth}月分 ・ 入金 ${jpDate(item.depositedAt)}',
                                  style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                                ),
                                if (item.memo.isNotEmpty)
                                  Text(item.memo, style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                            yen(item.amount),
                            style: TextStyle(fontWeight: FontWeight.w700, color: NexusColors.income),
                          ),
                          const SizedBox(width: 6),
                          _CloseMark(
                            onTap: () => _confirmDeleteIncome(context, store, item),
                          ),
                        ],
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

class ExpenseLedgerPage extends StatefulWidget {
  const ExpenseLedgerPage({super.key});

  @override
  State<ExpenseLedgerPage> createState() => _ExpenseLedgerPageState();
}

class _ExpenseLedgerPageState extends State<ExpenseLedgerPage> {
  final _query = TextEditingController();
  String? _tag;
  var _ready = false;
  late DateTime _from;
  late DateTime _to;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final month = AppScope.of(context).moneyMonth;
    _from = monthStart(month);
    _to = monthEnd(month);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final q = _query.text;
    final tags = store.expenseTagsInRange(_from, _to);
    final spend = store.spendCardsInRange(_from, _to);
    final list = [
      for (final card in spend)
        if ((_tag == null || card.tag == _tag) &&
            queryMatches(q, [
              card.title,
              card.tag,
              card.memo,
              yen(card.amount),
              '${card.amount}',
              store.boxById(card.boxId)?.name ?? '',
              jpDate(card.at),
            ]))
          card,
    ];

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
                    '${dayRangeLabel(_from, _to)}の支出',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                _RangeChip(
                  onTap: () async {
                    final next = await pickSearchRange(context, from: _from, to: _to);
                    if (next == null || !mounted) return;
                    setState(() {
                      _from = next.$1;
                      _to = next.$2;
                      _tag = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SearchField(
              controller: _query,
              hint: '内容・タグ・ボックス・金額で検索',
              onChanged: (_) => setState(() {}),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('タグ', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in tags)
                    FilterChip(
                      visualDensity: VisualDensity.compact,
                      selected: _tag == tag,
                      label: Text(tag),
                      selectedColor: NexusColors.expense.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        color: _tag == tag ? NexusColors.expense : NexusColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _tag = _tag == tag ? null : tag),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  spend.isEmpty ? 'この期間の支出カードはまだありません' : '一致する支出がありません',
                  style: TextStyle(color: NexusColors.textMuted),
                ),
              )
            else
              for (final card in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => openEditCard(context, store, card),
                    borderRadius: BorderRadius.circular(16),
                    child: GlassCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${card.at.month}/${card.at.day}  ${card.title.trim().isEmpty ? '（無題）' : card.title}',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  [
                                    if (card.tag.isNotEmpty) card.tag,
                                    store.boxById(card.boxId)?.name,
                                    jpDate(card.at),
                                  ].whereType<String>().join(' ・ '),
                                  style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                                ),
                                if (card.memo.isNotEmpty)
                                  Text(card.memo, style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                            yen(-card.amount),
                            style: TextStyle(fontWeight: FontWeight.w700, color: NexusColors.expense),
                          ),
                          const SizedBox(width: 6),
                          _CloseMark(
                            onTap: () => _confirmDeleteCard(context, store, card),
                          ),
                        ],
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

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AddChip(
      key: const Key('money-search-range'),
      label: '検索範囲',
      onTap: onTap,
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: NexusColors.text),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search_rounded, color: NexusColors.textMuted),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: Icon(Icons.close_rounded, color: NexusColors.textMuted),
              ),
      ),
    );
  }
}

class _CloseMark extends StatelessWidget {
  const _CloseMark({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: NexusColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: NexusColors.border),
          ),
          child: Icon(Icons.close, size: 13, color: NexusColors.textMuted),
        ),
      ),
    );
  }
}

Future<(DateTime, DateTime)?> pickSearchRange(
  BuildContext context, {
  required DateTime from,
  required DateTime to,
}) {
  var start = dateOnly(from);
  var end = dateOnly(to);
  return showNexusSheet<(DateTime, DateTime)>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) {
      return StatefulBuilder(
        builder: (sheet, setSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('検索範囲', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('1日単位で開始と終了を選べます', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('開始'),
                subtitle: Text(jpDate(start)),
                trailing: const Icon(Icons.event_outlined),
                onTap: () async {
                  final picked = await showDateReelSheet(sheet, initial: start);
                  if (picked == null) return;
                  setSheet(() {
                    start = dateOnly(picked);
                    if (end.isBefore(start)) end = start;
                  });
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('終了'),
                subtitle: Text(jpDate(end)),
                trailing: const Icon(Icons.event_outlined),
                onTap: () async {
                  final picked = await showDateReelSheet(sheet, initial: end);
                  if (picked == null) return;
                  setSheet(() {
                    end = dateOnly(picked);
                    if (end.isBefore(start)) start = end;
                  });
                },
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(sheet, (start, end)),
                child: const Text('この範囲で見る'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _confirmDeleteIncome(BuildContext context, AppStore store, IncomeEntry item) async {
  final ok = await _confirm(
    context,
    title: '収入を削除',
    body: '「${item.name}」を削除します。',
  );
  if (!ok || !context.mounted) return;
  store.deleteIncome(item.id);
  showNexusToast(context, store.lastToast);
}

Future<void> _confirmDeleteCard(BuildContext context, AppStore store, MoneyCard card) async {
  final label = card.title.trim().isEmpty ? 'このカード' : '「${card.title}」';
  final ok = await _confirm(
    context,
    title: 'カードを削除',
    body: '$labelを削除します。',
  );
  if (!ok || !context.mounted) return;
  store.deleteMoneyCard(card.id);
  showNexusToast(context, store.lastToast);
}

Future<bool> _confirm(BuildContext context, {required String title, required String body}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: NexusColors.card,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('やめる')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      );
    },
  );
  return result == true;
}
