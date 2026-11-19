import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/data/models.dart';

void main() {
  for (final start in [DateTime(2026, 10), DateTime(2026, 12)]) {
    final next = DateTime(start.year, start.month + 1);
    for (final deduct in [false, true]) {
      AppStore fresh() {
        final s = AppStore.seed();
        s.boxes.clear();
        s.cards.clear();
        s.incomes.clear();
        s.payments.clear();
        s.moneyMonth = start;
        s.updateSettings(s.settings.copyWith(deductBudgetFromBalance: deduct));
        for (final month in [start, next]) {
          s.addIncome(
            name: 'income',
            amount: 100000,
            depositedAt: month,
            useYear: month.year,
            useMonth: month.month,
          );
        }
        addTearDown(s.dispose);
        return s;
      }

      BudgetBox box(AppStore s, DateTime month) => s.addBudgetBox(
        name: 'budget',
        icon: Icons.restaurant,
        color: Colors.blue,
        monthlyBudget: 30000,
        tags: [],
        month: month,
      );
      final label = '${start.month} to ${next.month}, deduct=$deduct';
      test('new cross-month expense is counted once: $label', () {
        final s = fresh();
        final b = box(s, start);
        s.addMoneyCard(boxId: b.id, title: 'expense', amount: 1000, at: next);
        expect(s.moneyFor(start).expense, deduct ? 30000 : 0);
        expect(s.moneyFor(next).expense, 1000);
        expect(s.moneyFor(next).balance, 99000);
        expect(s.unassignedSpentFor(next), 1000);
      });
      test('date edit, JSON restore and deletion preserve totals: $label', () {
        final s = fresh();
        final b = box(s, start);
        final c = s.addMoneyCard(
          boxId: b.id,
          title: 'expense',
          amount: 1000,
          at: start,
        );
        expect(s.moneyFor(start).expense, deduct ? 30000 : 1000);
        s.updateMoneyCard(c.copyWith(at: next));
        final restored = AppStore.seed()
          ..applyCloudMap(
            jsonDecode(jsonEncode(s.toCloudMap())) as Map<String, dynamic>,
          );
        addTearDown(restored.dispose);
        expect(restored.moneyFor(start).expense, deduct ? 30000 : 0);
        expect(restored.moneyFor(next).expense, 1000);
        expect(restored.spendCardsInMonth(next).single.id, c.id);
        restored.deleteMoneyCard(c.id);
        expect(restored.moneyFor(next).expense, 0);
      });
      test(
        'moving between matching and mismatched boxes counts once: $label',
        () {
          final s = fresh();
          final oldBox = box(s, start);
          final newBox = box(s, next);
          final c = s.addMoneyCard(
            boxId: newBox.id,
            title: 'expense',
            amount: 40000,
            at: next,
          );
          expect(s.moneyFor(next).expense, 40000);
          s.updateMoneyCard(c.copyWith(boxId: oldBox.id));
          // The current month's separate unused budget remains reserved when enabled.
          expect(s.moneyFor(next).expense, deduct ? 70000 : 40000);
          expect(s.unassignedSpentFor(next), 40000);
          s.updateMoneyCard(c);
          expect(s.moneyFor(next).expense, 40000);
          expect(s.unassignedSpentFor(next), 0);
        },
      );
    }
  }
  test('savings accounting and carry-over are not counted twice', () {
    final s = AppStore.seed();
    addTearDown(s.dispose);
    final day = DateTime(2026, 12);
    final next = DateTime(2027, 1);
    s.boxes.clear();
    s.cards.clear();
    s.incomes.clear();
    s.payments.clear();
    final b = s.addSavingsBox(
      name: 'savings',
      icon: Icons.savings,
      color: Colors.blue,
      targetAmount: 100000,
      openingAmount: 5000,
      tags: [],
    );
    s.addMoneyCard(
      boxId: b.id,
      title: 'deposit',
      amount: 2000,
      at: day,
      kind: MoneyCardKind.saveIn,
    );
    s.addMoneyCard(boxId: b.id, title: 'cash expense', amount: 1000, at: next);
    s.addMoneyCard(
      boxId: b.id,
      title: 'savings expense',
      amount: 500,
      at: next,
      kind: MoneyCardKind.saveOut,
    );
    expect(s.moneyFor(day).expense, 2000);
    expect(s.moneyFor(next).expense, 1000);
    expect(s.unassignedSpentFor(next), 0);
    expect(s.savingsBalance(b), 6500);
  });
}
