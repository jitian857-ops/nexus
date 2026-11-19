import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/app/theme.dart';
import 'package:nexus/cloud/nexus_cloud.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/screens/money/money_screen.dart';
import 'package:nexus/widgets/nexus_nav_bar.dart';
import 'package:nexus/widgets/period_slide.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  testWidgets(
    'Money restores the edited expense and both monthly balances in a new screen',
    (tester) async {
      final previous = SharedPreferencesStorePlatform.instance;
      final storage = InMemorySharedPreferencesStore.empty();
      SharedPreferencesStorePlatform.instance = storage;
      SharedPreferences.resetStatic();
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = previous;
        SharedPreferences.resetStatic();
      });
      await tester.binding.setSurfaceSize(const Size(520, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final december = DateTime(2026, 12, 31);
      final january = DateTime(2027, 1, 1);
      Future<void> mount(AppStore store) async {
        store.goTo(NexusTab.money);
        store.moneyMonth = december;
        await tester.pumpWidget(
          AppScope(
            store: store,
            child: MaterialApp(
              theme: NexusTheme.dark,
              home: const Scaffold(body: MoneyScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      final originalCloud = NexusCloud();
      await originalCloud.enterGuestSession();
      final original = AppStore.seed();
      await original.attachCloud(originalCloud);
      original.moneyMonth = december;
      final box = original.addBudgetBox(
        name: '箱',
        icon: Icons.restaurant,
        color: Colors.blue,
        monthlyBudget: 30000,
        tags: [],
      );
      for (final month in [december, january]) {
        original.addIncome(
          name: 'synthetic income',
          amount: 100000,
          depositedAt: month,
          useYear: month.year,
          useMonth: month.month,
        );
      }
      final card = original.addMoneyCard(
        boxId: box.id,
        title: 'synthetic expense',
        amount: 1000,
        at: december,
      );
      await mount(original);
      expect(
        find.descendant(
          of: find.byType(PeriodSlide),
          matching: find.text('¥99,000'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('支出 -¥1,000'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('synthetic expense'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, '日付  2026年 12月 31日'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      final durable = await storage.getAll();
      final bundle = jsonDecode(
        durable['flutter.nexus_user_data_v2_guest'] as String,
      );
      expect(DateTime.parse(bundle['cards'].single['at']), january);
      expect(original.hasUnsavedChanges, false);
      // Mount a different store/cloud without disposing the original, so a dispose-time
      // save cannot hide a missing write by the edit action.
      await tester.pumpWidget(const SizedBox.shrink());
      SharedPreferences.resetStatic();
      final newCloud = NexusCloud();
      await newCloud.enterGuestSession();
      final restored = AppStore.seed();
      await restored.attachCloud(newCloud);
      await mount(restored);
      expect(find.text('2026年12月'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PeriodSlide),
          matching: find.text('¥100,000'),
        ),
        findsOneWidget,
      );
      expect(restored.cards.single.id, card.id);
      expect(restored.cards.single.boxId, box.id);
      expect(restored.cards.single.at, january);
      final balanceCard = tester.getRect(find.byType(PeriodSlide));
      await tester.tapAt(Offset(balanceCard.right - 12, balanceCard.center.dy));
      await tester.pumpAndSettle();
      expect(
        restored.moneyMonth,
        january,
        reason: 'The gesture must first select January in the store',
      );
      expect(restored.moneyFor(january).balance, 99000);
      expect(find.text('2027年1月'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PeriodSlide),
          matching: find.text('¥99,000'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('支出 -¥1,000'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1/1  synthetic expense'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      original.dispose();
      restored.dispose();
      await tester.pump();
      originalCloud.dispose();
      newCloud.dispose();
    },
  );
}
