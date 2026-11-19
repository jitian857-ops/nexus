import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/app/theme.dart';
import 'package:nexus/cloud/nexus_cloud.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/screens/life/checkin_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  testWidgets('check-in save and cancel close a focused diary safely', (
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
    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openCheckIn(context, store),
              child: const Text('開く'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('詳細を追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '合成日記');
    await tester.ensureVisible(find.text('今日を記録'));
    await tester.tap(find.text('今日を記録'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);
    Future<void> checkDisk() async {
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      final data = await disk.getAll();
      final bundles = [
        jsonDecode(data['flutter.nexus_user_data_v2_guest'] as String),
        jsonDecode(data['flutter.nexus_cloud_v1'] as String)['live']['guest'],
      ];
      for (final bundle in bundles) {
        expect((bundle['diaries'] as Map).values.toList(), ['合成日記']);
      }
    }

    expect(store.diary, '合成日記');
    await checkDisk();
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '取消する下書き');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);
    expect(store.diary, '合成日記');
    await checkDisk();
      // Cold-read the ordinary writes before disposing the original store.
      SharedPreferences.resetStatic();
      final restoredCloud = NexusCloud();
      await restoredCloud.enterGuestSession();
      final restored = AppStore.seed();
      await restored.attachCloud(restoredCloud);
      expect(restored.diaries.values.toList(), ['合成日記']);
      restored.dispose();
      restoredCloud.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
