import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/cloud/friend_models.dart';
import 'package:nexus/core/format.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/data/models.dart';
import 'package:nexus/voice/intent_parser.dart';
import 'package:nexus/voice/voice_context.dart';
import 'package:nexus/voice/voice_dispatcher.dart';
import 'package:nexus/voice/voice_intent.dart';
import 'package:nexus/widgets/nexus_nav_bar.dart';

void main() {
  const parser = IntentParser();
  final now = DateTime(2026, 10, 6, 12, 0); // Tuesday

  VoiceParseContext ctx({
    List<VoiceNamed> boxes = const [],
    List<VoiceNamed> subjects = const [],
    List<VoiceNamed> habits = const [],
    Set<String> habitsDoneToday = const {},
    List<VoiceNamed> friends = const [],
    List<VoiceNamed> schedules = const [],
    Set<String> savingsBoxIds = const {},
  }) {
    return VoiceParseContext(
      now: now,
      boxes: boxes,
      subjects: subjects,
      habits: habits,
      habitsDoneToday: habitsDoneToday,
      friends: friends,
      schedules: schedules,
      savingsBoxIds: savingsBoxIds,
    );
  }

  test('明日18時からバイトは予定になる', () {
    final intent = parser.parse('明日18時からバイト', ctx());
    expect(intent, isA<CreateScheduleIntent>());
    final schedule = intent as CreateScheduleIntent;
    expect(schedule.title, 'バイト');
    expect(schedule.startAt, DateTime(2026, 10, 7, 18));
    expect(schedule.allDay, isFalse);
  });

  test('土曜日終日サークルは次の土曜の終日予定', () {
    final intent = parser.parse('土曜日終日サークル', ctx());
    expect(intent, isA<CreateScheduleIntent>());
    final schedule = intent as CreateScheduleIntent;
    expect(schedule.title, 'サークル');
    expect(schedule.allDay, isTrue);
    expect(dateOnly(schedule.startAt), DateTime(2026, 10, 10));
  });

  test('食費に1200円ランチは支出カード', () {
    final intent = parser.parse(
      '食費に1200円 ランチ',
      ctx(boxes: const [VoiceNamed(id: 'food', name: '食費')]),
    );
    expect(intent, isA<CreateSpendIntent>());
    final spend = intent as CreateSpendIntent;
    expect(spend.amount, 1200);
    expect(spend.boxId, 'food');
    expect(spend.title.contains('ランチ'), isTrue);
    expect(spend.kind, MoneyCardKind.spend);
  });

  test('仕送り3万円入ったは収入', () {
    final intent = parser.parse('仕送り3万円入った', ctx());
    expect(intent, isA<CreateIncomeIntent>());
    final income = intent as CreateIncomeIntent;
    expect(income.amount, 30000);
    expect(income.name, '仕送り');
    expect(dateOnly(income.depositedAt), DateTime(2026, 10, 6));
  });

  test('勉強開いてはタブ移動', () {
    final intent = parser.parse('勉強開いて', ctx());
    expect(intent, isA<NavigateTabIntent>());
    expect((intent as NavigateTabIntent).tabIndex, NexusTab.study);
  });

  test('お金を見せてはMoneyタブ', () {
    final intent = parser.parse('お金を見せて', ctx());
    expect(intent, isA<NavigateTabIntent>());
    expect((intent as NavigateTabIntent).tabIndex, NexusTab.money);
  });

  test('25分スタートはタイマー', () {
    final intent = parser.parse('25分スタート', ctx());
    expect(intent, isA<StartTimerIntent>());
    expect((intent as StartTimerIntent).minutes, 25);
  });

  test('数学でポモドーロは教科付きタイマー', () {
    final intent = parser.parse(
      '数学でポモドーロ',
      ctx(subjects: const [VoiceNamed(id: 'math', name: '数学')]),
    );
    expect(intent, isA<StartTimerIntent>());
    final timer = intent as StartTimerIntent;
    expect(timer.minutes, 25);
    expect(timer.subjectId, 'math');
  });

  test('今日の筋トレやったは習慣', () {
    final intent = parser.parse(
      '今日の筋トレやった',
      ctx(habits: const [VoiceNamed(id: 'gym', name: '筋トレ')]),
    );
    expect(intent, isA<ToggleHabitIntent>());
    final habit = intent as ToggleHabitIntent;
    expect(habit.habitId, 'gym');
    expect(habit.alreadyDone, isFalse);
  });

  test('済んでいる習慣は取り消さないフラグが立つ', () {
    final intent = parser.parse(
      '今日の筋トレやった',
      ctx(
        habits: const [VoiceNamed(id: 'gym', name: '筋トレ')],
        habitsDoneToday: const {'gym'},
      ),
    );
    expect((intent as ToggleHabitIntent).alreadyDone, isTrue);
  });

  test('日記に疲れたは日記', () {
    final intent = parser.parse('日記に疲れた', ctx());
    expect(intent, isA<SetDiaryIntent>());
    expect((intent as SetDiaryIntent).text, '疲れた');
  });

  test('今日の気分は4はチェックイン', () {
    final intent = parser.parse('今日の気分は4', ctx());
    expect(intent, isA<CheckInIntent>());
    expect((intent as CheckInIntent).mood, 4);
  });

  test('この予定を太郎に共有は表示名の完全一致だけ相手にする', () {
    final matched = parser.parse(
      'この予定を太郎に共有',
      ctx(
        friends: const [VoiceNamed(id: 'u1', name: '太郎')],
        schedules: const [VoiceNamed(id: 's1', name: 'バイト')],
      ),
    );
    expect(matched, isA<ShareItemIntent>());
    expect((matched as ShareItemIntent).viewerId, 'u1');
    expect(matched.kind, SharedKind.schedule);

    final missed = parser.parse(
      'この予定を太に共有',
      ctx(
        friends: const [VoiceNamed(id: 'u1', name: '太郎')],
        schedules: const [VoiceNamed(id: 's1', name: 'バイト')],
      ),
    );
    expect((missed as ShareItemIntent).viewerId, isEmpty);
  });

  test('金曜までに数学のレポートは提出物', () {
    final intent = parser.parse(
      '金曜までに数学のレポート',
      ctx(subjects: const [VoiceNamed(id: 'math', name: '数学')]),
    );
    expect(intent, isA<CreateAssignmentIntent>());
    final assignment = intent as CreateAssignmentIntent;
    expect(assignment.subjectId, 'math');
    expect(dateOnly(assignment.dueAt), DateTime(2026, 10, 9));
  });

  test('来週月曜に英語の試験', () {
    final intent = parser.parse('来週月曜に英語の試験', ctx());
    expect(intent, isA<CreateExamIntent>());
    final exam = intent as CreateExamIntent;
    expect(exam.title.contains('英語'), isTrue);
    expect(dateOnly(exam.examAt), DateTime(2026, 10, 12));
  });

  test('不明な発話は Unknown', () {
    final intent = parser.parse('こんにちは', ctx());
    expect(intent, isA<VoiceUnknown>());
  });

  test('Dispatcher は既存 API で予定とカードを足す', () {
    final store = AppStore.seed();
    store.addBudgetBox(
      name: '食費',
      icon: Icons.restaurant,
      color: const Color(0xFF00D4FF),
      monthlyBudget: 20000,
      tags: const ['食費'],
    );
    final food = store.boxes.first;
    final dispatcher = VoiceDispatcher(store);

    dispatcher.dispatch(
      CreateScheduleIntent(title: 'バイト', startAt: DateTime(2026, 10, 7, 18)),
    );
    expect(store.schedules.single.title, 'バイト');
    expect(store.tabIndex, NexusTab.life);

    dispatcher.dispatch(
      CreateSpendIntent(amount: 1200, at: now, boxId: food.id, title: 'ランチ'),
    );
    expect(store.cards.single.amount, 1200);
    expect(store.tabIndex, NexusTab.money);

    dispatcher.dispatch(CreateIncomeIntent(name: '仕送り', amount: 30000, depositedAt: now));
    expect(store.incomes.single.amount, 30000);
    final use = nextUseMonth(dateOnly(now));
    expect(store.incomes.single.useMonth, use.month);
  });

  test('Dispatcher はクラウドなしでは共有しない', () async {
    final store = AppStore.seed();
    store.addSchedule(title: 'バイト', startAt: DateTime(2026, 10, 7, 18));
    final result = await VoiceDispatcher(store).dispatch(
      ShareItemIntent(
        kind: SharedKind.schedule,
        viewerName: '太郎',
        viewerId: 'u1',
        sourceLocalId: store.schedules.single.id,
        title: 'バイト',
      ),
    );
    expect(result.ok, isFalse);
    expect(result.message.contains('ログイン'), isTrue);
  });

  test('済んでいる習慣は Dispatcher が取り消さない', () async {
    final store = AppStore.seed();
    final habit = store.addHabit(name: '筋トレ', icon: Icons.fitness_center, color: const Color(0xFF3DFF8A));
    store.toggleHabit(habit.id, dateOnly(now));
    expect(habit.doneOn(now) || store.habits.first.doneOn(now), isTrue);
    final result = await VoiceDispatcher(store).dispatch(
      ToggleHabitIntent(habitId: habit.id, habitName: '筋トレ', alreadyDone: true),
    );
    expect(result.ok, isFalse);
    expect(store.habits.first.doneOn(now), isTrue);
  });

  test('voiceContextOf はストアの名前を渡す', () {
    final store = AppStore.seed();
    store.addBudgetBox(
      name: '食費',
      icon: Icons.restaurant,
      color: const Color(0xFF00D4FF),
      monthlyBudget: 1000,
      tags: const [],
    );
    store.addSubject(name: '数学');
    store.addHabit(name: '筋トレ', icon: Icons.fitness_center, color: const Color(0xFF3DFF8A));
    final context = voiceContextOf(store, now: now);
    expect(context.boxes.single.name, '食費');
    expect(context.subjects.single.name, '数学');
    expect(context.habits.single.name, '筋トレ');
  });
}
