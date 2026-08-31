import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../cloud/nexus_cloud.dart';
import '../core/format.dart';
import '../domain/daily_quotes.dart';
import '../domain/day_occasions.dart';
import '../domain/money_calc.dart';
import '../domain/review_scheduler.dart';
import '../widgets/nexus_nav_bar.dart';
import 'models.dart';
import 'nexus_icons.dart';
import 'nexus_prefs.dart';

class AppStore extends ChangeNotifier {
  AppStore.seed() {
    _seed();
  }

  int _seq = 0;
  String _id() => 'n${_seq++}';

  int tabIndex = NexusTab.home;
  DateTime focusedDate = dateOnly(DateTime.now());
  DateTime lifeDate = dateOnly(DateTime.now());
  DateTime moneyMonth = dateOnly(DateTime.now());
  DateTime studyWeek = dateOnly(DateTime.now());

  String userName = '蒼井 ユウ';
  String occupation = '';
  final Map<String, String> diaries = {};

  int dailyStudyGoalMinutes = 120;
  DateTime todayStudyDate = dateOnly(DateTime.now());
  int todayStudyLoggedSeconds = 0;

  final List<ScheduleItem> schedules = [];
  final List<StudySubject> subjects = [];
  final List<StudySession> sessions = [];
  final List<StudyGoal> goals = [];
  final List<Assignment> assignments = [];
  final List<Exam> exams = [];
  final List<LearningEntry> diaryPosts = [];
  final List<ProblemRecord> problems = [];
  final List<ReviewCard> reviewCards = [];
  final List<Habit> habits = [];
  final List<BudgetBox> boxes = [];
  final List<MoneyCard> cards = [];
  final List<IncomeEntry> incomes = [];
  final List<PaymentPlan> payments = [];
  final List<ChatMessage> messages = [];

  bool _canSave = false;
  String? dataUid;
  NexusCloud? _cloud;
  Timer? _cloudPush;

