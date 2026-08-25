import '../data/models.dart';

class MoneySnapshot {
  const MoneySnapshot({
    required this.income,
    required this.expense,
    required this.balance,
    required this.spendableToday,
    required this.todayBudget,
    required this.spendableWeek,
  });

  final int income;
  final int expense;
  final int balance;
  final int spendableToday;
  final int todayBudget;
  final int spendableWeek;
}

class MoneyCalc {
  MoneyCalc._();

  static MoneySnapshot compute({
    required int income,
    required List<BudgetBox> boxes,
    required List<PaymentPlan> payments,
    required DateTime today,
  }) {
    final expense = boxes.fold<int>(0, (sum, b) => sum + b.spent);
    final variableRemaining = boxes.fold<int>(0, (sum, b) => sum + b.remaining);
    final monthEnd = DateTime(today.year, today.month + 1, 0);
    final remainingDays = monthEnd.day - today.day + 1;
    final upcoming = payments
        .where((p) => !p.dueAt.isBefore(DateTime(today.year, today.month, today.day)))
        .where((p) => p.dueAt.month == today.month && p.dueAt.year == today.year)
        .fold<int>(0, (sum, p) => sum + p.amount);

    final pool = (variableRemaining - upcoming).clamp(0, 1 << 31);
    final spendableToday = remainingDays <= 0 ? 0 : (pool / remainingDays).floor();
    final weekDays = remainingDays < 7 ? remainingDays : 7;
    final spendableWeek = weekDays <= 0 ? 0 : spendableToday * weekDays;
    final todayBudget = spendableToday == 0
        ? 0
        : (spendableToday / 0.62).round().clamp(spendableToday, spendableToday * 3);

    return MoneySnapshot(
      income: income,
      expense: expense,
      balance: income - expense,
      spendableToday: spendableToday,
      todayBudget: todayBudget < spendableToday ? spendableToday : todayBudget,
      spendableWeek: spendableWeek,
    );
  }
}

String assignmentRisk({required DateTime dueAt, required DateTime today, required bool done}) {
  if (done) return '余裕あり';
  final days = DateTime(dueAt.year, dueAt.month, dueAt.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  if (days <= 2) return '要注意';
  if (days <= 7) return '注意';
  return '余裕あり';
}
