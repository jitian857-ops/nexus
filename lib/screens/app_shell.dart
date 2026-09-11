import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../tutorial/tutorial_overlay.dart';
import '../widgets/nexus_nav_bar.dart';
import '../app/theme.dart';
import 'home/home_screen.dart';
import 'life/life_screen.dart';
import 'money/money_screen.dart';
import 'friends/friends_screen.dart';
import 'study/study_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.read(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return TutorialLayer(
      child: Scaffold(
        backgroundColor: NexusColors.background,
        extendBody: true,
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 70 + (bottom > 0 ? bottom : 10)),
              child: _ShellTabs(store: store),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ListenableBuilder(
                listenable: store,
                builder: (context, _) {
                  return NexusNavBar(
                    currentIndex: store.tabIndex,
                    onTap: store.goTo,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellTabs extends StatefulWidget {
  const _ShellTabs({required this.store});

  final AppStore store;

  @override
  State<_ShellTabs> createState() => _ShellTabsState();
}

class _ShellTabsState extends State<_ShellTabs> {
  static const _tabs = [
    HomeScreen(),
    StudyScreen(),
    LifeScreen(),
    MoneyScreen(),
    FriendsScreen(),
  ];

  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.store.tabIndex;
    widget.store.addListener(_onStore);
  }

  @override
  void didUpdateWidget(covariant _ShellTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_onStore);
      widget.store.addListener(_onStore);
      _index = widget.store.tabIndex;
    }
  }

  void _onStore() {
    final next = widget.store.tabIndex;
    if (next == _index || !mounted) return;
    setState(() => _index = next);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < _tabs.length; i++)
          TickerMode(
            enabled: i == _index,
            child: _tabs[i],
          ),
      ],
    );
  }
}
