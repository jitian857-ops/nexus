import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/app/theme.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/cloud/nexus_cloud.dart';
import 'package:nexus/screens/money/money_forms.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  for (final save in [true, false]) {
    testWidgets('expense focused exit save=$save', (tester) async {
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
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: NexusTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openAddCard(context, store),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開く'));
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
      expect(store.cards.length, save ? 1 : 0);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      final data = await disk.getAll();
      for (final bundle in [
        jsonDecode(data['flutter.nexus_user_data_v2_guest'] as String),
        jsonDecode(data['flutter.nexus_cloud_v1'] as String)['live']['guest'],
      ]) {
        final cards = bundle['cards'] as List;
        expect(cards.length, save ? 1 : 0);
        if (save) {
          expect(cards.single['amount'], 1000);
          expect(cards.single['boxId'], box.id);
          expect(cards.single['id'], store.cards.single.id);
        }
      }
      // Check ordinary persistence before original-store disposal can flush it.
      SharedPreferences.resetStatic();
      final restoredCloud = NexusCloud();
      await restoredCloud.enterGuestSession();
      final restored = AppStore.seed();
      await restored.attachCloud(restoredCloud);
      expect(restored.cards.length, save ? 1 : 0);
      if (save) {
        expect(restored.cards.single.amount, 1000);
        expect(restored.cards.single.boxId, box.id);
        expect(restored.cards.single.id, store.cards.single.id);
      }
      restored.dispose();
      restoredCloud.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
