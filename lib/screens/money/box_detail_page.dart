import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_bits.dart';
import 'money_forms.dart';

enum _CardSort { date, amount, tag }

class BoxDetailPage extends StatefulWidget {
  const BoxDetailPage({super.key, required this.boxId});

  final String boxId;

  @override
  State<BoxDetailPage> createState() => _BoxDetailPageState();
}

class _BoxDetailPageState extends State<BoxDetailPage> {
  DateTime _month = dateOnly(DateTime.now());
  _CardSort _sort = _CardSort.date;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final box = store.boxById(widget.boxId);
    if (box == null) {
      return const Scaffold(body: Center(child: Text('ボックスが見つかりません')));
    }

    var list = store.cardsForBox(box.id, month: box.isSavings ? null : _month);
    list = [...list];
    switch (_sort) {
      case _CardSort.date:
        list.sort((a, b) => b.at.compareTo(a.at));
      case _CardSort.amount:
        list.sort((a, b) => b.amount.compareTo(a.amount));
      case _CardSort.tag:
        list.sort((a, b) => a.tag.compareTo(b.tag));
    }

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
                Icon(box.icon, color: box.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    box.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'ボックスを編集',
                  onPressed: () => openEditBox(context, store, box),
                  icon: Icon(Icons.edit_rounded, color: NexusColors.textSecondary),
                ),
                AddChip(
                  label: 'カードを追加',
                  onTap: () => openAddCard(context, store, boxId: box.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!box.isSavings)
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1, 1)),
                    icon: Icon(Icons.chevron_left, color: NexusColors.cyan),
                  ),
                  Text(jpMonth(_month), style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1, 1)),
                    icon: Icon(Icons.chevron_right, color: NexusColors.cyan),
                  ),
                ],
              ),
            if (box.isSavings) _SavingsHero(store: store, box: box) else _BudgetHero(store: store, box: box, month: _month),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final sort in _CardSort.values)
                  ChoiceChip(
                    label: Text(switch (sort) {
                      _CardSort.date => '日付順',
                      _CardSort.amount => '金額順',
                      _CardSort.tag => 'タグ別',
                    }),
                    selected: _sort == sort,
                    onSelected: (_) => setState(() => _sort = sort),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  box.isSavings ? 'まだ貯蓄履歴はありません' : 'この月のカードはありません',
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
                                if (card.tag.isNotEmpty)
                                  Text(card.tag, style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                            _amountLabel(card),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: card.kind == MoneyCardKind.saveIn
                                  ? NexusColors.income
                                  : NexusColors.expense,
                            ),
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

  String _amountLabel(MoneyCard card) {
    if (card.kind == MoneyCardKind.saveIn) return '+${yen(card.amount)}';
    if (card.kind == MoneyCardKind.saveOut) return '-${yen(card.amount)}';
    return yen(-card.amount);
  }
}

class _BudgetHero extends StatelessWidget {
  const _BudgetHero({required this.store, required this.box, required this.month});

  final AppStore store;
  final BudgetBox box;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final spent = store.spentOfBox(box.id, month: month);
    final remain = box.monthlyBudget - spent;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('残り', style: TextStyle(color: NexusColors.textSecondary)),
          Text(yen(remain), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('予算 ${yen(box.monthlyBudget)}'),
              const Spacer(),
              Text('使用済み ${yen(spent)}', style: TextStyle(color: NexusColors.expense)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: box.monthlyBudget == 0 ? 0 : (spent / box.monthlyBudget).clamp(0, 1),
              minHeight: 8,
              color: box.color,
              backgroundColor: NexusColors.border,
            ),
          ),
          if (box.memo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(box.memo, style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _SavingsHero extends StatelessWidget {
  const _SavingsHero({required this.store, required this.box});

  final AppStore store;
  final BudgetBox box;

  @override
  Widget build(BuildContext context) {
    final current = store.savingsBalance(box);
    final ratio = box.targetAmount == 0 ? 0.0 : (current / box.targetAmount).clamp(0.0, 1.0);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('目標金額', style: TextStyle(color: NexusColors.textSecondary)),
          Text(yen(box.targetAmount), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text('現在金額', style: TextStyle(color: NexusColors.textSecondary)),
          Text(yen(current), style: TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: NexusColors.cyan)),
          if (box.targetDate != null)
            Text('目標日 ${jpDate(box.targetDate!)}', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: box.color,
              backgroundColor: NexusColors.border,
            ),
          ),
          const SizedBox(height: 6),
          Text('達成率 ${(ratio * 100).round()}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
