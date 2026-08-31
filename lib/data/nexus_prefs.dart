import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NexusPrefs {
  NexusPrefs._();

  static const legacyKey = 'nexus_user_data_v2';

  static String keyFor(String? uid) {
    if (uid == null || uid.isEmpty || uid == 'test') return legacyKey;
    return '${legacyKey}_$uid';
  }

  static Future<void> saveBundle(String? uid, Map<String, dynamic> bundle) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyFor(uid), jsonEncode(bundle));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadBundle(String? uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(keyFor(uid));
      if ((raw == null || raw.isEmpty) && uid != null && uid.isNotEmpty && uid != 'test') {
        raw = prefs.getString(legacyKey);
      }
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> load() => loadBundle(null);

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
    await saveBundle(null, {
      'subjects': [for (final s in subjects) s.toJson()],
      'sessions': [for (final s in sessions) s.toJson()],
      'exams': [for (final e in exams) e.toJson()],
      'goals': [for (final g in goals) g.toJson()],
      'boxes': [for (final b in boxes) b.toJson()],
      'cards': [for (final c in cards) c.toJson()],
      'incomes': [for (final i in incomes) i.toJson()],
      'payments': [for (final p in payments) p.toJson()],
      'habits': [for (final h in habits) h.toJson()],
      'sleepLogs': [for (final s in sleepLogs) s.toJson()],
      'sleepStartedAt': sleepStartedAt?.toIso8601String(),
      if (userName != null) 'userName': userName,
      if (settings != null) 'settings': settings.toJson(),
      if (diaries != null) 'diaries': diaries,
    });
  }
}
