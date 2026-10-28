import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/app/theme.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/screens/study/study_screen.dart';

void main() {
  Future<AppStore> setup(WidgetTester tester) async {
    final s = AppStore.seed();
    addTearDown(s.dispose);
    s.addSubject(name: '数学');
    s.addSubject(name: '英語');
    await tester.pumpWidget(
      AppScope(
        store: s,
        child: MaterialApp(
          theme: NexusTheme.dark,
          home: const Scaffold(body: StudyScreen()),
        ),
      ),
    );
    await tester.pump();
    return s;
  }

  void action(
    WidgetTester tester,
    SemanticsNode n,
    SemanticsAction a, [
    Object? args,
  ]) => tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
    n.id,
    a,
    args,
  );
  testWidgets(
    'subject AX opens week editor, delete has a separate named action',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final s = await setup(tester);
        final body = tester.getSemantics(find.text('数学'));
        action(tester, body, SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(find.text('教科を削除'), findsNothing);
        expect(find.text('数字を押すとその日の勉強時間を編集できます'), findsOneWidget);
        Navigator.of(tester.element(find.text('数字を押すとその日の勉強時間を編集できます'))).pop();
        await tester.pumpAndSettle();
        final deletion = tester.getSemantics(find.bySemanticsLabel('数学を削除'));
        expect(deletion.id, isNot(tester.getSemantics(find.text('数学')).id));
        action(tester, deletion, SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(find.text('教科を削除'), findsOneWidget);
        expect(find.text('「数学」を削除します。'), findsOneWidget);
        expect(s.visibleSubjects, hasLength(2));
      } finally {
        handle.dispose();
      }
    },
  );
  testWidgets('pointer opening and reorder custom actions survive', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      final s = await setup(tester);
      await tester.tap(find.text('数学'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('数字を押すとその日の勉強時間を編集できます'), findsOneWidget);
      Navigator.of(tester.element(find.text('数字を押すとその日の勉強時間を編集できます'))).pop();
      await tester.pumpAndSettle();
      void move(String label) {
        SemanticsNode? n = tester.getSemantics(find.text('数学'));
        while (n != null &&
            (n.getSemanticsData().customSemanticsActionIds ?? []).isEmpty) {
          n = n.parent;
        }
        expect(n, isNotNull);
        final ids = n!.getSemanticsData().customSemanticsActionIds!;
        final id = ids.singleWhere(
          (id) => CustomSemanticsAction.getAction(id)!.label == label,
        );
        action(tester, n, SemanticsAction.customAction, id);
      }

      final loc = WidgetsLocalizations.of(tester.element(find.text('数学')));
      move(loc.reorderItemToEnd);
      await tester.pumpAndSettle();
      expect(s.visibleSubjects.map((e) => e.name), ['英語', '数学']);
      move(loc.reorderItemToStart);
      await tester.pumpAndSettle();
      expect(s.visibleSubjects.map((e) => e.name), ['数学', '英語']);
    } finally {
      handle.dispose();
    }
  });
}
