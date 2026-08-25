import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nexus/app/app.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/data/models.dart';
import 'package:nexus/domain/money_calc.dart';
import 'package:nexus/domain/review_scheduler.dart';
import 'package:nexus/widgets/nexus_nav_bar.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('5タブを切り替えられる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NexusApp());

    expect(find.text('蒼井 ユウ'), findsWidgets);
    expect(find.text('今日の予定'), findsOneWidget);

    Future<void> tapTab(String label) async {
      await tester.tap(find.descendant(of: find.byType(NexusNavBar), matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    await tapTab('Study');
    expect(find.text('総勉強時間'), findsOneWidget);

    await tapTab('Life');
    expect(find.text('毎日を、整える。'), findsOneWidget);

    await tapTab('Money');
    expect(find.text('未来のために、今日を知る。'), findsOneWidget);
    expect(find.text('収入を追加'), findsOneWidget);
    expect(find.text('ボックスを追加'), findsOneWidget);
    expect(find.text('カードを追加'), findsOneWidget);
    expect(find.text('支払予定を追加'), findsOneWidget);

    await tapTab('設定');
    expect(find.text('Nexusを、自分らしく。'), findsOneWidget);
  });

  test('問題記録で1・5日の復習カードが作られる', () {
    final store = AppStore.seed();
    final math = store.addSubject(name: '数学');
    final before = store.reviewCards.length;
    final problem = store.addProblem(subjectId: math.id, title: '確認問題');
    final created = store.reviewCards.where((c) => c.problemId == problem.id).toList();
    expect(store.reviewCards.length, before + 2);
    expect(created.map((c) => c.intervalStep), [1, 5]);
    expect(
      created.map((c) => c.dueAt.difference(problem.learnedAt).inDays),
      [1, 5],
    );
  });

  test('ネグモの提案は承認するまで予定を変えない', () {
    final store = AppStore.seed();
    store.addSchedule(title: 'テレビ', startAt: DateTime(2026, 8, 14, 20));
    store.createDefaultProposal();
    final before = store.schedules.firstWhere((s) => s.title == 'テレビ').startAt;
    expect(store.proposal?.status, ProposalStatus.pending);
    expect(store.schedules.firstWhere((s) => s.title == 'テレビ').startAt, before);
    store.approveProposal();
    expect(store.proposal?.status, ProposalStatus.approved);
    expect(
      store.schedules.firstWhere((s) => s.title == 'テレビ').startAt,
      before.add(const Duration(minutes: 30)),
    );
  });

  test('Moneyの残高は収入−支出、使える額は残日数で割る', () {
    final boxes = [
      const BudgetBox(
        id: 'a',
        name: '食費',
        monthlyBudget: 10000,
        spent: 3600,
        color: Color(0xFF000000),
        icon: Icons.restaurant,
      ),
    ];
    final payments = [
      PaymentPlan(id: 'p', title: 'x', amount: 1000, dueAt: DateTime(2026, 8, 25)),
    ];
    final snap = MoneyCalc.compute(
      income: 40000,
      boxes: boxes,
      payments: payments,
      today: DateTime(2026, 8, 14),
    );
    expect(snap.expense, 3600);
    expect(snap.balance, 36400);
    expect(snap.spendableToday >= 0, isTrue);
  });

  test('ReviewScheduler は learnedAt から 1/5 日', () {
    final cards = ReviewScheduler.cardsFor(
      problemId: 'p',
      learnedAt: DateTime(2026, 8, 14),
      nextId: () => 'id',
    );
    expect(cards.map((c) => c.intervalStep).toList(), [1, 5]);
  });
}
