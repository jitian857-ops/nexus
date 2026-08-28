import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../widgets/count_up_yen.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_bits.dart';
import 'box_detail_page.dart';
import 'money_forms.dart';

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  bool todayTab = true;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final money = store.money;
    final remainRatio = money.todayBudget == 0 ? 0.0 : money.spendableToday / money.todayBudget;

    return PageScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              const Expanded(child: GradientTitle('Money')),
              AddChip(
                label: '収入を追加',
                onTap: () => openAddIncome(context, store),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 180) {
                store.shiftMoneyMonth(-1);
              } else if (velocity < -180) {
                store.shiftMoneyMonth(1);
              }
            },
            child: GlassCard(
              glowColor: NexusColors.gold,
              borderColor: NexusColors.gold.withValues(alpha: 0.28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => store.shiftMoneyMonth(-1),
                      icon: Icon(Icons.chevron_left, color: NexusColors.gold),
                    ),
                    Expanded(
                      child: Text(
                        '${jpMonth(store.moneyMonth)}の残高',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: NexusColors.textSecondary),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => store.shiftMoneyMonth(1),
                      icon: Icon(Icons.chevron_right, color: NexusColors.gold),
                    ),
                  ],
                ),
                Center(
                  child: CountUpYen(
                    value: money.balance,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: NexusColors.gold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.center,
                  child: FilterChip(
                    selected: store.settings.deductBudgetFromBalance,
                    label: Text(
                      store.settings.deductBudgetFromBalance ? '予算を差し引いて表示中' : '予算を差し引いて表示',
                    ),
                    selectedColor: NexusColors.gold.withValues(alpha: 0.22),
                    labelStyle: TextStyle(
                      color: store.settings.deductBudgetFromBalance
                          ? NexusColors.gold
                          : NexusColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    onSelected: (value) => store.updateSettings(
                      store.settings.copyWith(deductBudgetFromBalance: value),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: NexusColors.income.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: NexusColors.income.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_upward_rounded, size: 13, color: NexusColors.income),
                          const SizedBox(width: 4),
                          Text(
                            '収入 ${yen(money.income)}',
                            style: TextStyle(color: NexusColors.income, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: NexusColors.expense.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: NexusColors.expense.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_downward_rounded, size: 13, color: NexusColors.expense),
                          const SizedBox(width: 4),
                          Text(
                            '支出 ${yen(-money.expense)}',
                            style: TextStyle(color: NexusColors.expense, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
          const SizedBox(height: 14),
          const SectionRow(title: 'ボックス'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AddChip(label: 'ボックスを追加', onTap: () => openAddBox(context, store)),
              AddChip(label: 'カードを追加', onTap: () => openAddCard(context, store)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 168,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              padding: EdgeInsets.zero,
              itemCount: store.boxes.length,
              onReorder: store.reorderBoxes,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) => Transform.scale(scale: 1.05, child: child),
                );
              },
              itemBuilder: (context, i) {
                final box = store.boxes[i];
                return Padding(
                  key: ValueKey(box.id),
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 148,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ReorderableTapDragListener(
                            index: i,
                            enabled: store.boxes.length > 1,
                            onTap: () => _openBox(context, box.id),
                            child: box.isSavings
                                ? _SavingsTile(store: store, box: box)
                                : _BudgetTile(store: store, box: box),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: _DeleteMark(
                            onTap: () => _confirmDeleteBox(context, store, box),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (store.boxes.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'ダブルタップしてからドラッグすると順番を変えられます',
                style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
              ),
            ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                Row(
                  children: [
                    _Tab(
                      label: '今日使える額',
                      selected: todayTab,
                      onTap: () => setState(() => todayTab = true),
                    ),
                    _Tab(
                      label: '今週使える額',
                      selected: !todayTab,
                      onTap: () => setState(() => todayTab = false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ShaderMask(
                  shaderCallback: (rect) =>
                      LinearGradient(colors: NexusColors.accentSweep).createShader(rect),
                  child: Text(
                    yen(todayTab ? money.spendableToday : money.spendableWeek),
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: remainRatio.clamp(0.0, 1.0),
                    minHeight: 5,
                    color: NexusColors.cyan,
                    backgroundColor: NexusColors.border,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('今日の予算 ${yen(money.todayBudget)}', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                    const Spacer(),
                    Text('残り ${(remainRatio * 100).round()}%', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                SectionRow(
                  title: '今後の支払い予定',
                  trailing: AddChip(
                    label: '支払予定を追加',
                    onTap: () => openAddPayment(context, store),
                  ),
                ),
                const SizedBox(height: 8),
                for (final p in store.payments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: NexusColors.cyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(Icons.event_rounded, size: 15, color: NexusColors.cyan),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.title),
                              Text(
                                [
                                  if (p.boxId != null) store.boxById(p.boxId!)?.name,
                                  switch (p.repeat) {
                                    PaymentRepeat.none => null,
                                    PaymentRepeat.monthly => '毎月',
                                    PaymentRepeat.yearly => '毎年',
                                  },
                                ].whereType<String>().join(' ・ '),
                                style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${store.nextPaymentDue(p, store.focusedDate).month}/${store.nextPaymentDue(p, store.focusedDate).day}',
                          style: TextStyle(color: NexusColors.textMuted),
                        ),
                        const SizedBox(width: 10),
                        Text(yen(p.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                        _DeleteMark(
                          onTap: () => _confirmDeletePayment(context, store, p),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBox(BuildContext context, String boxId) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => BoxDetailPage(boxId: boxId),
      ),
    );
  }

  Future<void> _confirmDeleteBox(BuildContext context, AppStore store, BudgetBox box) async {
    final ok = await _confirm(
      context,
      title: 'ボックスを削除',
      body: '「${box.name}」を削除します。中のカードも消えて、残高への影響は取り消されます。',
    );
    if (!ok || !context.mounted) return;
    store.deleteBox(box.id);
    showNexusToast(context, store.lastToast);
  }

  Future<void> _confirmDeletePayment(BuildContext context, AppStore store, PaymentPlan plan) async {
    final ok = await _confirm(
      context,
      title: '支払予定を削除',
      body: '「${plan.title}」を削除します。',
    );
    if (!ok || !context.mounted) return;
    store.deletePayment(plan.id);
    showNexusToast(context, store.lastToast);
  }
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

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({required this.store, required this.box});

  final AppStore store;
  final BudgetBox box;

  @override
  Widget build(BuildContext context) {
    final spent = store.spentOfBox(box.id, periodOf: box, day: store.moneyMonth);
    final remaining = box.monthlyBudget - spent;
    final ratio = box.monthlyBudget == 0 ? 0.0 : spent / box.monthlyBudget;
    return GlassCard(
      borderColor: box.color.withValues(alpha: 0.45),
      glowColor: box.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: box.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(box.icon, color: box.color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(box.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('残り ${yen(remaining)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text('予算 ${yen(box.monthlyBudget)}', style: TextStyle(color: NexusColors.textMuted, fontSize: 11)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              minHeight: 6,
              color: box.color,
              backgroundColor: NexusColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsTile extends StatelessWidget {
  const _SavingsTile({required this.store, required this.box});

  final AppStore store;
  final BudgetBox box;

  @override
  Widget build(BuildContext context) {
    final current = store.savingsBalance(box);
    final ratio = box.targetAmount == 0 ? 0.0 : current / box.targetAmount;
    return GlassCard(
      borderColor: box.color.withValues(alpha: 0.45),
      glowColor: box.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: box.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(box.icon, color: box.color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(box.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(yen(current), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: NexusColors.gold)),
          Text(
            '${yen(current)} / ${yen(box.targetAmount)}',
            style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              minHeight: 6,
              color: box.color,
              backgroundColor: NexusColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteMark extends StatelessWidget {
  const _DeleteMark({required this.onTap});

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

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? NexusColors.cyan : NexusColors.textMuted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 2,
              color: selected ? NexusColors.cyan : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
