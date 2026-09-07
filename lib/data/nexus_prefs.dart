import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 端末読込の結果。失敗と未保存は区別する。
class PrefsLoadResult {
  const PrefsLoadResult._({this.data, this.failed = false});

  const PrefsLoadResult.found(Map<String, dynamic> data) : this._(data: data);

  const PrefsLoadResult.missing() : this._();

  const PrefsLoadResult.failed() : this._(failed: true);

  final Map<String, dynamic>? data;
  final bool failed;

  bool get hasData => data != null;
}

class NexusPrefs {
  NexusPrefs._();

  static const legacyKey = 'nexus_user_data_v2';

  /// テスト用。null なら SharedPreferences を使う。
  static Future<PrefsLoadResult> Function(String uid)? debugLoad;

  static Future<void> Function(String uid, Map<String, dynamic> bundle)? debugSave;

  static String? keyFor(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    return '${legacyKey}_$uid';
  }

  static Future<void> saveBundle(String? uid, Map<String, dynamic> bundle) async {
    if (uid == null || uid.isEmpty) return;
    if (debugSave != null) {
      await debugSave!(uid, bundle);
      return;
    }
    final key = keyFor(uid);
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(bundle));
    } catch (_) {}
  }

  static Future<PrefsLoadResult> loadBundle(String? uid) async {
    if (uid == null || uid.isEmpty) return const PrefsLoadResult.missing();
    if (debugLoad != null) return debugLoad!(uid);
    final key = keyFor(uid);
    if (key == null) return const PrefsLoadResult.missing();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return const PrefsLoadResult.missing();
      return PrefsLoadResult.found(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const PrefsLoadResult.failed();
    }
  }

  /// 所有者不明の旧キー。新規ユーザーへは自動適用しない。削除もしない。
  static Future<Map<String, dynamic>?> loadUnownedLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(legacyKey);
      if (raw == null || raw.isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> load() => loadUnownedLegacy();

  static Future<void> save({
    required List<dynamic> subjects,
    required List<dynamic> sessions,
    required List<dynamic> exams,
    required List<dynamic> goals,
    required List<dynamic> boxes,
    required List<dynamic> cards,
    required List<dynamic> incomes,
    required List<dynamic> payments,
    required List<dynamic> habits,
    required List<dynamic> sleepLogs,
    DateTime? sleepStartedAt,
    String? userName,
    dynamic settings,
    Map<String, String>? diaries,
  }) async {
    return;
  }
}
