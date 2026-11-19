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
  for (final tab in ['Money', 'Study', 'Life']) {
    testWidgets(
      '$tab form releases focused text fields after save and dismissal',
      (tester) async {
        final before = SharedPreferencesStorePlatform.instance;
        final disk = InMemorySharedPreferencesStore.empty();
        SharedPreferencesStorePlatform.instance = disk;
        SharedPreferences.resetStatic();
        addTearDown(() {
          SharedPreferencesStorePlatform.instance = before;
          SharedPreferences.resetStatic();
        });
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const NexusApp());
        for (
          var i = 0;
          i < 40 && find.byType(NexusNavBar).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final nav = find.byType(NexusNavBar);
        await CloudScope.read(tester.element(nav)).enterGuestSession();
        await tester.pumpAndSettle();
        final store = AppScope.read(tester.element(nav));
        expect(store.dataUid, 'guest');
        if (tab == 'Study') {
          store.addSubject(name: '合成');
          await tester.pump(const Duration(milliseconds: 800));
        }
        await tester.tap(find.descendant(of: nav, matching: find.text(tab)));
        await tester.pumpAndSettle();
        Future<void> open() async {
          final title = tab == 'Money'
              ? '収入を追加'
              : tab == 'Study'
              ? '提出物を追加'
              : '習慣チェーン';
          await tester.scrollUntilVisible(
            find.text(title),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          if (tab == 'Life') {
            final row = find
                .ancestor(
                  of: find.text(title),
                  matching: find.byWidgetPredicate(
                    (w) => w is Row && w.children.any((c) => c is IconButton),
                  ),
                )
                .first;
            await tester.tap(
              find.descendant(of: row, matching: find.byType(IconButton)).first,
            );
          } else {
            await tester.tap(find.text(title));
          }
          await tester.pumpAndSettle();
        }

        final key = tab == 'Money'
            ? 'incomes'
            : tab == 'Study'
            ? 'assignments'
            : 'habits';
        final field = tab == 'Money'
            ? '収入名'
            : tab == 'Study'
            ? '提出物名'
            : '習慣名';
        final input = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == field,
        );
        Future<void> checkSaved() async {
          await tester.pump(const Duration(milliseconds: 800));
          await tester.pump();
          final data = await disk.getAll();
          if (tab == 'Study') expect(store.assignments.single.title, '合成一件');
          final bundles = [
            jsonDecode(data['flutter.nexus_user_data_v2_guest'] as String),
            jsonDecode(
              data['flutter.nexus_cloud_v1'] as String,
            )['live']['guest'],
          ];
          expect(
            bundles.map((b) => (b[key] as List).length).toList(),
            [1, 1],
            reason: 'device and live saved counts',
          );
          for (final bundle in bundles) {
            final item = (bundle[key] as List).single;
            expect(item[tab == 'Study' ? 'title' : 'name'], '合成一件');
            if (tab == 'Money') expect(item['amount'], 1250);
          }
        }

        await open();
        await tester.enterText(input, '合成一件');
        if (tab == 'Money') {
          await tester.enterText(
            find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.labelText == '金額',
            ),
            '1250',
          );
        }
        final save = find.widgetWithText(
          FilledButton,
          tab == 'Money' ? '保存' : '追加',
        );
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(input, findsNothing);
        await checkSaved();
        await open();
        await tester.enterText(input, '取消');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(input, findsNothing);
        await checkSaved();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
