import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/app_store.dart';
import '../screens/app_shell.dart';

class NexusApp extends StatefulWidget {
  const NexusApp({super.key});

  @override
  State<NexusApp> createState() => _NexusAppState();
}

class _NexusAppState extends State<NexusApp> {
  final AppStore _store = AppStore.seed();

  @override
  void initState() {
    super.initState();
    _store.hydrate();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: _store,
      child: MaterialApp(
        title: 'NEXUS',
        debugShowCheckedModeBanner: false,
        theme: NexusTheme.dark,
        themeMode: ThemeMode.dark,
        builder: (context, child) {
          return PhoneScope(child: child ?? const SizedBox.shrink());
        },
        home: const AppShell(),
      ),
    );
  }
}

class PhoneScope extends StatelessWidget {
  const PhoneScope({super.key, required this.child});

  final Widget child;

  static const double phoneWidth = 390;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= 500) return child;

    final height = media.size.height < phoneWidth * 19.5 / 9
        ? media.size.height
        : phoneWidth * 19.5 / 9;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: phoneWidth,
          height: height,
          child: MediaQuery(
            data: media.copyWith(size: Size(phoneWidth, height)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
