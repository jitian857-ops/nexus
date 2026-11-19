import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/app/app.dart';
import 'package:nexus/cloud/nexus_cloud.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/widgets/nexus_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  for (final form in ['budget', 'savings', 'tag', 'payment', 'exam', 'goal']) {
    for (final save in [true, false]) {
      testWidgets('$form focused exit save=$save', (tester) async {
        final previous = SharedPreferencesStorePlatform.instance;
        final disk = InMemorySharedPreferencesStore.empty();
        SharedPreferencesStorePlatform.instance = disk;
        SharedPreferences.resetStatic();
        addTearDown(() {
          SharedPreferencesStorePlatform.instance = previous;
          SharedPreferences.resetStatic();
        });
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const NexusApp());
        final nav = find.byType(NexusNavBar);
        for (var i = 0; i < 40 && nav.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await CloudScope.read(tester.element(nav)).enterGuestSession();
        await tester.pumpAndSettle();
        final store = AppScope.read(tester.element(nav));
        if (form == 'tag') {
          store.addBudgetBox(
            name: '合成箱',
            icon: Icons.restaurant_rounded,
            color: Colors.blue,
            monthlyBudget: 30000,
            tags: ['既存'],
          );
        }
        final study = form == 'exam' || form == 'goal';
        await tester.tap(
          find.descendant(
            of: nav,
            matching: find.text(study ? 'Study' : 'Money'),
          ),
        );
        await tester.pumpAndSettle();
        final entry = switch (form) {
          'budget' || 'savings' => 'ボックスを追加',
          'tag' => 'カードを追加',
          'payment' => '支払予定を追加',
          'exam' => '試験日を追加',
          _ => '目標を追加',
        };
        await tester.scrollUntilVisible(
          find.text(entry),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(entry));
        await tester.pumpAndSettle();
        if (form == 'budget' || form == 'savings') {
          await tester.tap(find.text(form == 'budget' ? '予算ボックス' : '貯蓄ボックス'));
          await tester.pumpAndSettle();
        }
        if (form == 'tag') {
          await tester.ensureVisible(find.text('＋タグを追加'));
          await tester.tap(find.text('＋タグを追加'));
          await tester.pumpAndSettle();
        }
        Future<void> input(String label, String value) async {
          final field = find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == label,
          );
          await tester.ensureVisible(field);
          await tester.enterText(field, value);
        }

        final nameLabel = switch (form) {
          'budget' || 'savings' => 'ボックス名',
          'tag' => 'タグ名',
          'payment' => '支払い名',
          'exam' => '科目・試験名',
          _ => '目標名（例: TOEIC 800）',
        };
        await input(nameLabel, '合成一件');
        if (form == 'budget') await input('月間予算', '12000');
        if (form == 'savings') {
          await input('目標金額', '20000');
          await input('現在金額', '3000');
        }
        if (form == 'payment') await input('金額', '1500');
        if (form == 'goal') await input('目標値（任意）', '800');
        if (save) {
          final button = switch (form) {
            'budget' || 'savings' => '作成',
            'payment' => '保存',
            'goal' => 'ロードマップを作る',
            _ => '追加',
          };
          final target = find.widgetWithText(FilledButton, button);
          await tester.ensureVisible(target);
          await tester.tap(target);
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (form == 'tag') {
          // Tag persistence is independent of saving the surrounding expense.
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(store.cards, isEmpty);
        }
        expect(find.byType(TextField), findsNothing);
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump();
        final data = await disk.getAll();
        final key = switch (form) {
          'budget' || 'savings' || 'tag' => 'boxes',
          'payment' => 'payments',
          'exam' => 'exams',
          _ => 'goals',
        };
        final bundles = [
          jsonDecode(data['flutter.nexus_user_data_v2_guest'] as String),
          jsonDecode(data['flutter.nexus_cloud_v1'] as String)['live']['guest'],
        ];
        void check(Map<String, dynamic> bundle) {
          final list = bundle[key] as List;
          expect(
            list.length,
            form == 'tag'
                ? 1
                : save
                ? 1
                : 0,
          );
          if (form == 'tag') {
            expect(list.single['tags'], save ? ['既存', '合成一件'] : ['既存']);
          } else if (save) {
            final item = list.single;
            expect(
              item[form == 'budget' || form == 'savings' ? 'name' : 'title'],
              '合成一件',
            );
            if (form == 'budget') expect(item['monthlyBudget'], 12000);
            if (form == 'savings') {
              expect(item['targetAmount'], 20000);
              expect(item['openingAmount'], 3000);
            }
            if (form == 'payment') expect(item['amount'], 1500);
            if (form == 'goal') expect(item['target'], 800);
          }
        }

        for (final bundle in bundles) {
          check(Map<String, dynamic>.from(bundle));
        }
        expect(bundles.first[key], bundles.last[key]);
        SharedPreferences.resetStatic();
        final cloud = NexusCloud();
        await cloud.enterGuestSession();
        final restored = AppStore.seed();
        await restored.attachCloud(cloud);
        check(restored.toCloudMap());
        expect(restored.toCloudMap()[key], bundles.first[key]);
        restored.dispose();
        cloud.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}
