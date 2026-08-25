import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class NexusPrefs {
  NexusPrefs._();

  static const _key = 'nexus_user_data_v2';

  static Future<void> save({
    required List<StudySubject> subjects,
    required List<BudgetBox> boxes,
    required List<MoneyCard> cards,
    required List<IncomeEntry> incomes,
    required List<PaymentPlan> payments,
    required List<Habit> habits,
    required List<SleepLog> sleepLogs,
    DateTime? sleepStartedAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'subjects': [for (final s in subjects) s.toJson()],
          'boxes': [for (final b in boxes) b.toJson()],
          'cards': [for (final c in cards) c.toJson()],
          'incomes': [for (final i in incomes) i.toJson()],
          'payments': [for (final p in payments) p.toJson()],
          'habits': [for (final h in habits) h.toJson()],
          'sleepLogs': [for (final s in sleepLogs) s.toJson()],
          'sleepStartedAt': sleepStartedAt?.toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
