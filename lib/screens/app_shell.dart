import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../widgets/nexus_nav_bar.dart';
import '../app/theme.dart';
import 'home/home_screen.dart';
import 'life/life_screen.dart';
import 'money/money_screen.dart';
import 'settings/settings_screen.dart';
import 'study/study_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: NexusColors.background,
      extendBody: true,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 70 + (bottom > 0 ? bottom : 10)),
            child: IndexedStack(
              index: store.tabIndex,
              children: const [
                HomeScreen(),
                StudyScreen(),
                LifeScreen(),
                MoneyScreen(),
                SettingsScreen(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: NexusNavBar(
              currentIndex: store.tabIndex,
              onTap: store.goTo,
            ),
          ),
        ],
      ),
    );
  }
}
