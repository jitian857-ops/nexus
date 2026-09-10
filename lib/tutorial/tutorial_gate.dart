import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/motion.dart';
import 'tutorial_catalog.dart';

/// 案内の完了／スキップを UID×タブ で保存する。記録成功とは別キー。
class TutorialGate {
  TutorialGate._();

  static const _prefix = 'nexus_tutorial_v2_';

  /// 既存のウィジェットテストを覆わない。チュートリアル試験だけ true。
  @visibleForTesting
  static bool debugAllowInTests = false;

  @visibleForTesting
  static Future<String?> Function(String key)? debugGet;

  @visibleForTesting
  static Future<void> Function(String key, String value)? debugSet;

  static String keyFor(String uid, TutorialTab tab) => '$_prefix${uid}_${tab.name}';

  static bool get _skipForWidgetTest =>
      NexusMotion.inWidgetTest && !debugAllowInTests;

  static Future<bool> shouldShow({
    required String uid,
    required TutorialTab tab,
    required bool hasRecords,
  }) async {
    if (uid.isEmpty || _skipForWidgetTest) return false;
    final key = keyFor(uid, tab);
    final stored = await _read(key);
    if (stored == 'done' || stored == 'skipped' || stored == 'legacy') {
      return false;
    }
    if (stored == 'pending') return true;
    if (stored == null && hasRecords) {
      await _write(key, 'legacy');
      return false;
    }
    return true;
  }

  static Future<void> markDone(String uid, TutorialTab tab) {
    return _write(keyFor(uid, tab), 'done');
  }

  static Future<void> markSkipped(String uid, TutorialTab tab) {
    return _write(keyFor(uid, tab), 'skipped');
  }

  static Future<void> reset(String uid, TutorialTab tab) {
    return _write(keyFor(uid, tab), 'pending');
  }

  static Future<void> resetAll(String uid) async {
    for (final tab in TutorialTab.values) {
      await reset(uid, tab);
    }
  }

  static Future<String?> _read(String key) async {
    if (debugGet != null) return debugGet!(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(String key, String value) async {
    if (debugSet != null) {
      await debugSet!(key, value);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
    } catch (_) {}
  }
}
