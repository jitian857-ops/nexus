import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/app/theme.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/cloud/nexus_cloud.dart';
import 'package:nexus/screens/money/box_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  for (final save in [true, false]) {
    testWidgets('expense edit focused exit save=$save', (tester) async {
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
      final box = store.addBudgetBox(
        name: '合成箱',
        icon: Icons.restaurant,
        color: Colors.blue,
        monthlyBudget: 30000,
        tags: [],
      );
      final card = store.addMoneyCard(
        boxId: box.id,
        title: '合成支出',
        amount: 1000,
        at: store.moneyEntryDate,
        memo: '元メモ',
      );
      final other = store.addMoneyCard(
        boxId: box.id,
        title: '別の支出',
        amount: 500,
        at: store.moneyEntryDate,
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: MaterialApp(
            theme: NexusTheme.dark,
            home: BoxDetailPage(boxId: box.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.textContaining('合成支出');
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == '金額',
        ),
        '2500',
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
      expect(store.cards.length, 2);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      final data = await disk.getAll();
      for (final bundle in [
        jsonDecode(data['flutter.nexus_user_data_v2_guest'] as String),
        jsonDecode(data['flutter.nexus_cloud_v1'] as String)['live']['guest'],
      ]) {
        final cards = bundle['cards'] as List;
        expect(cards.length, 2);
        final savedCard = cards.singleWhere((item) => item['id'] == card.id);
        expect(savedCard['amount'], save ? 2500 : 1000);
        expect(savedCard['boxId'], box.id);
        expect(savedCard['title'], '合成支出');
        expect(savedCard['memo'], '元メモ');
        expect(
          cards.singleWhere((item) => item['id'] == other.id)['amount'],
          500,
        );
      }
      // Check ordinary persistence before original-store disposal can flush it.
      SharedPreferences.resetStatic();
      final restoredCloud = NexusCloud();
      await restoredCloud.enterGuestSession();
      final restored = AppStore.seed();
      await restored.attachCloud(restoredCloud);
      expect(restored.cards.length, 2);
      final restoredCard = restored.cards.singleWhere(
        (item) => item.id == card.id,
      );
      expect(restoredCard.amount, save ? 2500 : 1000);
      expect(restoredCard.boxId, box.id);
      expect(restoredCard.title, '合成支出');
      expect(restoredCard.memo, '元メモ');
      expect(
        restored.cards.singleWhere((item) => item.id == other.id).amount,
        500,
      );
      await tester.pumpWidget(
        AppScope(
          store: restored,
          child: MaterialApp(
            key: ObjectKey(restored),
            theme: NexusTheme.dark,
            home: BoxDetailPage(boxId: box.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('合成支出'), findsOneWidget);
      expect(find.textContaining('別の支出'), findsOneWidget);
      restored.dispose();
      restoredCloud.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
