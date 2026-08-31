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

  test('教科を消してもグラフに勉強時間は残る', () {
    final store = AppStore.seed();
    final math = store.addSubject(name: '数学');
    store.addStudySession(subjectId: math.id, minutes: 60, focus: StudyFocus.high);
    final hours = store.weekStudyHoursFor(store.studyWeek);
    store.deleteSubject(math.id);
    expect(store.visibleSubjects, isEmpty);
    expect(store.weekStudyHoursFor(store.studyWeek), hours);
    expect(store.weekChartSubjects(store.studyWeek).any((s) => s.id == math.id), isTrue);
    expect(
      store.weekStackedHours(store.studyWeek).any((day) => day.any((value) => value > 0)),
      isTrue,
    );
  });

  test('Studyの週を動かしてもHomeとMoneyの日付は変わらない', () {
    final store = AppStore.seed();
    final today = store.focusedDate;
    final money = store.moneyMonth;
    store.shiftStudyWeek(-1);
    expect(store.focusedDate, today);
    expect(store.moneyMonth, money);
    expect(store.studyWeekMonday, weekMonday(today).subtract(const Duration(days: 7)));
    expect(weekDaySpan(DateTime(2026, 8, 24)), '8月24日ー8月30日');
    expect(weekDaySpan(DateTime(2026, 8, 31)), '8月31日ー9月6日');
  });

  test('学習記録は更新と削除ができる', () {
    final store = AppStore.seed();
    final math = store.addSubject(name: '数学');
    store.addStudySession(subjectId: math.id, minutes: 30, focus: StudyFocus.high);
    final session = store.sessions.single;
    store.updateStudySession(session.copyWith(minutes: 90, focus: StudyFocus.peak));
    expect(store.sessions.single.minutes, 90);
    expect(store.sessions.single.focus, StudyFocus.peak);
    expect(store.totalStudyHours, closeTo(1.5, 0.0001));
    store.deleteStudySession(session.id);
    expect(store.sessions, isEmpty);
    expect(store.totalStudyHours, 0);
  });

  test('1分の学習は1分と表示される', () {
    final store = AppStore.seed();
    final math = store.addSubject(name: '数学');
    store.addStudySession(subjectId: math.id, minutes: 1, focus: StudyFocus.high);
    expect(store.weekStudyHours, closeTo(1 / 60, 0.0001));
    expect(formatStudyHours(store.weekStudyHours), '1分');
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
      tags: const ['その他'],
    );
    expect(store.money.expense, 0);
    expect(store.money.balance, 100000);
    store.updateSettings(store.settings.copyWith(deductBudgetFromBalance: true));
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
      tags: const ['外食'],
    );
    final train = store.addBudgetBox(
      name: '交通費',
      icon: Icons.train_rounded,
      color: const Color(0xFF9B6BFF),
      monthlyBudget: 5000,
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

  test('予算ボックスは作った月だけに出る', () {
    final store = AppStore.seed();
    store.boxes.clear();
    store.addBudgetBox(
      name: '食費',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFF3DA9FC),
      monthlyBudget: 30000,
      tags: const ['外食'],
    );
    expect(store.visibleBoxes.where((b) => !b.isSavings), hasLength(1));
    store.shiftMoneyMonth(-1);
    expect(store.visibleBoxes.where((b) => !b.isSavings), isEmpty);
    store.shiftMoneyMonth(1);
    expect(store.visibleBoxes.single.name, '食費');
  });

  test('月を進めても予算ボックスは自動では入らない', () {
    final store = AppStore.seed();
    store.boxes.clear();
    store.addBudgetBox(
      name: '食費',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFF3DA9FC),
      monthlyBudget: 30000,
      tags: const ['外食'],
    );
    store.shiftMoneyMonth(1);
    expect(store.visibleBoxes.where((b) => !b.isSavings), isEmpty);
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
      tags: const ['ご飯', 'その他'],
    );
    final friend = store.boxes.last;
    final card = store.addMoneyCard(
      boxId: friend.id,
      title: 'サイゼリヤ',
      amount: 1480,
      at: store.focusedDate,
      tag: 'ご飯',
    );
    expect(store.spentOfBox(friend.id, month: store.moneyMonth), 1480);
    store.updateMoneyCard(card.copyWith(boxId: korea.id, kind: MoneyCardKind.saveOut));
    expect(store.spentOfBox(friend.id, month: store.moneyMonth), 0);
    expect(store.savingsBalance(korea), 72000 - 1480);
    store.shiftMoneyMonth(1);
    expect(store.visibleBoxes.any((b) => b.id == korea.id), isTrue);
    expect(store.visibleBoxes.any((b) => b.id == friend.id), isFalse);
    expect(store.visibleBoxes.where((b) => !b.isSavings), isEmpty);
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
      tags: const ['その他'],
    );
    final food = store.addBudgetBox(
      name: '食費',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFF3DA9FC),
      monthlyBudget: 30000,
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

  test('テーマはホワイトとブラックに5色ずつあり、古いIDは移行される', () {
    expect(NexusPalette.all, hasLength(10));
    expect(NexusPalette.byId('crimson').id, 'black-crimson');
    expect(NexusPalette.byId('ivory').isLight, isTrue);
    expect(NexusPalette.byId('unknown').id, 'white-midnight');
  });

  test('テーマ設定はJSONで保存して戻せる', () {
    final saved = const UserSettings().copyWith(themeId: 'sakura', reduceMotion: true);
    final restored = UserSettings.fromJson(saved.toJson());
    expect(restored.themeId, 'white-rose');
    expect(restored.reduceMotion, isTrue);
  });

  test('勉強時間でレベルと経験値が進む', () {
    final store = AppStore.seed();
    final math = store.addSubject(name: '数学');
    expect(store.level, 1);
    expect(store.levelProgress, 0);
    store.addStudySession(subjectId: math.id, minutes: 30, focus: StudyFocus.high);
    expect(store.level, 1);
    expect(store.levelProgress, closeTo(0.5, 0.001));
    store.addStudySession(subjectId: math.id, minutes: 30, focus: StudyFocus.high);
    expect(store.level, 2);
    expect(store.levelProgress, 0);
  });

  test('日記は日付ごとに残る', () {
    final store = AppStore.seed();
    final today = store.lifeDate;
    store.setDiary('今日の話');
    store.setLifeDate(today.subtract(const Duration(days: 1)));
    expect(store.diary, isEmpty);
    store.setDiary('昨日の話');
    store.setLifeDate(today);
    expect(store.diary, '今日の話');
    store.setLifeDate(today.subtract(const Duration(days: 1)));
    expect(store.diary, '昨日の話');
  });

  test('Moneyの月を動かしてもHomeの日付は変わらない', () {
    final store = AppStore.seed();
    final today = store.focusedDate;
    store.shiftMoneyMonth(-1);
    expect(store.moneyMonth.month, DateTime(today.year, today.month - 1).month);
    expect(store.focusedDate, today);
    store.shiftMoneyMonth(1);
    expect(store.moneyMonth.month, today.month);
  });

  test('Lifeの月移動で今月に戻ると今日が選ばれる', () {
    final store = AppStore.seed();
    final today = dateOnly(DateTime.now());
    store.shiftLifeMonth(-1);
    expect(store.lifeDate.day, 1);
    expect(store.lifeDate.month, DateTime(today.year, today.month - 1).month);
    store.shiftLifeMonth(1);
    expect(store.lifeDate, today);
  });

  test('収入は更新と削除ができる', () {
    final store = AppStore.seed();
    store.incomes.clear();
    store.addIncome(
      name: '給料',
      amount: 140000,
      depositedAt: store.focusedDate,
      useYear: store.focusedDate.year,
      useMonth: store.focusedDate.month,
    );
    final id = store.incomes.single.id;
    store.updateIncome(store.incomes.single.copyWith(name: 'ボーナス', amount: 20000));
    expect(store.incomes.single.name, 'ボーナス');
    expect(store.incomes.single.amount, 20000);
    expect(store.incomeForMonth(store.focusedDate), 20000);
    store.deleteIncome(id);
    expect(store.incomes, isEmpty);
    expect(store.incomeForMonth(store.focusedDate), 0);
  });

  test('支出カードはタグで探せ、検索にもヒットする', () {
    final store = AppStore.seed();
    store.boxes.clear();
    store.cards.clear();
    final food = store.addBudgetBox(
      name: '食費',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFF3DA9FC),
      monthlyBudget: 30000,
      tags: const ['外食', 'その他'],
    );
    store.addMoneyCard(
      boxId: food.id,
      title: 'サイゼリヤ',
      amount: 1480,
      at: store.focusedDate,
      tag: '外食',
    );
    store.addMoneyCard(
      boxId: food.id,
      title: 'スーパー',
      amount: 2200,
      at: store.focusedDate,
      tag: 'その他',
    );
    expect(store.expenseTags, containsAll(['外食', 'その他']));
    expect(store.spendHistory, hasLength(2));
    expect(queryMatches('サイゼ', ['サイゼリヤ', '外食', '食費']), isTrue);
    expect(queryMatches('ホテル', ['サイゼリヤ', '外食', '食費']), isFalse);
    store.deleteMoneyCard(store.spendHistory.firstWhere((c) => c.title == 'サイゼリヤ').id);
    expect(store.spendHistory.single.title, 'スーパー');
  });

  test('収入と支出の記録はその月だけを出す', () {
    final store = AppStore.seed();
    store.boxes.clear();
    store.cards.clear();
    store.incomes.clear();
    final august = DateTime(2026, 8, 1);
    final september = DateTime(2026, 9, 1);
    store.moneyMonth = august;
    final food = store.addBudgetBox(
      name: '食費',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFF3DA9FC),
      monthlyBudget: 30000,
      tags: const ['外食'],
      month: august,
    );
    store.addIncome(
      name: '8月の給料',
      amount: 140000,
      depositedAt: DateTime(2026, 8, 25),
      useYear: 2026,
      useMonth: 8,
    );
    store.addIncome(
      name: '9月の給料',
      amount: 150000,
      depositedAt: DateTime(2026, 9, 25),
      useYear: 2026,
      useMonth: 9,
    );
    store.addMoneyCard(
      boxId: food.id,
      title: '8月の外食',
      amount: 1480,
      at: DateTime(2026, 8, 10),
      tag: '外食',
    );
    store.addMoneyCard(
      boxId: food.id,
      title: '9月の外食',
      amount: 2200,
      at: DateTime(2026, 9, 3),
      tag: '外食',
    );
    expect(store.incomesInMonth(august).map((e) => e.name), ['8月の給料']);
    expect(store.spendCardsInMonth(august).map((c) => c.title), ['8月の外食']);
    expect(store.expenseTagsInMonth(august), contains('外食'));
    store.moneyMonth = september;
    expect(store.incomesInMonth(september).map((e) => e.name), ['9月の給料']);
    expect(store.spendCardsInMonth(september).map((c) => c.title), ['9月の外食']);
  });

  test('習慣は更新と削除ができる', () {
    final store = AppStore.seed();
    final added = store.addHabit(
      name: '読書',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF00D4FF),
    );
    store.updateHabit(added.copyWith(name: '朝の読書'));
    expect(store.habits.firstWhere((h) => h.id == added.id).name, '朝の読書');
    store.deleteHabit(added.id);
    expect(store.habits.any((h) => h.id == added.id), isFalse);
  });
}
