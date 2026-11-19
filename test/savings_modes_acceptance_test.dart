import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/app/theme.dart';
import 'package:nexus/cloud/nexus_cloud.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/screens/money/money_screen.dart';
import 'package:nexus/screens/money/box_detail_page.dart';
import 'package:nexus/widgets/nexus_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  for (final detail in [false, true]) {
    for (final mode in [
      ('預ける', 'saveIn', 6000, 9000),
      ('貯蓄から出す', 'saveOut', 4000, 10000),
      ('残高から出す', 'spend', 5000, 9000),
    ]) {
      for (final save in [true, false]) {
        testWidgets('savings detail=$detail ${mode.$1} save=$save', (
          tester,
        ) async {
          final previous = SharedPreferencesStorePlatform.instance;
          final disk = InMemorySharedPreferencesStore.empty();
          SharedPreferencesStorePlatform.instance = disk;
          SharedPreferences.resetStatic();
          final cloud = NexusCloud();
          await cloud.enterGuestSession();
          final store = AppStore.seed();
          await store.attachCloud(cloud);
          addTearDown(() {
            store.dispose();
            cloud.dispose();
            SharedPreferencesStorePlatform.instance = previous;
            SharedPreferences.resetStatic();
          });
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final day = DateTime(2026, 11, 19);
          final box = store.addSavingsBox(
            name: '合成貯蓄',
            icon: Icons.savings,
            color: Colors.blue,
            targetAmount: 20000,
            openingAmount: 5000,
            tags: [],
          );
          store.addIncome(
            name: '合成収入',
            amount: 10000,
            depositedAt: day,
            useYear: 2026,
            useMonth: 11,
          );
          Future<void> mount(AppStore state) async {
            state.goTo(NexusTab.money);
            state.moneyMonth = day;
            await tester.pumpWidget(
              AppScope(
                store: state,
                child: MaterialApp(
                  key: ObjectKey(state),
                  theme: NexusTheme.dark,
                  home: detail
                      ? BoxDetailPage(boxId: box.id)
                      : const Scaffold(body: MoneyScreen()),
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          await mount(store);
          await tester.tap(find.text('カードを追加'));
          await tester.pumpAndSettle();
          expect(find.text('合成貯蓄（貯蓄）'), findsOneWidget);
          await tester.tap(find.widgetWithText(ChoiceChip, mode.$1));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.labelText == '金額',
            ),
            '1000',
          );
          if (save) {
            await tester.ensureVisible(find.widgetWithText(FilledButton, '保存'));
            await tester.tap(find.widgetWithText(FilledButton, '保存'));
          } else {
            await tester.binding.handlePopRoute();
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(TextField), findsNothing);
          void check(AppStore state) {
            expect(state.cards.length, save ? 1 : 0);
            expect(
              state.savingsBalance(state.boxById(box.id)!),
              save ? mode.$3 : 5000,
            );
            expect(state.moneyFor(day).balance, save ? mode.$4 : 10000);
            if (save) {
              expect(state.cards.single.kind.name, mode.$2);
              expect(state.cards.single.amount, 1000);
              expect(state.cards.single.boxId, box.id);
            }
          }

          check(store);
          await tester.pump(const Duration(milliseconds: 800));
          await tester.pump();
          final data = await disk.getAll();
          for (final bundle in [
            jsonDecode(data['flutter.nexus_user_data_v2_guest'] as String),
            jsonDecode(
              data['flutter.nexus_cloud_v1'] as String,
            )['live']['guest'],
          ]) {
            final cards = bundle['cards'] as List;
            expect(cards.length, save ? 1 : 0);
            if (save) {
              expect(cards.single['kind'], mode.$2);
              expect(cards.single['amount'], 1000);
              expect(cards.single['id'], store.cards.single.id);
              expect(cards.single['boxId'], box.id);
            }
          }
          SharedPreferences.resetStatic();
          final restoredCloud = NexusCloud();
          await restoredCloud.enterGuestSession();
          final restored = AppStore.seed();
          await restored.attachCloud(restoredCloud);
          check(restored);
          await mount(restored);
          expect(tester.takeException(), isNull);
          if (save) expect(restored.cards.single.id, store.cards.single.id);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          restored.dispose();
          restoredCloud.dispose();
        });
      }
    }
  }
}
