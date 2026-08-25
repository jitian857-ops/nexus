import '../core/format.dart';
import 'models.dart';

class NexusSnapshot {
  NexusSnapshot._();

  static List<T> list<T>(
    Map<String, dynamic> data,
    String key,
    T Function(Map<String, dynamic>) parse,
  ) {
    return [
      for (final item in (data[key] as List? ?? const []))
        parse(Map<String, dynamic>.from(item as Map)),
    ];
  }

  static Map<String, dynamic> encode({
    required String userName,
    required int level,
    required double levelProgress,
    required int dailyStudyGoalMinutes,
    required DateTime todayStudyDate,
    required int todayStudyLoggedSeconds,
    required double totalStudyHours,
    required String nextStudySubjectId,
    required int timerTotalSeconds,
    required int timerAccumulatedSeconds,
    required bool timerRunning,
    required DateTime? timerStartedAt,
    required String? timerSubjectId,
    required DateTime? sleepStartedAt,
    required int steps,
    required int stepGoal,
    required UserSettings settings,
    required List<ScheduleItem> schedules,
    required List<StudySubject> subjects,
    required List<StudySession> sessions,
    required List<StudyGoal> goals,
    required List<Assignment> assignments,
    required List<Exam> exams,
    required List<LearningEntry> diaryPosts,
    required List<ProblemRecord> problems,
    required List<ReviewCard> reviewCards,
    required List<Habit> habits,
    required List<BudgetBox> boxes,
    required List<MoneyCard> cards,
    required List<IncomeEntry> incomes,
    required List<PaymentPlan> payments,
    required List<SleepLog> sleepLogs,
    required List<DayCheckIn> checkIns,
    required List<BoxAllocation> allocations,
    required List<StoredReport> reports,
  }) {
    return {
      'userName': userName,
      'level': level,
      'levelProgress': levelProgress,
      'dailyStudyGoalMinutes': dailyStudyGoalMinutes,
      'todayStudyDate': dateKey(todayStudyDate),
      'todayStudyLoggedSeconds': todayStudyLoggedSeconds,
      'totalStudyHours': totalStudyHours,
      'nextStudySubjectId': nextStudySubjectId,
      'timerTotalSeconds': timerTotalSeconds,
      'timerAccumulatedSeconds': timerAccumulatedSeconds,
      'timerRunning': timerRunning,
      'timerStartedAt': timerStartedAt?.toIso8601String(),
      'timerSubjectId': timerSubjectId,
      'sleepStartedAt': sleepStartedAt?.toIso8601String(),
      'steps': steps,
      'stepGoal': stepGoal,
      'settings': settings.toJson(),
      'schedules': [for (final s in schedules) s.toJson()],
      'subjects': [for (final s in subjects) s.toJson()],
      'sessions': [for (final s in sessions) s.toJson()],
      'goals': [for (final g in goals) g.toJson()],
      'assignments': [for (final a in assignments) a.toJson()],
      'exams': [for (final e in exams) e.toJson()],
      'diaryPosts': [for (final d in diaryPosts) d.toJson()],
      'problems': [for (final p in problems) p.toJson()],
      'reviewCards': [for (final c in reviewCards) c.toJson()],
      'habits': [for (final h in habits) h.toJson()],
      'boxes': [for (final b in boxes) b.toJson()],
      'cards': [for (final c in cards) c.toJson()],
      'incomes': [for (final i in incomes) i.toJson()],
      'payments': [for (final p in payments) p.toJson()],
      'sleepLogs': [for (final s in sleepLogs) s.toJson()],
      'checkIns': [for (final c in checkIns) c.toJson()],
      'allocations': [for (final a in allocations) a.toJson()],
      'reports': [for (final r in reports) r.toJson()],
    };
  }
}
