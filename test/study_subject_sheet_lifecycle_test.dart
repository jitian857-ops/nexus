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
  testWidgets(
    'adding a subject closes the sheet and persists exactly one; cancel discards draft',
    (tester) async {
      final previous = SharedPreferencesStorePlatform.instance;
      final storage = InMemorySharedPreferencesStore.empty();
      SharedPreferencesStorePlatform.instance = storage;
      SharedPreferences.resetStatic();
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = previous;
        SharedPreferences.resetStatic();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      const name = '合成再試行';
      Future<AppStore> openGuestStudy() async {
        await tester.pumpWidget(const NexusApp());
        for (
          var i = 0;
          i < 40 && find.byType(NexusNavBar).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final context = tester.element(find.byType(NexusNavBar));
        await CloudScope.read(context).enterGuestSession();
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(NexusNavBar),
            matching: find.text('Study'),
          ),
        );
        await tester.pumpAndSettle();
        final store = AppScope.read(tester.element(find.byType(NexusNavBar)));
        expect(store.dataUid, 'guest');
        return store;
      }

      Future<List<dynamic>> deviceSubjects() async =>
          jsonDecode(
                (await storage.getAll())['flutter.nexus_user_data_v2_guest']
                    as String,
              )['subjects']
              as List;
      Future<List<dynamic>> liveSubjects() async =>
          jsonDecode(
                (await storage.getAll())['flutter.nexus_cloud_v1'] as String,
              )['live']['guest']['subjects']
              as List;
      final original = await openGuestStudy();
      expect(await deviceSubjects(), isEmpty);
      expect(await liveSubjects(), isEmpty);
      await tester.tap(find.text('教科を追加'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), name);
      await tester.tap(find.widgetWithText(FilledButton, '追加'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNothing);
      expect(original.subjects.single.name, name);
      final id = original.subjects.single.id;
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      for (final entries in [await deviceSubjects(), await liveSubjects()]) {
        expect(entries.single['id'], id);
        expect(entries.single['name'], name);
      }
      await tester.tap(find.text('教科を追加'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '取り消す');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNothing);
      expect(original.subjects.single.id, id);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      for (final entries in [await deviceSubjects(), await liveSubjects()]) {
        expect(entries.single['id'], id);
        expect(entries.single['name'], name);
      }
      // Reopen the application after checking its ordinary writes.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      SharedPreferences.resetStatic();
      final restored = await openGuestStudy();
      expect(restored.subjects.single.id, id);
      expect(restored.subjects.single.name, name);
      expect(
        find.descendant(
          of: find.byKey(ValueKey(id)),
          matching: find.text(name),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
