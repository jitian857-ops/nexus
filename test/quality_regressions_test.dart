import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus/app/theme.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/data/models.dart';
import 'package:nexus/screens/money/money_screen.dart';
import 'package:nexus/screens/study/study_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpScreen(
    WidgetTester tester,
    AppStore store,
    Widget screen,
  ) async {
    await tester.pumpWidget(
      AppScope(
        store: store,
        child: MaterialApp(
          theme: NexusTheme.dark,
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('教科の新しい並替えコールバックは前後移動と非表示教科を保持する', (tester) async {
    final store = AppStore.seed();
    final a = store.addSubject(name: 'A');
    final hidden = store.addSubject(name: 'Hidden');
    final b = store.addSubject(name: 'B');
    final c = store.addSubject(name: 'C');
    store.deleteSubject(hidden.id);
    await pumpScreen(tester, store, const StudyScreen());
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(list.onReorderItem, isNotNull);
    list.onReorderItem!(0, 2);
    expect(store.visibleSubjects.map((s) => s.id), [b.id, c.id, a.id]);
    expect(store.subjects[1].id, hidden.id);
    list.onReorderItem!(2, 0);
    expect(store.visibleSubjects.map((s) => s.id), [a.id, b.id, c.id]);
    list.onReorderItem!(1, 1);
    expect(store.visibleSubjects.map((s) => s.id), [a.id, b.id, c.id]);
  });

  testWidgets('Moneyの新しい並替えコールバックは前後移動と同位置を保持する', (tester) async {
    final store = AppStore.seed();
    store.boxes.clear();
    final boxes = [
      for (final name in ['A', 'B', 'C'])
        store.addBudgetBox(
          name: name,
          icon: Icons.wallet,
          color: Colors.blue,
          monthlyBudget: 1000,
          tags: const [],
        ),
    ];
    await pumpScreen(tester, store, const MoneyScreen());
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(list.onReorderItem, isNotNull);
    list.onReorderItem!(0, 2);
    expect(store.visibleBoxes.map((b) => b.id), [
      boxes[1].id,
      boxes[2].id,
      boxes[0].id,
    ]);
    list.onReorderItem!(2, 0);
    expect(store.visibleBoxes.map((b) => b.id), boxes.map((b) => b.id));
    list.onReorderItem!(1, 1);
    expect(store.visibleBoxes.map((b) => b.id), boxes.map((b) => b.id));
  });

  testWidgets('学習編集の呼出元が閉じた後は削除確認を開かない', (tester) async {
    final store = AppStore.seed();
    final subject = store.addSubject(name: '数学');
    store.addStudySession(
      subjectId: subject.id,
      minutes: 30,
      focus: StudyFocus.three,
    );
    final session = store.sessions.single;
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    Future<void>? editing;
    await pumpScreen(
      tester,
      store,
      ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, show, _) => show
            ? Builder(
                builder: (origin) {
                  return TextButton(
                    onPressed: () {
                      editing = openStudySessionForm(
                        origin,
                        store,
                        existing: session,
                      );
                    },
                    child: const Text('編集開始'),
                  );
                },
              )
            : const SizedBox.shrink(),
      ),
    );
    await tester.tap(find.text('編集開始'));
    await tester.pumpAndSettle();
    expect(find.text('学習を編集'), findsOneWidget);
    visible.value = false;
    await tester.pump();
    final completion = expectLater(editing!, completes);
    Navigator.of(tester.element(find.text('学習を編集'))).pop(false);
    await tester.pumpAndSettle();
    await completion;
    expect(store.sessions.map((s) => s.id), [session.id]);
    expect(find.text('学習を削除'), findsNothing);
  });
}
