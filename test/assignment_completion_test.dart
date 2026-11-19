import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/app/theme.dart';
import 'package:nexus/cloud/nexus_cloud.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/screens/study/study_screen.dart';
import 'package:nexus/widgets/nexus_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  testWidgets('overdue assignment can be completed, restored and reopened', (
    tester,
  ) async {
    final previous = SharedPreferencesStorePlatform.instance;
    final disk = InMemorySharedPreferencesStore.empty();
    SharedPreferencesStorePlatform.instance = disk;
    SharedPreferences.resetStatic();
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = previous;
      SharedPreferences.resetStatic();
    });
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime(2026, 11, 12);
    final due = DateTime(2026, 11, 10);
    final clouds = <NexusCloud>[];
    final stores = <AppStore>[];
    Future<AppStore> load() async {
      SharedPreferences.resetStatic();
      final c = NexusCloud();
      await c.enterGuestSession();
      clouds.add(c);
      final s = AppStore.seed();
      await s.attachCloud(c);
      stores.add(s);
      s.goTo(NexusTab.study);
      s.focusedDate = today;
      await tester.pumpWidget(
        AppScope(
          store: s,
          child: MaterialApp(
            theme: NexusTheme.dark,
            home: const Scaffold(body: StudyScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return s;
    }

    final original = await load();
    final subject = original.addSubject(name: '数学');
    original.addAssignment(subjectId: subject.id, title: '合成レポート', dueAt: due);
    original.addAssignment(
      subjectId: subject.id,
      title: '別の提出物',
      dueAt: DateTime(2026, 11, 15),
    );
    await tester.pumpAndSettle();
    final id = original.assignments.first.id;
    final target = find.byWidgetPredicate(
      (w) => w is Checkbox && w.semanticLabel == '合成レポートの完了',
    );
    Future<void> reveal() async {
      await tester.scrollUntilVisible(
        find.text('合成レポート'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    Future<void> expectSaved(bool expected) async {
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      final data = await disk.getAll();
      final device = jsonDecode(
        data['flutter.nexus_user_data_v2_guest'] as String,
      );
      final live = jsonDecode(
        data['flutter.nexus_cloud_v1'] as String,
      )['live']['guest'];
      for (final bundle in [device, live]) {
        final rows = bundle['assignments'] as List;
        expect(rows.length, 2);
        expect(rows.first['id'], id);
        expect(rows.first['subjectId'], subject.id);
        expect(rows.first['title'], '合成レポート');
        expect(DateTime.parse(rows.first['dueAt']), due);
        expect(rows.first['done'], expected);
        expect(rows.last['done'], false);
      }
    }

    Future<void> coldOpen(bool expected) async {
      // A fresh widget and store read disk before the old store is disposed.
      await tester.pumpWidget(const SizedBox.shrink());
      final fresh = await load();
      await reveal();
      expect(fresh.assignments.first.done, expected);
      expect(tester.widget<Checkbox>(target).value, expected);
      expect(find.text('期限切れ 2日'), expected ? findsNothing : findsOneWidget);
      expect(find.text('完了'), expected ? findsOneWidget : findsNothing);
      expect(find.text('11/10まで'), findsOneWidget);
    }

    await reveal();
    expect(find.text('期限切れ 2日'), findsOneWidget);
    expect(
      target,
      findsOneWidget,
      reason: 'the assignment row exposes a completion checkbox',
    );
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.text('完了'), findsOneWidget);
    await expectSaved(true);
    await coldOpen(true);
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.text('期限切れ 2日'), findsOneWidget);
    await expectSaved(false);
    await coldOpen(false);
    await tester.pumpWidget(const SizedBox.shrink());
    for (final s in stores) {
      s.dispose();
      await tester.pump();
    }
    for (final c in clouds) {
      c.dispose();
    }
  });
}
