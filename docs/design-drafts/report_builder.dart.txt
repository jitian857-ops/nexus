import '../core/format.dart';
import '../data/app_store.dart';
import '../data/models.dart';

class ReportBuilder {
  ReportBuilder._();

  static String weekly(AppStore store, DateTime day) {
    final monday = dateOnly(day).subtract(Duration(days: mondayIndex(day)));
    final sunday = monday.add(const Duration(days: 6));
    final sessions = store.sessions.where((s) {
      final at = dateOnly(s.at);
      return !at.isBefore(monday) && !at.isAfter(sunday);
    }).toList();
    final minutes = sessions.fold<int>(0, (sum, s) => sum + s.minutes);
    final due = store.reviewDueCount();
    final habits = store.habits.where((h) => !h.archived).toList();
    final habitLines = [
      for (final h in habits)
        h.isWeekly
            ? '  - ${h.name}: 今週 ${h.weekDoneCount(day)}/${h.weekTarget}回'
            : '  - ${h.name}: 連続 ${h.currentStreak(day)}日',
    ];
    final income = store.incomeForMonth(day);
    final expense = store.money.expense;
    return [
      'NEXUS 週次レポート',
      '${jpDate(monday)} 〜 ${jpDate(sunday)}',
      '',
      'Study',
      '  学習 ${sessions.length}回 / ${(minutes / 60).toStringAsFixed(1)}時間',
      '  今日の復習残り $due 枚',
      '  提出物 未完了 ${store.assignments.where((a) => !a.done && !a.archived).length}件',
      '',
      'Life',
      if (habitLines.isEmpty) '  習慣はまだありません' else ...habitLines,
      '',
      'Money',
      '  今月の収入 ${yen(income)} / 支出 ${yen(expense)}',
      '  未振り分け ${yen(store.unallocatedForMonth(day))}',
      '',
      '次の一歩',
      '  ${store.nextAction(day)?.title ?? '今日の最重要を1つ決める'}',
    ].join('\n');
  }

  static String monthly(AppStore store, DateTime day, {DateTime? previous}) {
    final month = DateTime(day.year, day.month, 1);
    final prev = previous ?? DateTime(month.year, month.month - 1, 1);
    final thisMinutes = _monthMinutes(store, month);
    final prevMinutes = _monthMinutes(store, prev);
    final thisIncome = store.incomeForMonth(month);
    final prevIncome = store.incomeForMonth(prev);
    final thisExpense = _monthExpense(store, month);
    final prevExpense = _monthExpense(store, prev);
    final moods = store.checkIns.values.where((c) {
      final d = DateTime.tryParse(c.dayKey);
      return d != null && d.year == month.year && d.month == month.month && c.mood > 0;
    }).toList();
    final avgMood = moods.isEmpty
        ? 0.0
        : moods.fold<int>(0, (s, c) => s + c.mood) / moods.length;

    String delta(num now, num then, {String unit = ''}) {
      final diff = now - then;
      final sign = diff >= 0 ? '+' : '';
      return '$sign${diff is int ? diff : (diff as double).toStringAsFixed(1)}$unit';
    }

    final suggestions = <String>[];
    if (thisMinutes < prevMinutes) {
      suggestions.add('学習時間が前月より短い。週の最初に短い集中を置く。');
    } else {
      suggestions.add('学習の勢いは維持できている。復習キューを先に片付ける。');
    }
    if (store.unallocatedForMonth(month) > 0) {
      suggestions.add('未振り分けが残っている。来月分のボックスへ役割を与える。');
    }
    if (avgMood > 0 && avgMood < 3) {
      suggestions.add('気分が低めの日が多かった。10秒チェックインを続ける。');
    }

    return [
      'NEXUS 月次レポート',
      jpMonth(month),
      '',
      'Study',
      '  学習 ${(thisMinutes / 60).toStringAsFixed(1)}時間（前月比 ${delta(thisMinutes / 60, prevMinutes / 60, unit: 'h')}）',
      '  科目数 ${store.subjects.length} / 試験 ${store.exams.length}',
      '',
      'Life',
      '  記録した気分 ${moods.length}日 / 平均 ${avgMood.toStringAsFixed(1)}',
      '  習慣 ${store.habits.where((h) => !h.archived).length}件',
      '',
      'Money',
      '  収入 ${yen(thisIncome)}（前月比 ${delta(thisIncome, prevIncome)}）',
      '  支出 ${yen(thisExpense)}（前月比 ${delta(thisExpense, prevExpense)}）',
      '  未振り分け ${yen(store.unallocatedForMonth(month))}',
      '',
      '来月の提案',
      for (final s in suggestions) '  - $s',
    ].join('\n');
  }

  static int _monthMinutes(AppStore store, DateTime month) {
    return store.sessions
        .where((s) => s.at.year == month.year && s.at.month == month.month)
        .fold<int>(0, (sum, s) => sum + s.minutes);
  }

  static int _monthExpense(AppStore store, DateTime month) {
    return store.cards
        .where(
          (c) =>
              c.kind == MoneyCardKind.spend &&
              c.at.year == month.year &&
              c.at.month == month.month,
        )
        .fold<int>(0, (sum, c) => sum + c.amount);
  }
}

const kLifeActivityTags = ['勉強', '運動', '食事', '友人', '休息', '仕事', '趣味', '外出'];
