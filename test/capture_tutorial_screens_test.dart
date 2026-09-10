import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus/app/theme.dart';
import 'package:nexus/cloud/nexus_cloud.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/data/models.dart';
import 'package:nexus/screens/app_shell.dart';
import 'package:nexus/widgets/nexus_nav_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final file = File(r'C:\Windows\Fonts\NotoSansJP-VF.ttf');
    if (file.existsSync()) {
      final loader = FontLoader('CaptureJP');
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      await loader.load();
    }
  });

  testWidgets(
    '実画面からチュートリアル用スクショを書き出す',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});

      final store = _seededStore();
      final cloud = NexusCloud();
      await cloud.enterGuestSession();

      await tester.pumpWidget(
        CloudScope(
          cloud: cloud,
          child: AppScope(
            store: store,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _captureTheme(),
              home: const AppShell(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      Future<void> shot(String name) async {
        await tester.pump(const Duration(milliseconds: 200));
        await expectLater(find.byType(AppShell), matchesGoldenFile('../assets/tutorial/$name'));
      }

      Future<void> scrollTab() async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -340));
        await tester.pump(const Duration(milliseconds: 280));
      }

      await shot('home_01.png');
      await scrollTab();
      await shot('home_02.png');

      store.goTo(NexusTab.study);
      await tester.pump(const Duration(milliseconds: 400));
      await shot('study_01.png');
      await scrollTab();
      await shot('study_02.png');

      store.goTo(NexusTab.life);
      await tester.pump(const Duration(milliseconds: 400));
      await shot('life_01.png');
      await scrollTab();
      await shot('life_02.png');

      store.goTo(NexusTab.money);
      await tester.pump(const Duration(milliseconds: 800));
      await shot('money_01.png');
      await scrollTab();
      await shot('money_02.png');
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: Platform.environment['NEXUS_CAPTURE_TUTORIAL'] != '1',
  );
}

ThemeData _captureTheme() {
  const palette = NexusPalette.whiteMidnight;
  NexusColors.apply(palette);
  final scheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.cyan,
    secondary: palette.purple,
    surface: palette.surface,
    error: palette.expense,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: palette.text,
    onError: Colors.white,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    colorScheme: scheme,
    fontFamily: 'CaptureJP',
    scaffoldBackgroundColor: palette.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
  final textTheme = base.textTheme.apply(
    bodyColor: palette.textSecondary,
    displayColor: palette.text,
    fontFamily: 'CaptureJP',
  );
  return base.copyWith(textTheme: textTheme, primaryTextTheme: textTheme);
}

AppStore _seededStore() {
  final store = AppStore.seed();
  store.updateSettings(store.settings.copyWith(reduceMotion: true));
  store.userName = '蒼井 ユウ';
  store.occupation = '学生';
  final today = store.focusedDate;
  store.addSchedule(
    title: '数学の復習',
    startAt: DateTime(today.year, today.month, today.day, 16, 30),
    endAt: DateTime(today.year, today.month, today.day, 18, 0),
    tags: const ['勉強'],
  );
  store.addSchedule(
    title: '買い物',
    startAt: DateTime(today.year, today.month, today.day, 19, 0),
    tags: const ['用事'],
  );
  final math = store.addSubject(name: '数学');
  store.addSubject(name: '英語');
  store.addStudySession(
    subjectId: math.id,
    minutes: 50,
    focus: StudyFocus.four,
    at: today.add(const Duration(hours: 10)),
  );
  store.setDailyStudyGoalMinutes(120);
  store.addHabit(name: '朝の読書', icon: Icons.menu_book_rounded, color: const Color(0xFF0A8CA8));
  store.addIncome(
    name: '今月の収入',
    amount: 80000,
    depositedAt: today,
    useYear: today.year,
    useMonth: today.month,
  );
  final food = store.addBudgetBox(
    name: '食費',
    icon: Icons.restaurant_rounded,
    color: const Color(0xFF3DA9FC),
    monthlyBudget: 30000,
    tags: const ['食費'],
  );
  store.addMoneyCard(boxId: food.id, title: '昼食', amount: 780, at: today);
  store.steps = 4320;
  store.mood = 2;
  store.energy = 3;
  return store;
}