  int income = 0;
  double weekStudyHours = 0;
  double totalStudyHours = 0;
  List<double> weekBars = const [0, 0, 0, 0, 0, 0, 0];
  String nextTaskTitle = '';
  String nextTaskDuration = '';
  String nextStudySubjectId = '';
  String nextStudyPlace = '';
  DateTime nextStudyAt = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    16,
    30,
  );

  int timerTotalSeconds = 30 * 60;
  int timerAccumulatedSeconds = 0;
  DateTime? timerStartedAt;
  bool timerRunning = false;
  String? timerSubjectId;

  final List<SleepLog> sleepLogs = [];
  DateTime? sleepStartedAt;

  bool get isSleeping => sleepStartedAt != null;
  int mood = 0;
  int energy = 0;
  int steps = 0;
  int stepGoal = 10000;

  UserSettings settings = const UserSettings();
  AiProposal? proposal;
  String lastToast = '';

  SleepLog? sleepLogOn(DateTime day) {
    final key = dateKey(day);
    for (final log in sleepLogs) {
      if (dateKey(log.wakeDate) == key) return log;
    }
    return null;
  }

  SleepLog? get latestSleepLog {
    if (sleepLogs.isEmpty) return null;
    final sorted = [...sleepLogs]..sort((a, b) => b.wakeAt.compareTo(a.wakeAt));
    return sorted.first;
  }

  double get sleepHours => latestSleepLog?.hours ?? 0;

  List<double> sleepWeekHours([DateTime? day]) {
    final anchor = dateOnly(day ?? focusedDate);
    final monday = anchor.subtract(Duration(days: mondayIndex(anchor)));
    return [
      for (var i = 0; i < 7; i++)
        sleepLogOn(monday.add(Duration(days: i)))?.hours ?? 0,
    ];
  }

  MoneySnapshot get money => moneyFor(moneyMonth);

  MoneySnapshot moneyFor(DateTime day, {bool? deductBudget}) {
    final anchor = dateOnly(day);
    final budgetBoxes = [
      for (final box in boxes.where((b) => !b.isSavings && _boxInMonth(b, anchor)))
        box.copyWith(spent: spentOfBox(box.id, month: anchor)),
    ];
    return MoneyCalc.compute(
      income: incomeForMonth(anchor),
      boxes: budgetBoxes,
      payments: payments,
      today: anchor,
      unassignedSpent: unassignedSpentFor(anchor),
      savingsAllocated: savingsAllocatedFor(anchor),
      deductBudget: deductBudget ?? settings.deductBudgetFromBalance,
    );
  }

  int get studyXpMinutes => sessions.fold<int>(0, (sum, s) => sum + s.minutes);

  int get level => 1 + studyXpMinutes ~/ 60;

  double get levelProgress => (studyXpMinutes % 60) / 60.0;

  String diaryOn(DateTime day) => diaries[dateKey(day)] ?? '';

  String get diary => diaryOn(lifeDate);

  int savingsAllocatedFor(DateTime day) {
    return cards.where((c) {
      if (c.at.year != day.year || c.at.month != day.month) return false;
      if (c.kind == MoneyCardKind.saveIn) return true;
      if (c.kind != MoneyCardKind.spend) return false;
      final box = boxById(c.boxId);
      return box != null && box.isSavings;
    }).fold<int>(0, (sum, c) => sum + c.amount);
  }

  int unassignedSpentFor(DateTime day) {
    return cards.where((c) {
      if (c.kind != MoneyCardKind.spend) return false;
      if (boxById(c.boxId) != null) return false;
      return c.at.year == day.year && c.at.month == day.month;
    }).fold<int>(0, (sum, c) => sum + c.amount);
  }

  int incomeForMonth(DateTime day) {
    return incomes
        .where((e) => e.useYear == day.year && e.useMonth == day.month)
        .fold<int>(0, (sum, e) => sum + e.amount);
  }

  int spentOfBox(
    String boxId, {
    DateTime? month,
  }) {
    final anchor = month ?? moneyMonth;
    return cards.where((c) {
      if (c.boxId != boxId || c.kind != MoneyCardKind.spend) return false;
      return sameMonth(c.at, anchor);
    }).fold<int>(0, (sum, c) => sum + c.amount);
  }

  List<BudgetBox> get visibleBoxes => [
        for (final box in boxes)
          if (box.isSavings || _boxInMonth(box, moneyMonth)) box,
      ];

  DateTime get moneyEntryDate {
    final now = dateOnly(DateTime.now());
    if (sameMonth(moneyMonth, now)) return now;
    return monthStart(moneyMonth);
  }

  bool _boxInMonth(BudgetBox box, DateTime day) {
    if (box.isSavings) return true;
    final month = box.month;
    if (month == null) return false;
    return sameMonth(month, day);
  }

  int savingsBalance(BudgetBox box) {
    var value = box.openingAmount;
    for (final card in cards.where((c) => c.boxId == box.id)) {
      if (card.kind == MoneyCardKind.saveIn) value += card.amount;
      if (card.kind == MoneyCardKind.saveOut) value -= card.amount;
    }
    return value;
  }

  List<MoneyCard> cardsForBox(String boxId, {DateTime? month}) {
    final list = cards.where((c) {
      if (c.boxId != boxId) return false;
      if (month == null) return true;
      return c.at.year == month.year && c.at.month == month.month;
    }).toList();
    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  BudgetBox? boxById(String id) {
    for (final b in boxes) {
      if (b.id == id) return b;
    }
    return null;
  }

  DateTime nextPaymentDue(PaymentPlan plan, DateTime today) {
    var due = dateOnly(plan.dueAt);
    final now = dateOnly(today);
    if (plan.repeat == PaymentRepeat.none || !due.isBefore(now)) return due;
    while (due.isBefore(now)) {
      due = plan.repeat == PaymentRepeat.yearly
          ? DateTime(due.year + 1, due.month, due.day)
          : DateTime(due.year, due.month + 1, due.day);
    }
    return due;
  }

  DayOccasion get todayOccasion => occasionFor(focusedDate);

  DailyQuote get todayQuote => quoteFor(focusedDate);

  double get goalProgress {
    final goal = dailyStudyGoalMinutes * 60;
    if (goal <= 0) return 0;
    return (todayStudySeconds() / goal).clamp(0.0, 1.0);
  }

  int todayStudySeconds() {
    _rollTodayStudyIfNeeded();
    var seconds = todayStudyLoggedSeconds;
    if (timerRunning) seconds += timerElapsedSeconds();
    return seconds;
  }

  int remainingStudyMinutes() {
    final remain = dailyStudyGoalMinutes * 60 - todayStudySeconds();
    if (remain <= 0) return 0;
    return (remain / 60).ceil();
  }

  void _rollTodayStudyIfNeeded() {
    final today = dateOnly(DateTime.now());
    if (sameDay(todayStudyDate, today)) return;
    todayStudyDate = today;
    todayStudyLoggedSeconds = 0;
  }

  List<ScheduleItem> schedulesOn(DateTime day) {
    final items = schedules.where((s) => sameDay(s.startAt, day)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return items;
  }

  StudySubject? subjectById(String id) {
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<StudySubject> get visibleSubjects => [
        for (final s in subjects)
          if (!s.archived) s,
      ];

  static const otherSubjectId = '__other';

  DateTime get studyWeekMonday => weekMonday(studyWeek);

  DateTime get studyEntryDate {
    final now = DateTime.now();
    final monday = studyWeekMonday;
    final sunday = monday.add(const Duration(days: 6));
    final today = dateOnly(now);
    if (!today.isBefore(monday) && !today.isAfter(sunday)) return now;
    return DateTime(monday.year, monday.month, monday.day, now.hour, now.minute);
  }

  List<StudySubject> weekChartSubjects([DateTime? week]) {
    final monday = weekMonday(week ?? studyWeek);
    final used = <String>{};
    for (final session in sessions) {
      final idx = dateOnly(session.at).difference(monday).inDays;
      if (idx < 0 || idx > 6) continue;
      used.add(session.subjectId);
    }
    final list = [
      for (final s in subjects)
        if (!s.archived) s,
    ];
    for (final s in subjects) {
      if (s.archived && used.contains(s.id)) list.add(s);
    }
    final known = {for (final s in list) s.id};
    if (used.any((id) => !known.contains(id))) {
      list.add(
        StudySubject(
          id: otherSubjectId,
          name: 'その他',
          color: NexusColors.textMuted,
          weekHours: 0,
          icon: Icons.more_horiz_rounded,
          archived: true,
        ),
      );
    }
    return list;
  }

  List<List<double>> weekStackedHours([DateTime? week]) {
    final monday = weekMonday(week ?? studyWeek);
    final series = weekChartSubjects(week);
    if (series.isEmpty) return const [];
    final stacks = List.generate(7, (_) => List<double>.filled(series.length, 0));
    final indexOf = {for (var i = 0; i < series.length; i++) series[i].id: i};
    final otherIndex = indexOf[otherSubjectId] ?? -1;
    for (final session in sessions) {
      final idx = dateOnly(session.at).difference(monday).inDays;
      if (idx < 0 || idx > 6) continue;
      final si = indexOf[session.subjectId] ?? otherIndex;
      if (si < 0) continue;
      stacks[idx][si] += session.minutes / 60.0;
    }
    return stacks;
  }

  List<double> weekDayHours([DateTime? week]) {
    final monday = weekMonday(week ?? focusedDate);
    final hours = List<double>.filled(7, 0);
    for (final session in sessions) {
      final idx = dateOnly(session.at).difference(monday).inDays;
      if (idx < 0 || idx > 6) continue;
      hours[idx] += session.minutes / 60.0;
    }
    return hours;
  }

  double weekStudyHoursFor(DateTime week) {
    return weekDayHours(week).fold<double>(0, (a, b) => a + b);
  }

  List<StudySession> sessionsInWeek(DateTime week) {
    final monday = weekMonday(week);
    final list = [
      for (final session in sessions)
        if ((dateOnly(session.at).difference(monday).inDays) >= 0 &&
            (dateOnly(session.at).difference(monday).inDays) <= 6)
          session,
    ];
    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  void _refreshWeekBars() {
    final monday = weekMonday(focusedDate);
    final dayMinutes = List<int>.filled(7, 0);
    for (final session in sessions) {
      final idx = dateOnly(session.at).difference(monday).inDays;
      if (idx < 0 || idx > 6) continue;
      dayMinutes[idx] += session.minutes;
    }
    weekStudyHours = dayMinutes.fold<int>(0, (a, b) => a + b) / 60.0;
    final max = dayMinutes.fold<int>(0, (a, b) => a > b ? a : b);
    weekBars = [
      for (final total in dayMinutes) max <= 0 ? 0.2 : (total / max).clamp(0.08, 1.0),
    ];
    for (var i = 0; i < subjects.length; i++) {
      if (subjects[i].archived) continue;
      final hours = subjectWeekHours(subjects[i].id).fold<double>(0, (a, b) => a + b);
      subjects[i] = subjects[i].copyWith(weekHours: hours);
    }
  }

  void _syncStudyTotals() {
    totalStudyHours = sessions.fold<int>(0, (a, s) => a + s.minutes) / 60.0;
    _refreshWeekBars();
  }

  int reviewDueCount() {
    return reviewCards
        .where((c) => c.status == 'pending' && !c.dueAt.isAfter(focusedDate))
        .length;
  }

  int timerElapsedSeconds() {
    var elapsed = timerAccumulatedSeconds;
    if (timerRunning && timerStartedAt != null) {
      elapsed += DateTime.now().difference(timerStartedAt!).inSeconds;
    }
    return elapsed.clamp(0, timerTotalSeconds);
  }

  int timerRemainingSeconds() =>
      (timerTotalSeconds - timerElapsedSeconds()).clamp(0, timerTotalSeconds);

  void goTo(int tab) {
    tabIndex = tab.clamp(NexusTab.home, NexusTab.settings);
    notifyListeners();
  }

  void setFocusedDate(DateTime day) {
    focusedDate = dateOnly(day);
    notifyListeners();
  }

  void setLifeDate(DateTime day) {
    lifeDate = dateOnly(day);
    notifyListeners();
  }

  void shiftLifeMonth(int delta) {
    final next = DateTime(lifeDate.year, lifeDate.month + delta);
    final today = dateOnly(DateTime.now());
    if (next.year == today.year && next.month == today.month) {
      setLifeDate(today);
    } else {
      setLifeDate(DateTime(next.year, next.month, 1));
    }
  }

  void shiftStudyWeek(int delta) {
    studyWeek = dateOnly(studyWeek).add(Duration(days: 7 * delta));
    notifyListeners();
  }

  void shiftMoneyMonth(int delta) {
    moneyMonth = DateTime(moneyMonth.year, moneyMonth.month + delta, 1);
    notifyListeners();
  }

  void addSchedule({
    required String title,
    required DateTime startAt,
    String category = 'life',
  }) {
    schedules.add(
      ScheduleItem(id: _id(), title: title, startAt: startAt, category: category),
    );
    lastToast = '予定を追加しました';
    notifyListeners();
  }

  void updateSchedule(ScheduleItem item) {
    final i = schedules.indexWhere((s) => s.id == item.id);
    if (i < 0) return;
    schedules[i] = item;
    notifyListeners();
  }

  void deleteSchedule(String id) {
    schedules.removeWhere((s) => s.id == id);
    lastToast = '予定を削除しました';
    notifyListeners();
  }

  void toggleHabit(String habitId, DateTime day) {
    final i = habits.indexWhere((h) => h.id == habitId);
    if (i < 0) return;
    final key = dateKey(day);
    final next = {...habits[i].doneDays};
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    habits[i] = habits[i].copyWith(doneDays: next);
    lastToast = next.contains(key) ? '習慣を記録しました' : '習慣を取り消しました';
    notifyListeners();
    _saveUserData();
  }

  Habit addHabit({
    required String name,
    required IconData icon,
    required Color color,
  }) {
    final habit = Habit(
      id: _id(),
      name: name.trim(),
      icon: icon,
      color: color,
    );
    habits.add(habit);
    lastToast = '習慣「${habit.name}」を追加しました';
    notifyListeners();
    _saveUserData();
    return habit;
  }

  void updateHabit(Habit habit) {
    final i = habits.indexWhere((h) => h.id == habit.id);
    if (i < 0) return;
    habits[i] = habit;
    lastToast = '習慣「${habit.name}」を更新しました';
    notifyListeners();
    _saveUserData();
  }

  void deleteHabit(String id) {
    final i = habits.indexWhere((h) => h.id == id);
    if (i < 0) return;
    final name = habits[i].name;
    habits.removeAt(i);
    lastToast = '習慣「$name」を削除しました';
    notifyListeners();
    _saveUserData();
  }

  void startSleep({DateTime? at}) {
    sleepStartedAt = at ?? DateTime.now();
    lastToast = '就寝を記録しました';
    notifyListeners();
    _saveUserData();
  }

  void cancelSleep() {
    sleepStartedAt = null;
    notifyListeners();
    _saveUserData();
  }

  SleepLog? wakeUp({int quality = 3, DateTime? at}) {
    final started = sleepStartedAt;
    if (started == null) return null;
    final wake = at ?? DateTime.now();
    sleepStartedAt = null;
    return logSleep(bedAt: started, wakeAt: wake, quality: quality);
  }

  SleepLog logSleep({
    required DateTime bedAt,
    required DateTime wakeAt,
    int quality = 3,
  }) {
    var wake = wakeAt;
    var bed = bedAt;
    if (!wake.isAfter(bed)) {
      wake = bed.add(const Duration(hours: 7));
    }
    sleepLogs.removeWhere((l) => sameDay(l.wakeDate, wake));
    final log = SleepLog(
      id: _id(),
      bedAt: bed,
      wakeAt: wake,
      quality: quality.clamp(1, 5),
    );
    sleepLogs.add(log);
    sleepLogs.sort((a, b) => b.wakeAt.compareTo(a.wakeAt));
    lastToast = '睡眠 ${log.hours.toStringAsFixed(1)}時間を記録しました';
    notifyListeners();
    _saveUserData();
    return log;
  }

  void setCheckIn({
    required int mood,
    required int energy,
    List<String> tags = const [],
    String diary = '',
  }) {
    this.mood = mood;
    this.energy = energy;
    if (diary.trim().isNotEmpty) {
      setDiary(diary);
      return;
    }
    notifyListeners();
  }

  ({List<String> tags}) checkInOn(DateTime day) => (tags: const <String>[]);

  void setMood(int value) {
    mood = value;
    notifyListeners();
  }

  void setEnergy(int value) {
    energy = value;
    notifyListeners();
  }

  void setDiary(String value, {DateTime? day}) {
    final key = dateKey(day ?? lifeDate);
    final text = value.trim();
    if (text.isEmpty) {
      diaries.remove(key);
    } else {
      diaries[key] = text;
    }
    notifyListeners();
    _saveUserData();
  }

  void setTimerSubject(String? id) {
    if (timerRunning) return;
    if (id != null && id.isNotEmpty && subjectById(id) == null) return;
    timerSubjectId = id == null || id.isEmpty ? null : id;
    if (timerSubjectId != null) nextStudySubjectId = timerSubjectId!;
    notifyListeners();
  }

  String? get selectedTimerSubjectId {
    final current = timerSubjectId ?? (nextStudySubjectId.isEmpty ? null : nextStudySubjectId);
    if (current != null) {
      final subject = subjectById(current);
      if (subject != null && !subject.archived) return current;
    }
    return visibleSubjects.isEmpty ? null : visibleSubjects.first.id;
  }

  void startTimer() {
    if (timerRunning) return;
    if (timerTotalSeconds <= 0) return;
    final sid = selectedTimerSubjectId;
    if (sid == null) return;
    timerSubjectId = sid;
    timerStartedAt = DateTime.now();
    timerRunning = true;
    notifyListeners();
  }

  void pauseTimer() {
    if (!timerRunning) return;
    timerAccumulatedSeconds = timerElapsedSeconds();
    timerRunning = false;
    timerStartedAt = null;
    notifyListeners();
  }

  void finishTimer({StudyFocus focus = StudyFocus.high}) {
    final elapsed = timerElapsedSeconds();
    final sid = selectedTimerSubjectId ?? '';
    timerRunning = false;
    timerStartedAt = null;
    timerAccumulatedSeconds = 0;
    if (elapsed > 0 && sid.isNotEmpty) {
      addStudySession(
        subjectId: sid,
        minutes: (elapsed / 60).ceil().clamp(0, 24 * 60),
        focus: focus,
        loggedSeconds: elapsed,
      );
    } else {
      notifyListeners();
    }
  }

  void setTimerMinutes(int minutes) {
    if (timerRunning) return;
    timerTotalSeconds = minutes.clamp(0, 12 * 60 + 59) * 60;
    timerAccumulatedSeconds = 0;
    notifyListeners();
  }

  void addTimerPreset(int minutes) {
    final value = minutes.clamp(1, 12 * 60 + 59);
    if (settings.timerPresets.contains(value)) {
      lastToast = 'その時間はすでにあります';
      notifyListeners();
      return;
    }
    final next = [...settings.timerPresets, value]..sort();
    lastToast = '${studyGoalLabel(value)}を追加しました';
    updateSettings(settings.copyWith(timerPresets: next));
  }

  void removeTimerPreset(int minutes) {
    if (!settings.timerPresets.contains(minutes)) return;
    lastToast = '${studyGoalLabel(minutes)}を外しました';
    updateSettings(
      settings.copyWith(
        timerPresets: [...settings.timerPresets]..remove(minutes),
      ),
    );
  }

  void setDailyStudyGoalMinutes(int minutes) {
    dailyStudyGoalMinutes = minutes.clamp(10, 12 * 60);
    lastToast = '今日の勉強目標を${studyGoalLabel(dailyStudyGoalMinutes)}にしました';
    notifyListeners();
  }

  void addStudySession({
    required String subjectId,
    required int minutes,
    required StudyFocus focus,
    DateTime? at,
    int? loggedSeconds,
  }) {
    if (minutes <= 0 && (loggedSeconds == null || loggedSeconds <= 0)) return;
    final when = at ?? DateTime.now();
    sessions.insert(
      0,
      StudySession(
        id: _id(),
        subjectId: subjectId,
        minutes: minutes,
        focus: focus,
        at: when,
      ),
    );
    final seconds = loggedSeconds ?? minutes * 60;
    if (sameDay(when, DateTime.now())) {
      _rollTodayStudyIfNeeded();
      todayStudyLoggedSeconds += seconds;
    }
    _syncStudyTotals();
    lastToast = '学習を記録しました';
    notifyListeners();
    _saveUserData();
  }

  void updateStudySession(StudySession session) {
    final i = sessions.indexWhere((s) => s.id == session.id);
    if (i < 0) return;
    final prev = sessions[i];
    sessions[i] = session;
    _adjustTodayStudySeconds(prev, session);
    _syncStudyTotals();
    lastToast = '学習を更新しました';
    notifyListeners();
    _saveUserData();
  }

  void deleteStudySession(String id) {
    final i = sessions.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final prev = sessions.removeAt(i);
    _adjustTodayStudySeconds(prev, null);
    _syncStudyTotals();
    lastToast = '学習を削除しました';
    notifyListeners();
    _saveUserData();
  }

  void _adjustTodayStudySeconds(StudySession? prev, StudySession? next) {
    _rollTodayStudyIfNeeded();
    final today = dateOnly(DateTime.now());
    if (prev != null && sameDay(prev.at, today)) {
      todayStudyLoggedSeconds = (todayStudyLoggedSeconds - prev.minutes * 60).clamp(0, 24 * 3600);
    }
    if (next != null && sameDay(next.at, today)) {
      todayStudyLoggedSeconds += next.minutes * 60;
    }
  }

  void addAssignment({
    required String subjectId,
    required String title,
    required DateTime dueAt,
  }) {
    assignments.add(
      Assignment(id: _id(), subjectId: subjectId, title: title, dueAt: dateOnly(dueAt)),
    );
    assignments.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    lastToast = '提出物を追加しました';
    notifyListeners();
  }

  void addExam({
    required String title,
    required DateTime examAt,
  }) {
    const palette = [
      Color(0xFF9B6BFF),
      Color(0xFF00D4FF),
      Color(0xFF3DFF8A),
      Color(0xFFFFC857),
    ];
    exams.add(
      Exam(
        id: _id(),
        title: title,
        examAt: dateOnly(examAt),
        createdAt: dateOnly(focusedDate),
        color: palette[exams.length % palette.length],
        weekdayLabel: weekdayLabelOf(examAt),
      ),
    );
    exams.sort((a, b) => a.examAt.compareTo(b.examAt));
    lastToast = '試験日を追加しました';
    notifyListeners();
    _saveUserData();
  }

  void deleteExam(String id) {
    final before = exams.length;
    exams.removeWhere((e) => e.id == id);
    if (exams.length == before) return;
    lastToast = '試験日を削除しました';
    notifyListeners();
    _saveUserData();
  }

  void addGoal({
    required String title,
    required int current,
    required int target,
    required DateTime dueAt,
    required List<String> subGoalTitles,
  }) {
    final subs = [
      for (final text in subGoalTitles)
        if (text.trim().isNotEmpty) SubGoal(title: text.trim()),
    ];
    goals.add(
      StudyGoal(
        id: _id(),
        title: title,
        current: current,
        target: target < 0 ? 0 : target,
        dueAt: dateOnly(dueAt),
        subGoals: subs,
      ),
    );
    lastToast = '目標を追加しました';
    notifyListeners();
    _saveUserData();
  }

  void deleteGoal(String id) {
    final before = goals.length;
    goals.removeWhere((g) => g.id == id);
    if (goals.length == before) return;
    lastToast = '目標を削除しました';
    notifyListeners();
    _saveUserData();
  }

  void toggleSubGoal(String goalId, int index) {
    final i = goals.indexWhere((g) => g.id == goalId);
    if (i < 0 || index < 0 || index >= goals[i].subGoals.length) return;
    final next = [...goals[i].subGoals];
    next[index] = next[index].copyWith(done: !next[index].done);
    goals[i] = goals[i].copyWith(subGoals: next);
    notifyListeners();
  }

  ProblemRecord addProblem({
    required String subjectId,
    required String title,
    Uint8List? photoBytes,
    String answer = '',
  }) {
    final learnedAt = focusedDate;
    final problem = ProblemRecord(
      id: _id(),
      subjectId: subjectId,
      title: title,
      learnedAt: learnedAt,
      photoBytes: photoBytes,
      answer: answer,
    );
    problems.insert(0, problem);
    reviewCards.addAll(
      ReviewScheduler.cardsFor(
        problemId: problem.id,
        learnedAt: learnedAt,
        nextId: _id,
      ),
    );
    lastToast = '問題を記録し、1日後と5日後の復習カードを作りました';
    notifyListeners();
    return problem;
  }

  void rateReview(String cardId, ReviewRating rating) {
    final i = reviewCards.indexWhere((c) => c.id == cardId);
    if (i < 0) return;
    reviewCards[i] = reviewCards[i].copyWith(
      status: 'done',
      lastRating: rating,
    );
    notifyListeners();
  }

  void addExpense({required String boxId, required int amount, required String note}) {
    addMoneyCard(
      boxId: boxId,
      title: note.isEmpty ? '支出' : note,
      amount: amount,
      at: focusedDate,
      kind: MoneyCardKind.spend,
    );
  }

  StudySubject addSubject({
    required String name,
    IconData? icon,
    Color? color,
  }) {
    const palette = NexusColors.boxPalette;
    final n = visibleSubjects.length;
    final subject = StudySubject(
      id: _id(),
      name: name.trim(),
      color: color ?? palette[n % palette.length],
      weekHours: 0,
      icon: icon ?? kStudyIcons[n % kStudyIcons.length],
    );
    subjects.add(subject);
    lastToast = '教科「${subject.name}」を追加しました';
    notifyListeners();
    _saveUserData();
    return subject;
  }

  void updateSubject(StudySubject subject) {
    final i = subjects.indexWhere((s) => s.id == subject.id);
    if (i < 0) return;
    subjects[i] = subject;
    lastToast = '教科を更新しました';
    notifyListeners();
    _saveUserData();
  }

  void reorderSubjects(int oldIndex, int newIndex) {
    final vis = visibleSubjects;
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 || oldIndex >= vis.length) return;
    if (newIndex < 0 || newIndex >= vis.length) return;
    final original = [...subjects];
    final reordered = [...vis];
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    var i = 0;
    final visibleIds = {for (final s in vis) s.id};
    subjects
      ..clear()
      ..addAll([
        for (final s in original)
          if (visibleIds.contains(s.id)) reordered[i++] else s,
      ]);
    notifyListeners();
    _saveUserData();
  }

  void reorderBoxes(int oldIndex, int newIndex) {
    final vis = visibleBoxes;
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 || oldIndex >= vis.length) return;
    if (newIndex < 0 || newIndex >= vis.length) return;
    final original = [...boxes];
    final reordered = [...vis];
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    var i = 0;
    final visibleIds = {for (final box in vis) box.id};
    boxes
      ..clear()
      ..addAll([
        for (final box in original)
          if (visibleIds.contains(box.id)) reordered[i++] else box,
      ]);
    notifyListeners();
    _saveUserData();
  }

  void shiftSubject(int index, int delta) {
    final vis = visibleSubjects;
    final next = index + delta;
    if (index < 0 || index >= vis.length) return;
    if (next < 0 || next >= vis.length) return;
    reorderSubjects(index, delta > 0 ? next + 1 : next);
  }

  void shiftBox(int index, int delta) {
    final next = index + delta;
    if (index < 0 || index >= boxes.length) return;
    if (next < 0 || next >= boxes.length) return;
    final item = boxes.removeAt(index);
    boxes.insert(next, item);
    notifyListeners();
    _saveUserData();
  }

  List<double> subjectWeekHours(String subjectId) {
    final monday = weekMonday(focusedDate);
    final hours = List<double>.filled(7, 0);
    for (final session in sessions) {
      if (session.subjectId != subjectId) continue;
      final idx = dateOnly(session.at).difference(monday).inDays;
      if (idx < 0 || idx > 6) continue;
      hours[idx] += session.minutes / 60.0;
    }
    return hours;
  }

  void deleteSubject(String id) {
    final i = subjects.indexWhere((s) => s.id == id);
    if (i < 0 || subjects[i].archived) return;
    subjects[i] = subjects[i].copyWith(archived: true);
    if (timerSubjectId == id) timerSubjectId = null;
    if (nextStudySubjectId == id) {
      nextStudySubjectId = visibleSubjects.isEmpty ? '' : visibleSubjects.first.id;
    }
    _refreshWeekBars();
    lastToast = '教科を削除しました';
    notifyListeners();
    _saveUserData();
  }

  void addIncome({
    required String name,
    required int amount,
    required DateTime depositedAt,
    required int useYear,
    required int useMonth,
    String memo = '',
  }) {
    incomes.insert(
      0,
      IncomeEntry(
        id: _id(),
        name: name,
        amount: amount,
        depositedAt: depositedAt,
        useYear: useYear,
        useMonth: useMonth,
        memo: memo,
      ),
    );
    lastToast = '収入を追加しました';
    notifyListeners();
    _saveUserData();
  }

  void updateIncome(IncomeEntry entry) {
    final i = incomes.indexWhere((e) => e.id == entry.id);
    if (i < 0) return;
    incomes[i] = entry;
    lastToast = '収入を更新しました';
    notifyListeners();
    _saveUserData();
  }

  void deleteIncome(String id) {
    final before = incomes.length;
    incomes.removeWhere((e) => e.id == id);
    if (incomes.length == before) return;
    lastToast = '収入を削除しました';
    notifyListeners();
    _saveUserData();
  }

  List<IncomeEntry> get incomeHistory {
    final list = [...incomes];
    list.sort((a, b) => b.depositedAt.compareTo(a.depositedAt));
    return list;
  }

  List<MoneyCard> get spendHistory {
    final list = [for (final card in cards) if (card.kind == MoneyCardKind.spend) card];
    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  List<String> get expenseTags {
    final tags = <String>{};
    for (final card in cards) {
      if (card.kind != MoneyCardKind.spend) continue;
      final tag = card.tag.trim();
      if (tag.isNotEmpty) tags.add(tag);
    }
    for (final box in boxes) {
      for (final tag in box.tags) {
        final text = tag.trim();
        if (text.isNotEmpty) tags.add(text);
      }
    }
    final list = tags.toList()..sort();
    return list;
  }

  List<IncomeEntry> incomesInMonth(DateTime month) {
    return [
      for (final item in incomeHistory)
        if (item.useYear == month.year && item.useMonth == month.month) item,
    ];
  }

  List<MoneyCard> spendCardsInMonth(DateTime month) {
    return [
      for (final card in spendHistory)
        if (sameMonth(card.at, month)) card,
    ];
  }

  List<String> expenseTagsInMonth(DateTime month) {
    final tags = <String>{};
    for (final card in spendCardsInMonth(month)) {
      final tag = card.tag.trim();
      if (tag.isNotEmpty) tags.add(tag);
    }
    for (final box in boxes) {
      if (!box.isSavings && !_boxInMonth(box, month)) continue;
      for (final tag in box.tags) {
        final text = tag.trim();
        if (text.isNotEmpty) tags.add(text);
      }
    }
    final list = tags.toList()..sort();
    return list;
  }

  BudgetBox addBudgetBox({
    required String name,
    required IconData icon,
    required Color color,
    required int monthlyBudget,
    required List<String> tags,
    String memo = '',
    DateTime? month,
  }) {
    final assigned = monthStart(month ?? moneyMonth);
    final box = BudgetBox(
      id: _id(),
      name: name,
      kind: BoxKind.budget,
      monthlyBudget: monthlyBudget,
      color: color,
      icon: icon,
      tags: tags,
      month: assigned,
      memo: memo,
    );
    boxes.add(box);
    lastToast = 'ボックス「$name」を追加しました';
    notifyListeners();
    _saveUserData();
    return box;
  }

  BudgetBox addSavingsBox({
    required String name,
    required IconData icon,
    required Color color,
    required int targetAmount,
    required int openingAmount,
    DateTime? targetDate,
    required List<String> tags,
    String memo = '',
  }) {
    final box = BudgetBox(
      id: _id(),
      name: name,
      kind: BoxKind.savings,
      monthlyBudget: 0,
      color: color,
      icon: icon,
      tags: tags,
      targetAmount: targetAmount,
      openingAmount: openingAmount,
      targetDate: targetDate,
      memo: memo,
    );
    boxes.add(box);
    lastToast = '貯蓄ボックス「$name」を追加しました';
    notifyListeners();
    _saveUserData();
    return box;
  }

  void addBoxTag(String boxId, String tag) {
    final i = boxes.indexWhere((b) => b.id == boxId);
    if (i < 0) return;
    final name = tag.trim();
    if (name.isEmpty || boxes[i].tags.contains(name)) return;
    boxes[i] = boxes[i].copyWith(tags: [...boxes[i].tags, name]);
    notifyListeners();
    _saveUserData();
  }

  MoneyCard addMoneyCard({
    required String boxId,
    required String title,
    required int amount,
    required DateTime at,
    String tag = '',
    String memo = '',
    MoneyCardKind kind = MoneyCardKind.spend,
  }) {
    final card = MoneyCard(
      id: _id(),
      boxId: boxId,
      title: title,
      amount: amount,
      at: at,
      tag: tag,
      memo: memo,
      kind: kind,
    );
    cards.insert(0, card);
    lastToast = 'カードを追加しました';
    notifyListeners();
    _saveUserData();
    return card;
  }

  void updateMoneyCard(MoneyCard card) {
    final i = cards.indexWhere((c) => c.id == card.id);
    if (i < 0) return;
    cards[i] = card;
    lastToast = 'カードを更新しました';
    notifyListeners();
    _saveUserData();
  }

  void deleteMoneyCard(String id) {
    final before = cards.length;
    cards.removeWhere((c) => c.id == id);
    if (cards.length == before) return;
    lastToast = 'カードを削除しました';
    notifyListeners();
    _saveUserData();
  }

  void deleteBox(String id) {
    if (boxes.every((b) => b.id != id)) return;
    cards.removeWhere((c) => c.boxId == id);
    for (var i = 0; i < payments.length; i++) {
      if (payments[i].boxId == id) {
        payments[i] = payments[i].copyWith(clearBoxId: true);
      }
    }
    boxes.removeWhere((b) => b.id == id);
    lastToast = 'ボックスを削除しました';
    notifyListeners();
    _saveUserData();
  }

  void updateBox(BudgetBox box) {
    final i = boxes.indexWhere((b) => b.id == box.id);
    if (i < 0) return;
    boxes[i] = box;
    lastToast = 'ボックスを更新しました';
    notifyListeners();
    _saveUserData();
  }

  void deletePayment(String id) {
    final before = payments.length;
    payments.removeWhere((p) => p.id == id);
    if (payments.length == before) return;
    lastToast = '支払予定を削除しました';
    notifyListeners();
    _saveUserData();
  }

  void addPaymentPlan({
    required String title,
    required int amount,
    required DateTime dueAt,
    String? boxId,
    PaymentRepeat repeat = PaymentRepeat.none,
    String memo = '',
  }) {
    payments.add(
      PaymentPlan(
        id: _id(),
        title: title,
        amount: amount,
        dueAt: dateOnly(dueAt),
        boxId: boxId,
        repeat: repeat,
        memo: memo,
      ),
    );
    payments.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    lastToast = '支払予定を追加しました';
    notifyListeners();
    _saveUserData();
  }

  Future<void> hydrate() async {
    final data = await NexusPrefs.loadBundle(dataUid);
    if (data != null) applyCloudMap(data);
    _canSave = true;
    notifyListeners();
  }

  Future<void> attachCloud(NexusCloud cloud) async {
    _cloud = cloud;
    dataUid = cloud.uid;
    _canSave = false;
    final local = await NexusPrefs.loadBundle(dataUid);
    if (local != null) applyCloudMap(local);
    try {
      final remote = await cloud.pullLive();
      if (remote != null && _isRemoteNewer(remote, local)) {
        applyCloudMap(remote);
      } else if (local != null) {
        await cloud.pushLive(toCloudMap());
      } else if (remote != null) {
        applyCloudMap(remote);
      }
    } catch (_) {}
    if (cloud.session != null) {
      if (userName == '蒼井 ユウ' && cloud.session!.displayName.isNotEmpty) {
        userName = cloud.session!.displayName;
      }
      if (occupation.isEmpty) occupation = cloud.session!.occupation;
    }
    _canSave = true;
    _saveUserData();
    try {
      final vault = await cloud.listVault();
      if (vault.isEmpty) {
        await cloud.sealVault('初回保管', toCloudMap());
      }
    } catch (_) {}
    notifyListeners();
  }

  void detachCloud() {
    _cloudPush?.cancel();
    _cloud = null;
    dataUid = null;
    subjects.clear();
    sessions.clear();
    exams.clear();
    goals.clear();
    boxes.clear();
    cards.clear();
    incomes.clear();
    payments.clear();
    habits.clear();
    sleepLogs.clear();
    schedules.clear();
    assignments.clear();
    problems.clear();
    reviewCards.clear();
    diaries.clear();
    _seed();
    notifyListeners();
  }

  bool _isRemoteNewer(Map<String, dynamic> remote, Map<String, dynamic>? local) {
    final remoteAt = remote['updatedAt'] as int? ?? 0;
    final localAt = local?['updatedAt'] as int? ?? 0;
    return remoteAt >= localAt;
  }

  Map<String, dynamic> toCloudMap() {
    return {
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'userName': userName,
      'occupation': occupation,
      'dailyStudyGoalMinutes': dailyStudyGoalMinutes,
      'todayStudyDate': todayStudyDate.toIso8601String(),
      'todayStudyLoggedSeconds': todayStudyLoggedSeconds,
      'totalStudyHours': totalStudyHours,
      'settings': settings.toJson(),
      'diaries': diaries,
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
      'schedules': [for (final s in schedules) s.toJson()],
      'assignments': [for (final a in assignments) a.toJson()],
      'problems': [for (final p in problems) p.toJson()],
      'reviewCards': [for (final c in reviewCards) c.toJson()],
    };
  }

  void applyCloudMap(Map<String, dynamic> data) {
    final savedSubjects = [
      for (final item in (data['subjects'] as List? ?? const []))
        StudySubject.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
    if (savedSubjects.isNotEmpty || data.containsKey('subjects')) {
      subjects
        ..clear()
        ..addAll(savedSubjects);
    }
    if (data.containsKey('sessions')) {
      sessions
        ..clear()
        ..addAll([
          for (final item in (data['sessions'] as List? ?? const []))
            StudySession.fromJson(Map<String, dynamic>.from(item as Map)),
        ]);
    }
    _syncStudyTotals();
    if (data.containsKey('exams')) {
      exams
        ..clear()
        ..addAll([
          for (final item in (data['exams'] as List? ?? const []))
            Exam.fromJson(Map<String, dynamic>.from(item as Map)),
        ]);
    }
    if (data.containsKey('goals')) {
      goals
        ..clear()
        ..addAll([
          for (final item in (data['goals'] as List? ?? const []))
            StudyGoal.fromJson(Map<String, dynamic>.from(item as Map)),
        ]);
    }
    if (data.containsKey('schedules')) {
      schedules
        ..clear()
        ..addAll([
          for (final item in (data['schedules'] as List? ?? const []))
            ScheduleItem.fromJson(Map<String, dynamic>.from(item as Map)),
        ]);
    }
    if (data.containsKey('assignments')) {
      assignments
        ..clear()
        ..addAll([
          for (final item in (data['assignments'] as List? ?? const []))
            Assignment.fromJson(Map<String, dynamic>.from(item as Map)),
        ]);
    }
    if (data.containsKey('problems')) {
      problems
        ..clear()
        ..addAll([
          for (final item in (data['problems'] as List? ?? const []))
            ProblemRecord.fromJson(Map<String, dynamic>.from(item as Map)),
        ]);
    }
    if (data.containsKey('reviewCards')) {
      reviewCards
        ..clear()
        ..addAll([
          for (final item in (data['reviewCards'] as List? ?? const []))
            ReviewCard.fromJson(Map<String, dynamic>.from(item as Map)),
        ]);
    }
    final savedBoxes = [
      for (final item in (data['boxes'] as List? ?? const []))
        BudgetBox.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
    final savedCards = [
      for (final item in (data['cards'] as List? ?? const []))
        MoneyCard.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
    final savedIncomes = [
      for (final item in (data['incomes'] as List? ?? const []))
        IncomeEntry.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
    final savedPayments = [
      for (final item in (data['payments'] as List? ?? const []))
        PaymentPlan.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
    if (savedBoxes.isNotEmpty || data.containsKey('boxes')) {
      boxes
        ..clear()
        ..addAll(savedBoxes);
      _assignLegacyBoxMonths();
    }
    if (savedCards.isNotEmpty || savedBoxes.isNotEmpty || data.containsKey('cards')) {
      cards
        ..clear()
        ..addAll(savedCards);
    }
    if (savedIncomes.isNotEmpty || data.containsKey('incomes')) {
      incomes
        ..clear()
        ..addAll(savedIncomes);
    }
    if (savedPayments.isNotEmpty || data.containsKey('payments')) {
      payments
        ..clear()
        ..addAll(savedPayments);
    }
    if (data.containsKey('habits')) {
      habits
        ..clear()
        ..addAll([
          for (final item in (data['habits'] as List? ?? const []))
            Habit.fromJson(Map<String, dynamic>.from(item as Map)),
        ]);
    }
    if (data.containsKey('sleepLogs')) {
      sleepLogs
        ..clear()
        ..addAll([
          for (final item in (data['sleepLogs'] as List? ?? const []))
            SleepLog.fromJson(Map<String, dynamic>.from(item as Map)),
        ]);
    }
    final started = data['sleepStartedAt'] as String?;
    sleepStartedAt = started == null || started.isEmpty ? null : DateTime.tryParse(started);
    final savedName = (data['userName'] as String?)?.trim();
    if (savedName != null && savedName.isNotEmpty) {
      userName = savedName;
    }
    occupation = (data['occupation'] as String?)?.trim() ?? occupation;
    final goal = data['dailyStudyGoalMinutes'] as int?;
    if (goal != null) dailyStudyGoalMinutes = goal;
    diaries.clear();
    final rawDiaries = data['diaries'];
    if (rawDiaries is Map) {
      for (final entry in rawDiaries.entries) {
        final text = entry.value?.toString() ?? '';
        if (text.isNotEmpty) diaries[entry.key.toString()] = text;
      }
    }
    final legacyDiary = (data['diary'] as String?)?.trim();
    if (legacyDiary != null && legacyDiary.isNotEmpty && diaries.isEmpty) {
      diaries[dateKey(DateTime.now())] = legacyDiary;
    }
    final rawSettings = data['settings'];
    if (rawSettings is Map) {
      settings = UserSettings.fromJson(Map<String, dynamic>.from(rawSettings));
    } else if (data['themeId'] is String) {
      settings = settings.copyWith(
        themeId: UserSettings.normalizeThemeId(data['themeId'] as String),
      );
    }
    NexusColors.apply(NexusPalette.byId(settings.themeId));
  }

  void _assignLegacyBoxMonths() {
    final fallback = monthStart(moneyMonth);
    for (var i = 0; i < boxes.length; i++) {
      final box = boxes[i];
      if (box.isSavings || box.month != null) continue;
      boxes[i] = box.copyWith(month: fallback);
    }
  }

  void _saveUserData() {
    if (!_canSave) return;
    final bundle = toCloudMap();
    NexusPrefs.saveBundle(dataUid, bundle);
    _cloudPush?.cancel();
    _cloudPush = Timer(const Duration(milliseconds: 400), () {
      _cloud?.pushLive(bundle);
    });
  }

  void sendUserMessage(String text) {
    messages.add(
      ChatMessage(id: _id(), fromUser: true, text: text, at: DateTime.now()),
    );
    messages.add(
      ChatMessage(
        id: _id(),
        fromUser: false,
        text: _replyFor(text),
        at: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  String _replyFor(String text) {
    if (text.contains('学習')) {
      return '数学を30分だけ先に確保するのはどう？プランとして出すネグ。';
    }
    if (text.contains('予定') || text.contains('整理')) {
      return '今日は学校・カフェ・テレビが入ってるネグ。詰まりそうならテレビを短くできるよ。';
    }
    if (text.contains('相談')) {
      return 'いまの予定と学習だけを見て考えるネグ。お金の詳細は許可がないから見てないよ。';
    }
    return '今日の予定、少し詰まってるネグ。数学を30分だけ先にやる？';
  }

  void createDefaultProposal() {
    final tv = schedules.cast<ScheduleItem?>().firstWhere(
          (s) => s?.title == 'テレビ',
          orElse: () => null,
        );
    if (tv == null) return;
    proposal = AiProposal(
      id: _id(),
      rationale: '集中しやすい時間を先に確保するため',
      summary: '数学を30分前倒しし、20:00のテレビを30分短縮する',
      scheduleId: tv.id,
      newStartAt: tv.startAt.add(const Duration(minutes: 30)),
    );
    notifyListeners();
  }

  bool approveProposal() {
    final p = proposal;
    if (p == null || p.status != ProposalStatus.pending) return false;
    final i = schedules.indexWhere((s) => s.id == p.scheduleId);
    if (i < 0) return false;
    schedules[i] = schedules[i].copyWith(startAt: p.newStartAt);
    proposal = p.copyWith(status: ProposalStatus.approved);
    lastToast = 'プランを反映しました';
    notifyListeners();
    return true;
  }

  void rejectProposal() {
    final p = proposal;
    if (p == null) return;
    proposal = p.copyWith(status: ProposalStatus.rejected);
    lastToast = 'プランは反映していません';
    notifyListeners();
  }

  void setUserName(String value) {
    userName = value;
    notifyListeners();
    _saveUserData();
  }

  void setOccupation(String value) {
    occupation = value.trim();
    notifyListeners();
    _saveUserData();
  }

  void updateSettings(UserSettings next) {
    settings = next;
    NexusColors.apply(NexusPalette.byId(next.themeId));
    notifyListeners();
    _saveUserData();
  }

  void _seed() {
    final today = dateOnly(DateTime.now());
    focusedDate = today;
    lifeDate = today;
    moneyMonth = today;
    studyWeek = today;
    todayStudyDate = today;
    income = 0;
    weekStudyHours = 0;
    totalStudyHours = 0;
    weekBars = List.filled(7, 0);
    nextTaskTitle = '';
    nextTaskDuration = '';
    nextStudySubjectId = '';
    nextStudyPlace = '';
    mood = 0;
    energy = 0;
    steps = 0;
    diaries.clear();
    proposal = null;
    occupation = '';
    userName = '蒼井 ユウ';
    dailyStudyGoalMinutes = 120;
    todayStudyLoggedSeconds = 0;
    settings = const UserSettings();
    NexusColors.apply(NexusPalette.byId(settings.themeId));
    tabIndex = NexusTab.home;
    messages.clear();
    timerRunning = false;
    timerStartedAt = null;
    timerSubjectId = null;
    timerAccumulatedSeconds = 0;
    timerTotalSeconds = 30 * 60;
  }

  @override
  void dispose() {
    _cloudPush?.cancel();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({
    super.key,
    required AppStore store,
    required super.child,
  }) : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope が見つかりません');
    return scope!.notifier!;
  }
}
