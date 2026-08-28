import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/format.dart';
import 'nexus_icons.dart';

enum StudyFocus {
  low,
  mid,
  high,
  peak;

  String get label => switch (this) {
        low => 'いまいち',
        mid => 'ふつう',
        high => '集中',
        peak => '最高',
      };
}

enum ReviewRating { again, hard, normal, easy }

enum ProposalStatus { draft, pending, approved, rejected }

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.title,
    required this.startAt,
    this.endAt,
    this.allDay = false,
    this.location,
    this.category = 'life',
    this.source = 'user',
  });

  final String id;
  final String title;
  final DateTime startAt;
  final DateTime? endAt;
  final bool allDay;
  final String? location;
  final String category;
  final String source;

  ScheduleItem copyWith({
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    String? location,
  }) {
    return ScheduleItem(
      id: id,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      allDay: allDay,
      location: location ?? this.location,
      category: category,
      source: source,
    );
  }
}

class StudySubject {
  const StudySubject({
    required this.id,
    required this.name,
    required this.color,
    required this.weekHours,
    required this.icon,
  });

  final String id;
  final String name;
  final Color color;
  final double weekHours;
  final IconData icon;

  StudySubject copyWith({double? weekHours, String? name, Color? color, IconData? icon}) {
    return StudySubject(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      weekHours: weekHours ?? this.weekHours,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.toARGB32(),
        'weekHours': weekHours,
        'icon': icon.codePoint,
      };

  factory StudySubject.fromJson(Map<String, dynamic> json) {
    return StudySubject(
      id: json['id'] as String,
      name: json['name'] as String,
      color: Color(json['color'] as int),
      weekHours: (json['weekHours'] as num).toDouble(),
      icon: nexusIconFromCode(json['icon'] as int),
    );
  }
}

class StudySession {
  const StudySession({
    required this.id,
    required this.subjectId,
    required this.minutes,
    required this.focus,
    required this.at,
  });

  final String id;
  final String subjectId;
  final int minutes;
  final StudyFocus focus;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'minutes': minutes,
        'focus': focus.name,
        'at': at.toIso8601String(),
      };

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String? ?? '',
      minutes: json['minutes'] as int? ?? 0,
      focus: StudyFocus.values.firstWhere(
        (value) => value.name == json['focus'],
        orElse: () => StudyFocus.high,
      ),
      at: DateTime.parse(json['at'] as String),
    );
  }
}

class SubGoal {
  const SubGoal({required this.title, this.done = false});

  final String title;
  final bool done;

  SubGoal copyWith({String? title, bool? done}) {
    return SubGoal(title: title ?? this.title, done: done ?? this.done);
  }

  Map<String, dynamic> toJson() => {'title': title, 'done': done};

  factory SubGoal.fromJson(Map<String, dynamic> json) {
    return SubGoal(
      title: json['title'] as String? ?? '',
      done: json['done'] as bool? ?? false,
    );
  }
}

class StudyGoal {
  const StudyGoal({
    required this.id,
    required this.title,
    required this.current,
    required this.target,
    required this.dueAt,
    required this.subGoals,
  });

  final String id;
  final String title;
  final int current;
  final int target;
  final DateTime dueAt;
  final List<SubGoal> subGoals;

  List<SubGoal> get filledSubGoals =>
      subGoals.where((s) => s.title.trim().isNotEmpty).toList();

  double get progress {
    final filled = filledSubGoals;
    if (filled.isNotEmpty) {
      return filled.where((s) => s.done).length / filled.length;
    }
    if (target <= 0) return 0;
    return (current / target).clamp(0, 1);
  }

