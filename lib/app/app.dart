import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../cloud/nexus_cloud.dart';
import '../data/app_store.dart';
import '../screens/auth/auth_gate.dart';

class NexusApp extends StatefulWidget {
  const NexusApp({super.key});

  @override
  State<NexusApp> createState() => _NexusAppState();
}

class _NexusAppState extends State<NexusApp> {
  final AppStore _store = AppStore.seed();
  final NexusCloud _cloud = NexusCloud();
  var _bound = false;

  @override
  void initState() {
    super.initState();
    _cloud.addListener(_onCloud);
    _cloud.boot();
  }

  void _onCloud() {
    if (_cloud.isSignedIn && _cloud.emailVerified) {
      if (!_bound) {
        _bound = true;
        _store.attachCloud(_cloud);
      }
    } else {
      if (_bound || !_cloud.isSignedIn) {
        _bound = false;
        if (!_cloud.isSignedIn) _store.detachCloud();
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cloud.removeListener(_onCloud);
    _store.dispose();
    _cloud.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CloudScope(
      cloud: _cloud,
      child: AppScope(
        store: _store,
        child: _ThemedMaterialApp(store: _store),
      ),
    );
  }
}

class _ThemedMaterialApp extends StatefulWidget {
  const _ThemedMaterialApp({required this.store});

  final AppStore store;

  @override
  State<_ThemedMaterialApp> createState() => _ThemedMaterialAppState();
}

class _ThemedMaterialAppState extends State<_ThemedMaterialApp> {
  late String _themeId;

  @override
  void initState() {
    super.initState();
    _themeId = widget.store.settings.themeId;
    widget.store.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    final next = widget.store.settings.themeId;
    if (next == _themeId || !mounted) return;
    setState(() => _themeId = next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = NexusPalette.byId(_themeId);
    final overlay = palette.isLight ? Brightness.dark : Brightness.light;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: overlay,
        statusBarBrightness: palette.isLight ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: palette.background,
        systemNavigationBarIconBrightness: overlay,
      ),
    );
    return MaterialApp(
      title: 'NEXUS',
      debugShowCheckedModeBanner: false,
      theme: NexusTheme.of(palette),
      builder: (context, child) {
        return PhoneScope(child: child ?? const SizedBox.shrink());
      },
      home: const AuthGate(),
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
      color: NexusColors.frame,
      child: Center(
        child: Container(
          width: phoneWidth + 18,
          height: height + 18,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(38),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: NexusColors.isLight
                  ? [
                      NexusColors.border,
                      NexusColors.frame,
                      NexusColors.border,
                    ]
                  : [
                      NexusColors.cyan.withValues(alpha: 0.45),
                      NexusColors.purple.withValues(alpha: 0.28),
                      NexusColors.text.withValues(alpha: 0.08),
                    ],
            ),
            boxShadow: NexusColors.isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: NexusColors.cyan.withValues(alpha: 0.18),
                      blurRadius: 28,
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: SizedBox(
              width: phoneWidth,
              height: height,
              child: MediaQuery(
                data: media.copyWith(size: Size(phoneWidth, height)),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
