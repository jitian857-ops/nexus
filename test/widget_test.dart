import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus/app/app.dart';
import 'package:nexus/app/theme.dart';
import 'package:nexus/cloud/nexus_cloud.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/data/models.dart';
import 'package:nexus/domain/money_calc.dart';
import 'package:nexus/domain/review_scheduler.dart';
import 'package:nexus/screens/auth/login_page.dart';
import 'package:nexus/screens/study/focus_timer_page.dart';
import 'package:nexus/widgets/nexus_nav_bar.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSignedInApp(WidgetTester tester) async {
    await tester.pumpWidget(const NexusApp());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('今日の予定').evaluate().isNotEmpty) return;
    }
    fail('ホーム画面が出ませんでした');
  }

  testWidgets('5タブを切り替えられる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpSignedInApp(tester);

    expect(find.text('蒼井 ユウ'), findsWidgets);
    expect(find.text('今日の予定'), findsOneWidget);

    Future<void> tapTab(String label) async {
      await tester.tap(find.descendant(of: find.byType(NexusNavBar), matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    await tapTab('Study');
    expect(find.text('総勉強時間'), findsOneWidget);

    await tapTab('Life');
    expect(find.text('カレンダー'), findsOneWidget);
    expect(find.text('書く'), findsNothing);

    await tapTab('Money');
    expect(find.text('収入を追加'), findsOneWidget);
    expect(find.text('予算を差し引いて表示'), findsOneWidget);
    expect(find.text('ボックスを追加'), findsOneWidget);
    expect(find.text('カードを追加'), findsOneWidget);
    expect(find.text('支払予定を追加'), findsOneWidget);

    await tester.tap(find.text('収入 ¥0'));
    await tester.pumpAndSettle();
    expect(find.textContaining('の収入'), findsWidgets);
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('支出 ¥0'));
    await tester.pumpAndSettle();
    expect(find.textContaining('の支出'), findsWidgets);
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    await tapTab('設定');
    expect(find.text('設定'), findsWidgets);
    expect(find.text('ホワイト'), findsOneWidget);
    expect(find.text('ブラック'), findsOneWidget);
    expect(find.text('ミッドナイト'), findsWidgets);
    expect(find.text('サンセット'), findsOneWidget);
    expect(find.text('クリムゾン'), findsOneWidget);
    expect(find.text('ログアウト'), findsOneWidget);
    expect(find.text('メールボックス'), findsOneWidget);
    expect(find.text('保管庫'), findsOneWidget);
  });

  testWidgets('ログインと新規登録の画面がある', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cloud = NexusCloud();
    cloud.ready = true;
    await tester.pumpWidget(
      CloudScope(
        cloud: cloud,
        child: MaterialApp(
          theme: NexusTheme.of(NexusPalette.byId('white-midnight')),
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('ログイン'), findsWidgets);
    expect(find.text('新規登録'), findsOneWidget);
    expect(find.text('パスワードを忘れた'), findsOneWidget);

    await tester.tap(find.text('新規登録'));
    await tester.pump();
    expect(find.text('職業'), findsOneWidget);
    expect(find.text('登録する'), findsOneWidget);

    await tester.tap(find.text('パスワードを忘れた'));
    await tester.pump();
    expect(find.text('コードを送る'), findsOneWidget);
  });

  testWidgets('集中タイマーで教科を選べる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore.seed();
    store.addSubject(name: '数学');
    final english = store.addSubject(name: '英語');

    await tester.pumpWidget(
      AppScope(
        store: store,
        child: MaterialApp(
          theme: NexusTheme.of(NexusPalette.byId(store.settings.themeId)),
          home: const FocusTimerPage(),
        ),
      ),
    );
    await tester.pump();
    expect(store.selectedTimerSubjectId, isNot(english.id));
    await tester.tap(find.text('英語'));
    await tester.pump();
    expect(store.selectedTimerSubjectId, english.id);

    await tester.pumpWidget(const SizedBox.shrink());
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

  test('既定の残高は実支出だけを引き、予算差し引きは切替できる', () {
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
    final actual = MoneyCalc.compute(
      income: 40000,
      boxes: boxes,
      payments: payments,
      today: DateTime(2026, 8, 14),
    );
    expect(actual.expense, 3600);
    expect(actual.balance, 36400);

    final budgeted = MoneyCalc.compute(
      income: 40000,
      boxes: boxes,
      payments: payments,
      today: DateTime(2026, 8, 14),
      deductBudget: true,
    );
    expect(budgeted.expense, 10000);
    expect(budgeted.balance, 30000);
    expect(budgeted.spendableToday, 1611);
    expect(budgeted.spendableWeek, 1611 * 7);
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
