import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/app/theme.dart';
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

  test('1分の学習は0.02hに繰り上げ表示される', () {
    final store = AppStore.seed();
    final math = store.addSubject(name: '数学');
    store.addStudySession(subjectId: math.id, minutes: 1, focus: StudyFocus.high);
    expect(store.weekStudyHours, closeTo(1 / 60, 0.0001));
    expect(formatStudyHours(store.weekStudyHours), '0.02h');
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

  test('入金日を動かすと使う月の初期値も翌月に動く', () {
    expect(nextUseMonth(DateTime(2026, 8, 25)), (year: 2026, month: 9));
    expect(nextUseMonth(DateTime(2026, 12, 10)), (year: 2027, month: 1));
  });

  test('予算ボックスを作ると今月の残高が減る', () {
    final store = AppStore.seed();
    store.incomes.clear();
    store.boxes.clear();
    store.addIncome(
      name: '給料',
      amount: 100000,
      depositedAt: store.focusedDate,
      useYear: store.focusedDate.year,
      useMonth: store.focusedDate.month,
    );
    expect(store.money.balance, 100000);
    store.addBudgetBox(
      name: '食費',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFF3DA9FC),
      monthlyBudget: 30000,
      renewalDay: 1,
      tags: const ['その他'],
    );
    expect(store.money.expense, 30000);
    expect(store.money.balance, 70000);
  });

  test('貯蓄ボックスへ預けると残高が減り、ボックスを消すと戻る', () {
    final store = AppStore.seed();
    store.incomes.clear();
    store.boxes.clear();
    store.cards.clear();
    store.addIncome(
      name: '給料',
      amount: 100000,
      depositedAt: store.focusedDate,
      useYear: store.focusedDate.year,
      useMonth: store.focusedDate.month,
    );
    final save = store.addSavingsBox(
      name: '旅行',
      icon: Icons.savings_rounded,
      color: const Color(0xFFFFC857),
      targetAmount: 150000,
      openingAmount: 0,
      tags: const ['積立'],
    );
    expect(store.money.balance, 100000);
    store.addMoneyCard(
      boxId: save.id,
      title: '積立',
      amount: 20000,
      at: store.focusedDate,
      kind: MoneyCardKind.saveIn,
    );
    expect(store.money.balance, 80000);
    store.addMoneyCard(
      boxId: save.id,
      title: '残高から支出',
      amount: 5000,
      at: store.focusedDate,
      kind: MoneyCardKind.spend,
    );
    expect(store.money.balance, 75000);
    store.addMoneyCard(
      boxId: save.id,
      title: '貯蓄から支出',
      amount: 3000,
      at: store.focusedDate,
      kind: MoneyCardKind.saveOut,
    );
    expect(store.money.balance, 75000);
    expect(store.savingsBalance(save), 17000);
    store.deleteBox(save.id);
    expect(store.money.balance, 100000);
  });

  test('試験カウントダウンは作った日が0で日ごとに進む', () {
    final store = AppStore.seed();
    store.focusedDate = DateTime(2026, 8, 1);
    store.addExam(title: '模試', examAt: DateTime(2026, 8, 11));
    final exam = store.exams.last;
    expect(exam.countdownProgress(DateTime(2026, 8, 1)), 0);
    expect(exam.countdownProgress(DateTime(2026, 8, 6)), 0.5);
    expect(exam.countdownProgress(DateTime(2026, 8, 11)), 1);
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

  test('ボックスと支払予定は削除でき、カードを消すと残高が戻る', () {
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
    expect(store.cards.any((c) => c.title == 'サイゼリヤ'), isFalse);

    store.deleteBox(unassigned.id);
    expect(store.boxes, isEmpty);

    store.addPaymentPlan(
      title: 'スマホ代',
      amount: 3000,
      dueAt: store.focusedDate.add(const Duration(days: 7)),
    );
    final payId = store.payments.last.id;
    store.deletePayment(payId);
    expect(store.payments.any((p) => p.id == payId), isFalse);
  });

  test('StudyとMoneyのボックス色は11色ある', () {
    expect(NexusColors.boxPalette, hasLength(11));
  });

  test('教科はアイコンと色を指定して作り、あとから編集できる', () {
    final store = AppStore.seed();
    final added = store.addSubject(
      name: '数学',
      icon: Icons.functions,
      color: NexusColors.boxPalette.last,
    );
    expect(added.icon, Icons.functions);
    expect(added.color, NexusColors.boxPalette.last);

    store.updateSubject(added.copyWith(name: '数II', icon: Icons.science_rounded));
    expect(store.subjects.single.name, '数II');
    expect(store.subjects.single.icon, Icons.science_rounded);
    expect(store.subjects.single.color, NexusColors.boxPalette.last);
  });

  test('教科を選ぶとその週の曜日別勉強時間が分かる', () {
    final store = AppStore.seed();
    final math = store.addSubject(name: '数学');
    final monday = dateOnly(store.focusedDate).subtract(Duration(days: mondayIndex(store.focusedDate)));
    store.addStudySession(
      subjectId: math.id,
      minutes: 60,
      focus: StudyFocus.high,
      at: monday,
    );
    store.addStudySession(
      subjectId: math.id,
      minutes: 30,
      focus: StudyFocus.high,
      at: monday.add(const Duration(days: 2)),
    );
    final hours = store.subjectWeekHours(math.id);
    expect(hours, hasLength(7));
    expect(hours[0], closeTo(1, 0.0001));
    expect(hours[1], 0);
    expect(hours[2], closeTo(0.5, 0.0001));
  });

  test('教科とMoneyボックスの順番を入れ替えられる', () {
    final store = AppStore.seed();
    store.boxes.clear();
    final math = store.addSubject(name: '数学');
    final english = store.addSubject(name: '英語');
    store.shiftSubject(0, 1);
    expect(store.subjects.map((s) => s.id).toList(), [english.id, math.id]);

    final food = store.addBudgetBox(
      name: '食費',
      icon: Icons.restaurant_rounded,
      color: NexusColors.boxPalette.first,
      monthlyBudget: 10000,
      renewalDay: 1,
      tags: const ['その他'],
    );
    final trip = store.addSavingsBox(
      name: '旅行',
      icon: Icons.savings_rounded,
      color: NexusColors.boxPalette.last,
      targetAmount: 50000,
      openingAmount: 0,
      tags: const ['その他'],
    );
    store.shiftBox(0, 1);
    expect(store.boxes.map((b) => b.id).toList(), [trip.id, food.id]);
  });

    test('集中タイマーは選んだ教科に学習を記録する', () {
    final store = AppStore.seed();
    store.addSubject(name: '数学');
    final english = store.addSubject(name: '英語');
    store.setTimerSubject(english.id);
    store.setTimerMinutes(5);
    store.timerAccumulatedSeconds = 60;
    store.finishTimer(focus: StudyFocus.high);
    expect(store.sessions.first.subjectId, english.id);
    expect(store.selectedTimerSubjectId, english.id);
  });

  test('テーマは7種類あり、不明なIDはミッドナイトになる', () {
    expect(NexusPalette.all, hasLength(7));
    expect(NexusPalette.byId('crimson').label, 'クリムゾン');
    expect(NexusPalette.byId('ivory').isLight, isTrue);
    expect(NexusPalette.byId('unknown').id, 'midnight');
  });

  test('テーマ設定はJSONで保存して戻せる', () {
    final saved = const UserSettings().copyWith(themeId: 'sakura', reduceMotion: true);
    final restored = UserSettings.fromJson(saved.toJson());
    expect(restored.themeId, 'sakura');
    expect(restored.reduceMotion, isTrue);
  });
}
