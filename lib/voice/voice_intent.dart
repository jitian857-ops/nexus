import '../cloud/friend_models.dart';
import '../data/models.dart';

class VoiceNamed {
  const VoiceNamed({required this.id, required this.name});

  final String id;
  final String name;
}

class VoiceParseContext {
  VoiceParseContext({
    DateTime? now,
    this.boxes = const [],
    this.subjects = const [],
    this.habits = const [],
    this.habitsDoneToday = const {},
    this.friends = const [],
    this.schedules = const [],
    this.diaryText = '',
    this.savingsBoxIds = const {},
  }) : now = now ?? DateTime.now();

  final DateTime now;
  final List<VoiceNamed> boxes;
  final List<VoiceNamed> subjects;
  final List<VoiceNamed> habits;
  final Set<String> habitsDoneToday;
  final List<VoiceNamed> friends;
  final List<VoiceNamed> schedules;
  final String diaryText;
  final Set<String> savingsBoxIds;
}

sealed class VoiceIntent {
  const VoiceIntent();

  bool get needsConfirm => true;
}

class VoiceUnknown extends VoiceIntent {
  const VoiceUnknown({this.transcript = '', this.hint = '例: 明日18時にバイト'});

  final String transcript;
  final String hint;

  @override
  bool get needsConfirm => false;
}

class NavigateTabIntent extends VoiceIntent {
  const NavigateTabIntent(this.tabIndex);

  final int tabIndex;

  @override
  bool get needsConfirm => false;
}

class CreateScheduleIntent extends VoiceIntent {
  const CreateScheduleIntent({
    required this.title,
    required this.startAt,
    this.endAt,
    this.allDay = false,
    this.note = '',
  });

  final String title;
  final DateTime startAt;
  final DateTime? endAt;
  final bool allDay;
  final String note;
}

class CreateSpendIntent extends VoiceIntent {
  const CreateSpendIntent({
    required this.amount,
    required this.at,
    this.boxId,
    this.boxQuery = '',
    this.title = '支出',
    this.memo = '',
    this.kind,
  });

  final String? boxId;
  final String boxQuery;
  final int amount;
  final DateTime at;
  final String title;
  final String memo;
  final MoneyCardKind? kind;
}

class CreateIncomeIntent extends VoiceIntent {
  const CreateIncomeIntent({
    required this.name,
    required this.amount,
    required this.depositedAt,
  });

  final String name;
  final int amount;
  final DateTime depositedAt;
}

class StartTimerIntent extends VoiceIntent {
  const StartTimerIntent({
    this.minutes = 0,
    this.subjectId,
    this.subjectQuery = '',
  });

  final int minutes;
  final String? subjectId;
  final String subjectQuery;
}

class PauseTimerIntent extends VoiceIntent {
  const PauseTimerIntent();

  @override
  bool get needsConfirm => false;
}

class FinishTimerIntent extends VoiceIntent {
  const FinishTimerIntent();
}

class ToggleHabitIntent extends VoiceIntent {
  const ToggleHabitIntent({
    this.habitId,
    required this.habitName,
    this.alreadyDone = false,
  });

  final String? habitId;
  final String habitName;
  final bool alreadyDone;
}

class CheckInIntent extends VoiceIntent {
  const CheckInIntent({
    this.mood = 0,
    this.energy = 0,
    this.tags = const [],
    this.diary = '',
  });

  final int mood;
  final int energy;
  final List<String> tags;
  final String diary;
}

class SetDiaryIntent extends VoiceIntent {
  const SetDiaryIntent({required this.text});

  final String text;
}

class ShareItemIntent extends VoiceIntent {
  const ShareItemIntent({
    required this.kind,
    required this.viewerName,
    this.viewerId = '',
    this.sourceLocalId = '',
    this.title = '',
  });

  final SharedKind kind;
  final String viewerName;
  final String viewerId;
  final String sourceLocalId;
  final String title;
}

class CreateAssignmentIntent extends VoiceIntent {
  const CreateAssignmentIntent({
    required this.title,
    required this.dueAt,
    this.subjectId,
    this.subjectQuery = '',
  });

  final String title;
  final DateTime dueAt;
  final String? subjectId;
  final String subjectQuery;
}

class CreateExamIntent extends VoiceIntent {
  const CreateExamIntent({
    required this.title,
    required this.examAt,
  });

  final String title;
  final DateTime examAt;
}

class VoiceDispatchResult {
  const VoiceDispatchResult({
    required this.ok,
    this.message = '',
    this.tabIndex,
  });

  const VoiceDispatchResult.ok({this.message = '', this.tabIndex}) : ok = true;

  const VoiceDispatchResult.fail(this.message)
      : ok = false,
        tabIndex = null;

  final bool ok;
  final String message;
  final int? tabIndex;
}
