import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus/app/theme.dart';
import 'package:nexus/cloud/nexus_cloud.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/screens/app_shell.dart';
import 'package:nexus/tutorial/tutorial_catalog.dart';
import 'package:nexus/tutorial/tutorial_gate.dart';
import 'package:nexus/widgets/nexus_nav_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final memory = <String, String>{};

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    memory.clear();
    TutorialGate.debugAllowInTests = true;
    TutorialGate.debugGet = (key) async => memory[key];
    TutorialGate.debugSet = (key, value) async {
      if (value.isEmpty) {
        memory.remove(key);
      } else {
        memory[key] = value;
      }
    };
  });

  tearDown(() {
    TutorialGate.debugAllowInTests = false;
    TutorialGate.debugGet = null;
    TutorialGate.debugSet = null;
  });

  test('案内の再表示は記録があってもpendingなら出す', () async {
    expect(
      await TutorialGate.shouldShow(uid: 'u1', tab: TutorialTab.home, hasRecords: true),
      isFalse,
    );
    await TutorialGate.reset('u1', TutorialTab.home);
    expect(
      await TutorialGate.shouldShow(uid: 'u1', tab: TutorialTab.home, hasRecords: true),
      isTrue,
    );
  });

  test('新規UIDはタブごとに案内し、スキップと完了を分ける', () async {
    expect(
      await TutorialGate.shouldShow(uid: 'guest', tab: TutorialTab.home, hasRecords: false),
      isTrue,
    );
    await TutorialGate.markSkipped('guest', TutorialTab.home);
    expect(
      await TutorialGate.shouldShow(uid: 'guest', tab: TutorialTab.home, hasRecords: false),
      isFalse,
    );
    expect(
      await TutorialGate.shouldShow(uid: 'guest', tab: TutorialTab.study, hasRecords: false),
      isTrue,
    );
    await TutorialGate.markDone('guest', TutorialTab.study);
    expect(memory[TutorialGate.keyFor('guest', TutorialTab.home)], 'skipped');
    expect(memory[TutorialGate.keyFor('guest', TutorialTab.study)], 'done');
  });

  testWidgets('ゲスト初回のHomeに案内が出てスキップできる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore.seed();
    final cloud = NexusCloud();
    await cloud.enterGuestSession();

    await tester.pumpWidget(
      CloudScope(
        cloud: cloud,
        child: AppScope(
          store: store,
          child: MaterialApp(
            theme: NexusTheme.of(NexusPalette.byId(store.settings.themeId)),
            home: const AppShell(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Homeは今日の窓口'), findsOneWidget);
    expect(find.text('スキップ'), findsOneWidget);
    await tester.tap(find.text('スキップ'));
    await tester.pumpAndSettle();
    expect(find.text('Homeは今日の窓口'), findsNothing);
    expect(find.text('今日の予定'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(NexusNavBar), matching: find.text('Study')));
    await tester.pumpAndSettle();
    expect(find.text('学習の記録'), findsOneWidget);
  });
}
