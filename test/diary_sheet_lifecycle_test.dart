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
  for (final save in [true, false]) {
    testWidgets(
      'Life diary focused exit save=$save preserves durable content',
      (tester) async {
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
        await tester.tap(find.descendant(of: nav, matching: find.text('Life')));
        await tester.pumpAndSettle();
        final store = AppScope.read(tester.element(nav));
        store.setDiary('元の日記');
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('元の日記'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('元の日記'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '編集した日記');
        if (save) {
          await tester.ensureVisible(find.widgetWithText(FilledButton, '保存'));
          await tester.tap(find.widgetWithText(FilledButton, '保存'));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsNothing);
        final expected = save ? '編集した日記' : '元の日記';
        expect(store.diary, expected);
        expect(find.text(expected), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump();
        final data = await disk.getAll();
        for (final bundle in [
          jsonDecode(data['flutter.nexus_user_data_v2_guest'] as String),
          jsonDecode(data['flutter.nexus_cloud_v1'] as String)['live']['guest'],
        ]) {
          expect((bundle['diaries'] as Map).values.toList(), [expected]);
        }
        SharedPreferences.resetStatic();
        final restoredCloud = NexusCloud();
        await restoredCloud.enterGuestSession();
        final restored = AppStore.seed();
        await restored.attachCloud(restoredCloud);
        expect(restored.diaries.values.toList(), [expected]);
        restored.dispose();
        restoredCloud.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
