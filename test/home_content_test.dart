import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/core/format.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/data/models.dart';
import 'package:nexus/domain/daily_quotes.dart';
import 'package:nexus/domain/day_occasions.dart';

void main() {
  test('8月18日は米の日で、漢字の由来が説明される', () {
    final day = occasionFor(DateTime(2026, 8, 18));
    expect(day.name, '米の日');
    expect(day.reason.contains('八'), isTrue);
    expect(day.alsoKnownAs, contains('高校野球記念日'));
  });

  test('国民の祝日は記念日より優先される', () {
    expect(occasionFor(DateTime(2026, 1, 1)).name, '元日');
    expect(occasionFor(DateTime(2026, 5, 5)).name, 'こどもの日');
    expect(occasionFor(DateTime(2026, 8, 11)).name, '山の日');
    expect(occasionFor(DateTime(2026, 5, 6)).name, '振替休日');
  });

  test('日付が変わると記念日も名言も変わる', () {
    final a = occasionFor(DateTime(2026, 8, 18));
    final b = occasionFor(DateTime(2026, 8, 15));
    expect(a.name, isNot(b.name));

    final q1 = quoteFor(DateTime(2026, 8, 18));
    final q2 = quoteFor(DateTime(2026, 1, 1));
    expect(q1.text, isNot(q2.text));
    expect(q1.author, isNotEmpty);
  });

  test('残りの勉強時間は60分以上なら時間、未満なら分数', () {
    expect(remainingStudyLabel(0), '達成');
    expect(remainingStudyLabel(25), '25分');
    expect(remainingStudyLabel(60), '1時間');
    expect(remainingStudyLabel(80), '1時間20分');
  });

  test('1時間以上のタイマー表示は時:分:秒になる', () {
    expect(mmss(25 * 60), '25:00');
    expect(mmss(90 * 60), '1:30:00');
    expect(mmss(12 * 60 * 60), '12:00:00');
  });

  test('今日の勉強目標を変えると残り時間が変わる', () {
    final store = AppStore.seed();
    store.setDailyStudyGoalMinutes(60);
    expect(store.dailyStudyGoalMinutes, 60);
    expect(store.remainingStudyMinutes(), 60);

    store.todayStudyLoggedSeconds = 20 * 60;
    expect(store.remainingStudyMinutes(), 40);
    expect(remainingStudyLabel(store.remainingStudyMinutes()), '40分');
  });

  test('提出物は期限までの日数、目標はサブゴール4つを持てる', () {
    final store = AppStore.seed();
    final math = store.addSubject(name: '数学');
    final today = store.focusedDate;
    store.addAssignment(
      subjectId: math.id,
      title: '小テスト',
      dueAt: today.add(const Duration(days: 3)),
    );
    expect(daysLeftLabel(today.add(const Duration(days: 3)), today), 'あと3日');
    expect(
      store.assignments.any((a) => a.title == '小テスト'),
      isTrue,
    );

    store.addGoal(
      title: '英検準1級',
      current: 10,
      target: 100,
      dueAt: today.add(const Duration(days: 60)),
      subGoalTitles: ['単語', '長文', 'リスニング', 'スピーキング'],
    );
    expect(store.goals.last.subGoals.length, 4);
    expect(store.goals.last.filledSubGoals.length, 4);
  });

  test('学習記録は積層グラフの科目時間に積まれる', () {
    final store = AppStore.seed();
    final math = store.addSubject(name: '数学');
    final before = store.weekStudyHours;
    store.addStudySession(subjectId: math.id, minutes: 60, focus: StudyFocus.peak);
    expect(store.weekStudyHours, greaterThan(before));
    expect(store.sessions.first.focus, StudyFocus.peak);
  });

  test('新しい教科は一覧にすぐ追加される', () {
    final store = AppStore.seed();
    final added = store.addSubject(name: '物理');
    expect(store.subjects.any((s) => s.id == added.id && s.name == '物理'), isTrue);
  });

  test('収入は入金月ではなく使用月で計算する', () {
    final store = AppStore.seed();
    store.incomes.clear();
    store.addIncome(
      name: '給料',
      amount: 140000,
      depositedAt: DateTime(2026, 8, 30),
      useYear: 2026,
      useMonth: 9,
    );
    expect(store.incomeForMonth(DateTime(2026, 8, 18)), 0);
    expect(store.incomeForMonth(DateTime(2026, 9, 1)), 140000);
  });

  test('カードを別ボックスへ移すと二重計上されない', () {
    final store = AppStore.seed();
    final food = store.addBudgetBox(
      name: '食費',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFF3DA9FC),
      monthlyBudget: 30000,
      renewalDay: 1,
      tags: const ['外食'],
    );
    final train = store.addBudgetBox(
      name: '交通費',
      icon: Icons.train_rounded,
      color: const Color(0xFF9B6BFF),
      monthlyBudget: 5000,
      renewalDay: 1,
      tags: const ['電車'],
    );
    final card = store.addMoneyCard(
      boxId: food.id,
      title: 'サイゼリヤ追加',
      amount: 1480,
      at: store.focusedDate,
      tag: '外食',
    );
    final foodBefore = store.spentOfBox(food.id, month: store.focusedDate);
    final trainBefore = store.spentOfBox(train.id, month: store.focusedDate);
    store.updateMoneyCard(card.copyWith(boxId: train.id));
    expect(store.spentOfBox(food.id, month: store.focusedDate), foodBefore - 1480);
    expect(store.spentOfBox(train.id, month: store.focusedDate), trainBefore + 1480);
  });

  test('予算ボックスは指定した更新日から次の更新日前日までを一期間とする', () {
    final store = AppStore.seed();
    final created = store.addBudgetBox(
      name: '食費',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFF3DA9FC),
      monthlyBudget: 30000,
      renewalDay: 10,
      tags: const ['外食'],
    );
    final box = created.copyWith(renewalDay: 10);
    final mid = store.budgetPeriod(box, DateTime(2026, 8, 18));
    expect(mid.start, DateTime(2026, 8, 10));
    expect(mid.end, DateTime(2026, 9, 9));
    final early = store.budgetPeriod(box, DateTime(2026, 8, 5));
    expect(early.start, DateTime(2026, 7, 10));
    expect(early.end, DateTime(2026, 8, 9));
  });

  test('貯蓄ボックスは月が変わっても残高を持ち越し、カード移動で残高が入れ替わる', () {
    final store = AppStore.seed();
    final korea = store.addSavingsBox(
      name: '韓国旅行',
      icon: Icons.flight_rounded,
      color: const Color(0xFFFF8AD2),
      targetAmount: 150000,
      openingAmount: 72000,
      tags: const ['ホテル'],
    );
    expect(store.savingsBalance(korea), 72000);
    expect(korea.isSavings, isTrue);

    store.addBudgetBox(
      name: '友達',
      icon: Icons.people_alt_rounded,
      color: const Color(0xFFFF8AD2),
      monthlyBudget: 10000,
      renewalDay: 25,
      tags: const ['ご飯', 'その他'],
    );
    final friend = store.boxes.last;
    final card = store.addMoneyCard(
      boxId: friend.id,
      title: 'サイゼリヤ',
      amount: 1480,
      at: DateTime(2026, 8, 18),
      tag: 'ご飯',
    );
    expect(store.spentOfBox(friend.id, month: DateTime(2026, 8, 1)), 1480);
    store.updateMoneyCard(card.copyWith(boxId: korea.id, kind: MoneyCardKind.saveOut));
    expect(store.spentOfBox(friend.id, month: DateTime(2026, 8, 1)), 0);
    expect(store.savingsBalance(korea), 72000 - 1480);
  });

  test('教科の追加はJSON経由でも復元できる', () {
    final store = AppStore.seed();
    final added = store.addSubject(name: '物理');
    final restored = StudySubject.fromJson(added.toJson());
    expect(restored.name, '物理');
    expect(restored.id, added.id);
    expect(restored.icon.codePoint, added.icon.codePoint);
  });

  test('習慣は名前を付けて追加できる', () {
    final store = AppStore.seed();
    final added = store.addHabit(
      name: '読書',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF00D4FF),
    );
    expect(store.habits.any((h) => h.id == added.id && h.name == '読書'), isTrue);
  });

  test('習慣チェーンは連続日数で数える', () {
    final store = AppStore.seed();
    final today = store.focusedDate;
    store.habits.add(
      Habit(
        id: 'h-wake',
        name: '起床',
        icon: Icons.wb_sunny_rounded,
        color: const Color(0xFFFFC857),
        doneDays: {
          for (var i = 0; i < 5; i++) dateKey(today.subtract(Duration(days: i))),
        },
      ),
    );
    final wake = store.habits.firstWhere((h) => h.name == '起床');
    expect(wake.currentStreak(store.focusedDate), 5);
    store.toggleHabit(wake.id, store.focusedDate);
    final after = store.habits.firstWhere((h) => h.name == '起床');
    expect(after.doneOn(store.focusedDate), isFalse);
    expect(after.currentStreak(store.focusedDate), 4);
  });

  test('睡眠は就寝と起床から時間を記録する', () {
    final store = AppStore.seed();
    store.sleepLogs.clear();
    store.logSleep(
      bedAt: DateTime(2026, 8, 17, 23, 30),
      wakeAt: DateTime(2026, 8, 18, 7, 0),
      quality: 4,
    );
    expect(store.sleepHours, 7.5);
    expect(store.sleepLogOn(DateTime(2026, 8, 18))?.qualityLabel, 'よい');

    store.startSleep(at: DateTime(2026, 8, 18, 23, 0));
    expect(store.isSleeping, isTrue);
    store.wakeUp(at: DateTime(2026, 8, 19, 7, 0), quality: 5);
    expect(store.isSleeping, isFalse);
    expect(store.sleepLogOn(DateTime(2026, 8, 19))?.hours, 8.0);
  });

  test('Lifeの日付を変えても他画面の日付は変わらない', () {
    final store = AppStore.seed();
    final today = store.focusedDate;
    store.setLifeDate(DateTime(today.year, today.month, 19));
    expect(store.lifeDate.day, 19);
    expect(store.focusedDate, today);
    store.setLifeDate(DateTime(today.year, today.month, 27));
    expect(store.lifeDate.day, 27);
    expect(store.focusedDate, today);
  });

  test('ボックスと支払予定は削除でき、カードは未振り分けへ移る', () {
    final store = AppStore.seed();
    final unassigned = store.addBudgetBox(
      name: '未振り分け',
      icon: Icons.inbox_rounded,
      color: const Color(0xFF8B9BB4),
      monthlyBudget: 0,
      renewalDay: 1,
      tags: const ['その他'],
    );
    final food = store.addBudgetBox(
      name: '食費',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFF3DA9FC),
      monthlyBudget: 30000,
      renewalDay: 1,
      tags: const ['外食'],
    );
    store.addMoneyCard(
      boxId: food.id,
      title: 'サイゼリヤ',
      amount: 1480,
      at: store.focusedDate,
      tag: '外食',
    );
    expect(store.cards.any((c) => c.boxId == food.id), isTrue);
    store.deleteBox(food.id);
    expect(store.boxById(food.id), isNull);
    expect(store.cards.any((c) => c.boxId == food.id), isFalse);
    expect(store.cards.any((c) => c.title == 'サイゼリヤ' && c.boxId == unassigned.id), isTrue);

    store.addPaymentPlan(
      title: 'スマホ代',
      amount: 3000,
      dueAt: store.focusedDate.add(const Duration(days: 7)),
    );
    final payId = store.payments.last.id;
    store.deletePayment(payId);
    expect(store.payments.any((p) => p.id == payId), isFalse);
  });
}