  StudyGoal copyWith({List<SubGoal>? subGoals, int? current}) {
    return StudyGoal(
      id: id,
      title: title,
      current: current ?? this.current,
      target: target,
      dueAt: dueAt,
      subGoals: subGoals ?? this.subGoals,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'current': current,
        'target': target,
        'dueAt': dueAt.toIso8601String(),
        'subGoals': [for (final s in subGoals) s.toJson()],
      };

  factory StudyGoal.fromJson(Map<String, dynamic> json) {
    return StudyGoal(
      id: json['id'] as String,
      title: json['title'] as String,
      current: json['current'] as int? ?? 0,
      target: json['target'] as int? ?? 0,
      dueAt: DateTime.parse(json['dueAt'] as String),
      subGoals: [
        for (final item in (json['subGoals'] as List? ?? const []))
          SubGoal.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
    );
  }
}

class Assignment {
  const Assignment({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.dueAt,
    this.done = false,
  });

  final String id;
  final String subjectId;
  final String title;
  final DateTime dueAt;
  final bool done;
}

class Exam {
  const Exam({
    required this.id,
    required this.title,
    required this.examAt,
    required this.color,
    required this.weekdayLabel,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? examAt;

  final String id;
  final String title;
  final DateTime examAt;
  final Color color;
  final String weekdayLabel;
  final DateTime createdAt;

  double countdownProgress(DateTime today) {
    final start = dateOnly(createdAt);
    final end = dateOnly(examAt);
    final now = dateOnly(today);
    final total = end.difference(start).inDays;
    if (total <= 0) return now.isBefore(end) ? 0 : 1;
    return (now.difference(start).inDays / total).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'examAt': examAt.toIso8601String(),
        'color': color.toARGB32(),
        'weekdayLabel': weekdayLabel,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Exam.fromJson(Map<String, dynamic> json) {
    final examAt = DateTime.parse(json['examAt'] as String);
    return Exam(
      id: json['id'] as String,
      title: json['title'] as String,
      examAt: examAt,
      color: Color(json['color'] as int),
      weekdayLabel: json['weekdayLabel'] as String? ?? weekdayLabelOf(examAt),
      createdAt: json['createdAt'] == null ? examAt : DateTime.parse(json['createdAt'] as String),
    );
  }
}

class LearningEntry {
  const LearningEntry({
    required this.id,
    required this.author,
    required this.subject,
    required this.body,
    required this.visibility,
    required this.learnedAt,
    this.helpful = 0,
  });

  final String id;
  final String author;
  final String subject;
  final String body;
  final String visibility;
  final DateTime learnedAt;
  final int helpful;
}

class ProblemRecord {
  const ProblemRecord({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.learnedAt,
    this.photoBytes,
    this.answer = '',
  });

  final String id;
  final String subjectId;
  final String title;
  final DateTime learnedAt;
  final Uint8List? photoBytes;
  final String answer;
}

class ReviewCard {
  const ReviewCard({
    required this.id,
    required this.problemId,
    required this.dueAt,
    required this.intervalStep,
    this.status = 'pending',
    this.lastRating,
  });

  final String id;
  final String problemId;
  final DateTime dueAt;
  final int intervalStep;
  final String status;
  final ReviewRating? lastRating;

  ReviewCard copyWith({String? status, ReviewRating? lastRating}) {
    return ReviewCard(
      id: id,
      problemId: problemId,
      dueAt: dueAt,
      intervalStep: intervalStep,
      status: status ?? this.status,
      lastRating: lastRating ?? this.lastRating,
    );
  }
}

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.doneDays = const {},
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final Set<String> doneDays;

  bool doneOn(DateTime day) => doneDays.contains(dateKey(day));

  int streakEndingOn(DateTime day) {
    if (!doneOn(day)) return 0;
    var count = 0;
    var cursor = dateOnly(day);
    while (doneOn(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  int currentStreak(DateTime today) {
    final day = dateOnly(today);
    if (doneOn(day)) return streakEndingOn(day);
    return streakEndingOn(day.subtract(const Duration(days: 1)));
  }

  Habit copyWith({
    String? name,
    IconData? icon,
    Color? color,
    Set<String>? doneDays,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      doneDays: doneDays ?? this.doneDays,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon.codePoint,
        'color': color.toARGB32(),
        'doneDays': doneDays.toList(),
      };

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: nexusIconFromCode(json['icon'] as int? ?? 0),
      color: Color(json['color'] as int? ?? 0xFF00D4FF),
      doneDays: {
        for (final d in (json['doneDays'] as List? ?? const [])) d.toString(),
      },
    );
  }
}

class SleepLog {
  const SleepLog({
    required this.id,
    required this.bedAt,
    required this.wakeAt,
    this.quality = 3,
  });

  final String id;
  final DateTime bedAt;
  final DateTime wakeAt;
  final int quality;

  DateTime get wakeDate => dateOnly(wakeAt);

  double get hours {
    final minutes = wakeAt.difference(bedAt).inMinutes;
    if (minutes <= 0) return 0;
    return minutes / 60.0;
  }

  String get qualityLabel => switch (quality) {
        1 => '浅い',
        2 => 'いまいち',
        3 => '普通',
        4 => 'よい',
        _ => 'とてもよい',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'bedAt': bedAt.toIso8601String(),
        'wakeAt': wakeAt.toIso8601String(),
        'quality': quality,
      };

  factory SleepLog.fromJson(Map<String, dynamic> json) {
    return SleepLog(
      id: json['id'] as String,
      bedAt: DateTime.parse(json['bedAt'] as String),
      wakeAt: DateTime.parse(json['wakeAt'] as String),
      quality: json['quality'] as int? ?? 3,
    );
  }
}

enum BoxKind { budget, savings }

enum MoneyCardKind { spend, saveIn, saveOut }

enum PaymentRepeat { none, monthly, yearly }

class BudgetBox {
  const BudgetBox({
    required this.id,
    required this.name,
    required this.monthlyBudget,
    required this.color,
    required this.icon,
    this.kind = BoxKind.budget,
    this.spent = 0,
    this.tags = const [],
    this.renewalDay = 1,
    this.memo = '',
    this.targetAmount = 0,
    this.openingAmount = 0,
    this.targetDate,
  });

  final String id;
  final String name;
  final BoxKind kind;
  final int monthlyBudget;
  final int spent;
  final Color color;
  final IconData icon;
  final List<String> tags;
  final int renewalDay;
  final String memo;
  final int targetAmount;
  final int openingAmount;
  final DateTime? targetDate;

  bool get isSavings => kind == BoxKind.savings;

  int get remaining => monthlyBudget - spent;
  double get usedRatio => monthlyBudget == 0 ? 0 : spent / monthlyBudget;
  double get savingsProgress =>
      targetAmount == 0 ? 0 : (openingAmount / targetAmount).clamp(0, 1);

  BudgetBox copyWith({
    String? name,
    int? monthlyBudget,
    int? spent,
    List<String>? tags,
    int? renewalDay,
    String? memo,
    int? targetAmount,
    int? openingAmount,
    DateTime? targetDate,
    IconData? icon,
    Color? color,
  }) {
    return BudgetBox(
      id: id,
      name: name ?? this.name,
      kind: kind,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      spent: spent ?? this.spent,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      tags: tags ?? this.tags,
      renewalDay: renewalDay ?? this.renewalDay,
      memo: memo ?? this.memo,
      targetAmount: targetAmount ?? this.targetAmount,
      openingAmount: openingAmount ?? this.openingAmount,
      targetDate: targetDate ?? this.targetDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'monthlyBudget': monthlyBudget,
        'color': color.toARGB32(),
        'icon': icon.codePoint,
        'tags': tags,
        'renewalDay': renewalDay,
        'memo': memo,
        'targetAmount': targetAmount,
        'openingAmount': openingAmount,
        'targetDate': targetDate?.toIso8601String(),
      };

  factory BudgetBox.fromJson(Map<String, dynamic> json) {
    return BudgetBox(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: json['kind'] == 'savings' ? BoxKind.savings : BoxKind.budget,
      monthlyBudget: json['monthlyBudget'] as int? ?? 0,
      color: Color(json['color'] as int),
      icon: nexusIconFromCode(json['icon'] as int),
      tags: [for (final t in (json['tags'] as List? ?? const [])) t.toString()],
      renewalDay: json['renewalDay'] as int? ?? 1,
      memo: json['memo'] as String? ?? '',
      targetAmount: json['targetAmount'] as int? ?? 0,
      openingAmount: json['openingAmount'] as int? ?? 0,
      targetDate: json['targetDate'] == null ? null : DateTime.parse(json['targetDate'] as String),
    );
  }
}

class MoneyCard {
  const MoneyCard({
    required this.id,
    required this.boxId,
    required this.title,
    required this.amount,
    required this.at,
    this.tag = '',
    this.memo = '',
    this.kind = MoneyCardKind.spend,
  });

  final String id;
  final String boxId;
  final String title;
  final int amount;
  final DateTime at;
  final String tag;
  final String memo;
  final MoneyCardKind kind;

  MoneyCard copyWith({
    String? boxId,
    String? title,
    int? amount,
    DateTime? at,
    String? tag,
    String? memo,
    MoneyCardKind? kind,
  }) {
    return MoneyCard(
      id: id,
      boxId: boxId ?? this.boxId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      at: at ?? this.at,
      tag: tag ?? this.tag,
      memo: memo ?? this.memo,
      kind: kind ?? this.kind,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'boxId': boxId,
        'title': title,
        'amount': amount,
        'at': at.toIso8601String(),
        'tag': tag,
        'memo': memo,
        'kind': kind.name,
      };

  factory MoneyCard.fromJson(Map<String, dynamic> json) {
    return MoneyCard(
      id: json['id'] as String,
      boxId: json['boxId'] as String,
      title: json['title'] as String,
      amount: json['amount'] as int,
      at: DateTime.parse(json['at'] as String),
      tag: json['tag'] as String? ?? '',
      memo: json['memo'] as String? ?? '',
      kind: MoneyCardKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => MoneyCardKind.spend,
      ),
    );
  }
}

class IncomeEntry {
  const IncomeEntry({
    required this.id,
    required this.name,
    required this.amount,
    required this.depositedAt,
    required this.useYear,
    required this.useMonth,
    this.memo = '',
  });

  final String id;
  final String name;
  final int amount;
  final DateTime depositedAt;
  final int useYear;
  final int useMonth;
  final String memo;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'depositedAt': depositedAt.toIso8601String(),
        'useYear': useYear,
        'useMonth': useMonth,
        'memo': memo,
      };

  factory IncomeEntry.fromJson(Map<String, dynamic> json) {
    return IncomeEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: json['amount'] as int,
      depositedAt: DateTime.parse(json['depositedAt'] as String),
      useYear: json['useYear'] as int,
      useMonth: json['useMonth'] as int,
      memo: json['memo'] as String? ?? '',
    );
  }
}

class PaymentPlan {
  const PaymentPlan({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueAt,
    this.boxId,
    this.repeat = PaymentRepeat.none,
    this.memo = '',
  });

  final String id;
  final String title;
  final int amount;
  final DateTime dueAt;
  final String? boxId;
  final PaymentRepeat repeat;
  final String memo;

  PaymentPlan copyWith({String? boxId, bool clearBoxId = false}) {
    return PaymentPlan(
      id: id,
      title: title,
      amount: amount,
      dueAt: dueAt,
      boxId: clearBoxId ? null : (boxId ?? this.boxId),
      repeat: repeat,
      memo: memo,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'dueAt': dueAt.toIso8601String(),
        'boxId': boxId,
        'repeat': repeat.name,
        'memo': memo,
      };

  factory PaymentPlan.fromJson(Map<String, dynamic> json) {
    return PaymentPlan(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: json['amount'] as int,
      dueAt: DateTime.parse(json['dueAt'] as String),
      boxId: json['boxId'] as String?,
      repeat: PaymentRepeat.values.firstWhere(
        (r) => r.name == json['repeat'],
        orElse: () => PaymentRepeat.none,
      ),
      memo: json['memo'] as String? ?? '',
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.fromUser,
    required this.text,
    required this.at,
  });

  final String id;
  final bool fromUser;
  final String text;
  final DateTime at;
}

class AiProposal {
  const AiProposal({
    required this.id,
    required this.rationale,
    required this.summary,
    required this.scheduleId,
    required this.newStartAt,
    this.status = ProposalStatus.pending,
  });

  final String id;
  final String rationale;
  final String summary;
  final String scheduleId;
  final DateTime newStartAt;
  final ProposalStatus status;

  AiProposal copyWith({ProposalStatus? status}) {
    return AiProposal(
      id: id,
      rationale: rationale,
      summary: summary,
      scheduleId: scheduleId,
      newStartAt: newStartAt,
      status: status ?? this.status,
    );
  }
}

class UserSettings {
  const UserSettings({
    this.themeId = 'white-midnight',
    this.notifyTasks = true,
    this.notifySchedule = true,
    this.notifyReview = true,
    this.notifyNegumo = true,
    this.memoryStudy = true,
    this.memorySchedule = true,
    this.memoryMoney = false,
    this.memoryLife = false,
    this.reduceMotion = false,
    this.diaryDefaultPrivate = true,
    this.negumoStrength = 0.5,
    this.proposalFrequency = 0.5,
    this.deductBudgetFromBalance = false,
    this.timerPresets = const [25, 50, 90],
  });

  final String themeId;
  final bool notifyTasks;
  final bool notifySchedule;
  final bool notifyReview;
  final bool notifyNegumo;
  final bool memoryStudy;
  final bool memorySchedule;
  final bool memoryMoney;
  final bool memoryLife;
  final bool reduceMotion;
  final bool diaryDefaultPrivate;
  final double negumoStrength;
  final double proposalFrequency;
  final bool deductBudgetFromBalance;
  final List<int> timerPresets;

  String get themeBase => themeId.startsWith('black-') ? 'black' : 'white';

  String get themeAccent {
    final dash = themeId.indexOf('-');
    if (dash < 0) return 'midnight';
    return themeId.substring(dash + 1);
  }

  static const themeAccents = [
    ('midnight', 'ミッドナイト'),
    ('sunset', 'サンセット'),
    ('forest', 'フォレスト'),
    ('crimson', 'クリムゾン'),
    ('rose', 'ローズ'),
  ];

  static String composeThemeId(String base, String accent) => '$base-$accent';

  static String normalizeThemeId(String? id) {
    switch (id) {
      case null:
      case '':
        return 'white-midnight';
      case 'midnight':
      case 'ocean':
        return 'black-midnight';
      case 'ivory':
        return 'white-midnight';
      case 'sakura':
        return 'white-rose';
      case 'crimson':
        return 'black-crimson';
      case 'forest':
        return 'black-forest';
      case 'sunset':
        return 'black-sunset';
      default:
        return id;
    }
  }

  factory UserSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const UserSettings();
    final presets = [
      for (final item in (json['timerPresets'] as List? ?? const [25, 50, 90]))
        (item as num).toInt(),
    ];
    return UserSettings(
      themeId: UserSettings.normalizeThemeId(json['themeId'] as String?),
      notifyTasks: json['notifyTasks'] as bool? ?? true,
      notifySchedule: json['notifySchedule'] as bool? ?? true,
      notifyReview: json['notifyReview'] as bool? ?? true,
      notifyNegumo: json['notifyNegumo'] as bool? ?? true,
      memoryStudy: json['memoryStudy'] as bool? ?? true,
      memorySchedule: json['memorySchedule'] as bool? ?? true,
      memoryMoney: json['memoryMoney'] as bool? ?? false,
      memoryLife: json['memoryLife'] as bool? ?? false,
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      diaryDefaultPrivate: json['diaryDefaultPrivate'] as bool? ?? true,
      negumoStrength: (json['negumoStrength'] as num?)?.toDouble() ?? 0.5,
      proposalFrequency: (json['proposalFrequency'] as num?)?.toDouble() ?? 0.5,
      deductBudgetFromBalance: json['deductBudgetFromBalance'] as bool? ?? false,
      timerPresets: presets.isEmpty ? const [25, 50, 90] : presets,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeId': themeId,
        'notifyTasks': notifyTasks,
        'notifySchedule': notifySchedule,
        'notifyReview': notifyReview,
        'notifyNegumo': notifyNegumo,
        'memoryStudy': memoryStudy,
        'memorySchedule': memorySchedule,
        'memoryMoney': memoryMoney,
        'memoryLife': memoryLife,
        'reduceMotion': reduceMotion,
        'diaryDefaultPrivate': diaryDefaultPrivate,
        'negumoStrength': negumoStrength,
        'proposalFrequency': proposalFrequency,
        'deductBudgetFromBalance': deductBudgetFromBalance,
        'timerPresets': timerPresets,
      };

  UserSettings copyWith({
    String? themeId,
    bool? notifyTasks,
    bool? notifySchedule,
    bool? notifyReview,
    bool? notifyNegumo,
    bool? memoryStudy,
    bool? memorySchedule,
    bool? memoryMoney,
    bool? memoryLife,
    bool? reduceMotion,
    bool? diaryDefaultPrivate,
    double? negumoStrength,
    double? proposalFrequency,
    bool? deductBudgetFromBalance,
    List<int>? timerPresets,
  }) {
    return UserSettings(
      themeId: themeId ?? this.themeId,
      notifyTasks: notifyTasks ?? this.notifyTasks,
      notifySchedule: notifySchedule ?? this.notifySchedule,
      notifyReview: notifyReview ?? this.notifyReview,
      notifyNegumo: notifyNegumo ?? this.notifyNegumo,
      memoryStudy: memoryStudy ?? this.memoryStudy,
      memorySchedule: memorySchedule ?? this.memorySchedule,
      memoryMoney: memoryMoney ?? this.memoryMoney,
      memoryLife: memoryLife ?? this.memoryLife,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      diaryDefaultPrivate: diaryDefaultPrivate ?? this.diaryDefaultPrivate,
      negumoStrength: negumoStrength ?? this.negumoStrength,
      proposalFrequency: proposalFrequency ?? this.proposalFrequency,
      deductBudgetFromBalance: deductBudgetFromBalance ?? this.deductBudgetFromBalance,
      timerPresets: timerPresets ?? this.timerPresets,
    );
  }
}
