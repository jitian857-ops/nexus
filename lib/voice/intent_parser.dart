import '../cloud/friend_models.dart';
import '../core/format.dart';
import '../data/models.dart';
import '../widgets/nexus_nav_bar.dart';
import 'voice_intent.dart';

class IntentParser {
  const IntentParser();

  VoiceIntent parse(String raw, VoiceParseContext context) {
    final text = _normalize(raw);
    if (text.isEmpty) {
      return const VoiceUnknown(hint: '例: 明日18時にバイト');
    }

    final share = _parseShare(text, context);
    if (share != null) return share;

    final navigate = _parseNavigate(text);
    if (navigate != null) return navigate;

    final timer = _parseTimer(text, context);
    if (timer != null) return timer;

    final habit = _parseHabit(text, context);
    if (habit != null) return habit;

    final checkIn = _parseCheckIn(text);
    if (checkIn != null) return checkIn;

    final diary = _parseDiary(text);
    if (diary != null) return diary;

    final exam = _parseExam(text, context);
    if (exam != null) return exam;

    final assignment = _parseAssignment(text, context);
    if (assignment != null) return assignment;

    final money = _parseMoney(text, context);
    if (money != null) return money;

    final schedule = _parseSchedule(text, context);
    if (schedule != null) return schedule;

    return VoiceUnknown(transcript: raw, hint: '例: 明日18時にバイト');
  }

  NavigateTabIntent? _parseNavigate(String text) {
    if (_hasYen(text) || _hasShare(text)) return null;
    if (!_navCue.hasMatch(text)) return null;
    if (_timerCue.hasMatch(text) && _minutesRe.hasMatch(text)) return null;

    final tab = _tabFor(text);
    if (tab == null) return null;
    return NavigateTabIntent(tab);
  }

  VoiceIntent? _parseTimer(String text, VoiceParseContext context) {
    if (_hasYen(text) || _hasShare(text)) return null;

    if (_pauseRe.hasMatch(text)) return const PauseTimerIntent();
    if (_finishTimerRe.hasMatch(text)) return const FinishTimerIntent();

    final isTimer = _timerCue.hasMatch(text) || _pomodoroRe.hasMatch(text);
    if (!isTimer) return null;

    var minutes = 0;
    final minuteMatch = _minutesRe.firstMatch(text);
    if (minuteMatch != null) {
      minutes = int.tryParse(minuteMatch.group(1) ?? '') ?? 0;
    } else if (_pomodoroRe.hasMatch(text)) {
      minutes = 25;
    }

    final subject = _bestMatch(text, context.subjects);
    return StartTimerIntent(
      minutes: minutes,
      subjectId: subject?.id,
      subjectQuery: subject?.name ?? '',
    );
  }

  ToggleHabitIntent? _parseHabit(String text, VoiceParseContext context) {
    if (!_habitCue.hasMatch(text) || context.habits.isEmpty) return null;
    final habit = _bestMatch(text, context.habits);
    if (habit == null) return null;
    return ToggleHabitIntent(
      habitId: habit.id,
      habitName: habit.name,
      alreadyDone: context.habitsDoneToday.contains(habit.id),
    );
  }

  CheckInIntent? _parseCheckIn(String text) {
    final mood = _intAfter(_moodRe, text);
    final energy = _intAfter(_energyRe, text);
    final tags = [
      for (final tag in _lifeTags)
        if (text.contains(tag)) tag,
    ];
    if (mood == null && energy == null && tags.isEmpty) return null;
    if (!_checkInCue.hasMatch(text) && mood == null && energy == null) return null;
    return CheckInIntent(
      mood: (mood ?? 0).clamp(0, 5),
      energy: (energy ?? 0).clamp(0, 5),
      tags: tags,
    );
  }

  SetDiaryIntent? _parseDiary(String text) {
    final match = _diaryRe.firstMatch(text);
    if (match == null) return null;
    final body = (match.group(1) ?? '').replaceAll(RegExp(r'[。．、,]+$'), '').trim();
    if (body.isEmpty) return null;
    return SetDiaryIntent(text: body);
  }

  CreateExamIntent? _parseExam(String text, VoiceParseContext context) {
    if (!_examRe.hasMatch(text)) return null;
    final when = _parseWhen(text, context.now);
    if (when == null) return null;
    final title = _cleanTitle(
      text,
      extra: const ['試験', 'テスト', 'テスト日', '受験'],
    );
    if (title.isEmpty) return null;
    return CreateExamIntent(title: title, examAt: dateOnly(when.day));
  }

  CreateAssignmentIntent? _parseAssignment(String text, VoiceParseContext context) {
    if (!_assignmentRe.hasMatch(text)) return null;
    final when = _parseWhen(text, context.now);
    if (when == null) return null;
    final subject = _bestMatch(text, context.subjects);
    var title = _cleanTitle(
      text,
      extra: [
        '提出',
        '提出物',
        '宿題',
        '課題',
        'レポート',
        'まで',
        'までに',
        if (subject != null) subject.name,
      ],
    );
    if (title.isEmpty) title = '提出物';
    return CreateAssignmentIntent(
      title: title,
      dueAt: dateOnly(when.day),
      subjectId: subject?.id,
      subjectQuery: subject?.name ?? '',
    );
  }

  VoiceIntent? _parseMoney(String text, VoiceParseContext context) {
    final amount = parseYen(text);
    if (amount == null || amount <= 0) return null;

    if (_incomeRe.hasMatch(text)) {
      var name = _cleanTitle(
        text,
        extra: ['入った', '収入', '振り込まれた', '振り込み', '振込', 'もらった', '円', '萬'],
      );
      if (name.isEmpty) {
        if (text.contains('仕送り')) {
          name = '仕送り';
        } else if (text.contains('給料') || text.contains('給与')) {
          name = '給料';
        } else if (text.contains('おこづかい') || text.contains('お小遣い')) {
          name = 'おこづかい';
        } else {
          name = '収入';
        }
      }
      return CreateIncomeIntent(
        name: name,
        amount: amount,
        depositedAt: dateOnly(context.now),
      );
    }

    final box = _bestMatch(text, context.boxes);
    var title = _cleanTitle(
      text,
      extra: [
        '円',
        '使った',
        '払った',
        '支出',
        '支払った',
        if (box != null) box.name,
        if (box != null) '${box.name}に',
      ],
    );
    if (title.isEmpty) title = box?.name ?? '支出';
    final savings = box != null && context.savingsBoxIds.contains(box.id);
    return CreateSpendIntent(
      amount: amount,
      at: dateOnly(context.now),
      boxId: box?.id,
      boxQuery: box?.name ?? '',
      title: title,
      kind: savings ? null : MoneyCardKind.spend,
    );
  }

  CreateScheduleIntent? _parseSchedule(String text, VoiceParseContext context) {
    final when = _parseWhen(text, context.now);
    final scheduleCue = _scheduleCue.hasMatch(text);
    if (when == null && !scheduleCue) return null;

    final day = when?.day ?? dateOnly(context.now);
    final allDay = when?.allDay ?? (text.contains('終日') || when?.time == null);
    var title = _cleanTitle(text, extra: const ['予定', '入れて', '追加', '登録']);
    if (title.isEmpty) title = '予定';

    if (allDay || when?.time == null) {
      return CreateScheduleIntent(
        title: title,
        startAt: day,
        endAt: DateTime(day.year, day.month, day.day, 23, 59),
        allDay: true,
      );
    }

    final start = DateTime(day.year, day.month, day.day, when!.time!.hour, when.time!.minute);
    final end = when.endTime == null
        ? start.add(const Duration(hours: 1))
        : DateTime(day.year, day.month, day.day, when.endTime!.hour, when.endTime!.minute);
    return CreateScheduleIntent(
      title: title,
      startAt: start,
      endAt: end.isBefore(start) ? start.add(const Duration(hours: 1)) : end,
    );
  }

  ShareItemIntent? _parseShare(String text, VoiceParseContext context) {
    if (!_hasShare(text)) return null;
    final kind = text.contains('日記') ? SharedKind.diary : SharedKind.schedule;
    final name = _shareTarget(text);
    if (name.isEmpty) {
      return ShareItemIntent(kind: kind, viewerName: '');
    }
    final friend = _exactFriend(name, context.friends);
    var sourceId = '';
    var title = '';
    if (kind == SharedKind.schedule && context.schedules.isNotEmpty) {
      final named = _bestMatch(text, context.schedules);
      final item = named ?? context.schedules.last;
      sourceId = item.id;
      title = item.name;
    }
    return ShareItemIntent(
      kind: kind,
      viewerName: name,
      viewerId: friend?.id ?? '',
      sourceLocalId: sourceId,
      title: title,
    );
  }

  String _shareTarget(String text) {
    final match = _shareTargetRe.firstMatch(text);
    if (match == null) return '';
    return (match.group(1) ?? '')
        .replaceAll(RegExp(r'^(この)?(予定|日記|スケジュール)を?'), '')
        .replaceAll(RegExp(r'^(フレンド|友達|友だち)の'), '')
        .trim();
  }

  VoiceNamed? _exactFriend(String name, List<VoiceNamed> friends) {
    final n = name.trim();
    if (n.isEmpty) return null;
    final hits = [for (final f in friends) if (f.name == n) f];
    if (hits.length == 1) return hits.first;
    return null;
  }

  _When? _parseWhen(String text, DateTime now) {
    final today = dateOnly(now);
    DateTime? day;
    var nextWeek = text.contains('来週');

    if (text.contains('今日')) {
      day = today;
    } else if (text.contains('明日')) {
      day = today.add(const Duration(days: 1));
    } else if (text.contains('明後日')) {
      day = today.add(const Duration(days: 2));
    } else if (text.contains('昨日')) {
      day = today.subtract(const Duration(days: 1));
    }

    final md = _monthDayRe.firstMatch(text);
    if (md != null) {
      final month = int.parse(md.group(1)!);
      final d = int.parse(md.group(2)!);
      var year = now.year;
      var candidate = DateTime(year, month, d);
      if (candidate.isBefore(today)) candidate = DateTime(year + 1, month, d);
      day = dateOnly(candidate);
    } else {
      final onlyDay = _dayOnlyRe.firstMatch(text);
      if (onlyDay != null && day == null && !_minutesRe.hasMatch(onlyDay.group(0)!)) {
        final d = int.parse(onlyDay.group(1)!);
        var candidate = DateTime(now.year, now.month, d);
        if (candidate.isBefore(today)) {
          candidate = DateTime(now.year, now.month + 1, d);
        }
        day = dateOnly(candidate);
      }
    }

    final weekday = _weekdayOf(text);
    if (weekday != null) {
      day = _onWeekday(today, weekday, nextWeek: nextWeek, keepToday: !nextWeek);
    }

    final time = _parseTime(text);
    final endTime = _parseEndTime(text);
    final allDay = text.contains('終日');
    if (day == null && time == null && !allDay && weekday == null) return null;
    return _When(
      day: day ?? today,
      time: allDay ? null : time,
      endTime: allDay ? null : endTime,
      allDay: allDay,
    );
  }

  DateTime _onWeekday(DateTime today, int weekday, {required bool nextWeek, required bool keepToday}) {
    if (nextWeek) {
      final daysUntilNextMonday = (DateTime.monday - today.weekday + 7) % 7;
      final nextMonday = today.add(Duration(days: daysUntilNextMonday == 0 ? 7 : daysUntilNextMonday));
      return dateOnly(nextMonday.add(Duration(days: weekday - DateTime.monday)));
    }
    var delta = (weekday - today.weekday) % 7;
    if (delta == 0 && !keepToday) delta = 7;
    return dateOnly(today.add(Duration(days: delta)));
  }

  int? _weekdayOf(String text) {
    const map = {
      '月曜': DateTime.monday,
      '火曜日': DateTime.tuesday,
      '火曜': DateTime.tuesday,
      '水曜': DateTime.wednesday,
      '木曜': DateTime.thursday,
      '金曜': DateTime.friday,
      '土曜': DateTime.saturday,
      '日曜': DateTime.sunday,
      '月曜日': DateTime.monday,
      '水曜日': DateTime.wednesday,
      '木曜日': DateTime.thursday,
      '金曜日': DateTime.friday,
      '土曜日': DateTime.saturday,
      '日曜日': DateTime.sunday,
    };
    for (final entry in map.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return null;
  }

  _Clock? _parseTime(String text) {
    final hm = _hmRe.firstMatch(text);
    if (hm != null) {
      var hour = int.parse(hm.group(1)!);
      final minute = int.parse(hm.group(2)!);
      hour = _adjustHour(hour, text, hm.start);
      return _Clock(hour.clamp(0, 23), minute.clamp(0, 59));
    }
    final jp = _jpTimeRe.firstMatch(text);
    if (jp != null) {
      var hour = int.parse(jp.group(1)!);
      final half = jp.group(2) != null;
      final minuteRaw = jp.group(3);
      var minute = half ? 30 : (minuteRaw == null ? 0 : int.parse(minuteRaw));
      hour = _adjustHour(hour, text, jp.start);
      return _Clock(hour.clamp(0, 23), minute.clamp(0, 59));
    }
    return null;
  }

  _Clock? _parseEndTime(String text) {
    final match = _rangeTimeRe.firstMatch(text);
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    hour = _adjustHour(hour, text, match.start);
    return _Clock(hour.clamp(0, 23), minute.clamp(0, 59));
  }

  int _adjustHour(int hour, String text, int index) {
    if (hour >= 13) return hour;
    final prefix = text.substring(0, index);
    if (prefix.contains('午後') || prefix.contains('夜')) {
      if (hour < 12) return hour + 12;
    }
    if (prefix.contains('午前')) return hour == 12 ? 0 : hour;
    return hour;
  }

  int? _tabFor(String text) {
    if (_containsAny(text, const ['フレンド', '友達', '友だち', 'friend', '友人'])) {
      return NexusTab.friends;
    }
    if (_containsAny(text, const ['お金', 'マネー', 'money', '家計', '収支'])) {
      return NexusTab.money;
    }
    if (_containsAny(text, const ['生活', 'ライフ', 'life'])) {
      return NexusTab.life;
    }
    if (_containsAny(text, const ['勉強', '学習', 'スタディ', 'study'])) {
      return NexusTab.study;
    }
    if (_containsAny(text, const ['ホーム', 'home', 'ホーム画面'])) {
      return NexusTab.home;
    }
    return null;
  }

  VoiceNamed? _bestMatch(String text, List<VoiceNamed> items) {
    final compact = _compact(text);
    VoiceNamed? best;
    var bestLen = 0;
    for (final item in items) {
      final n = _compact(item.name);
      if (n.isEmpty) continue;
      if (compact.contains(n) && n.length > bestLen) {
        best = item;
        bestLen = n.length;
      }
    }
    return best;
  }

  String _cleanTitle(String text, {List<String> extra = const []}) {
    var t = text;
    const strip = [
      '今日',
      '明日',
      '明後日',
      '昨日',
      '今週',
      '来週',
      '終日',
      '午前',
      '午後',
      '夜',
      '月曜日',
      '火曜日',
      '水曜日',
      '木曜日',
      '金曜日',
      '土曜日',
      '日曜日',
      '月曜',
      '火曜',
      '水曜',
      '木曜',
      '金曜',
      '土曜',
      '日曜',
      'から',
      'まで',
      'までに',
      'の予定',
      '予定を',
      'を追加',
      'を登録',
      'してください',
      'して',
      'スタート',
      '開始',
      'タイマー',
      'ポモドーロ',
      'ポモドロ',
    ];
    for (final token in [...strip, ...extra]) {
      t = t.replaceAll(token, ' ');
    }
    t = t.replaceAll(_jpTimeRe, ' ');
    t = t.replaceAll(_hmRe, ' ');
    t = t.replaceAll(_monthDayRe, ' ');
    t = t.replaceAll(_yenChunkRe, ' ');
    t = t.replaceAll(RegExp(r'\d+\s*分'), ' ');
    t = t.replaceAll(RegExp(r'\d+\s*日'), ' ');
    t = t.replaceAll(RegExp(r'[にでをはがのとへ]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  static final _navCue = RegExp(r'(開いて|開けて|見せて|表示|行って|へ行|を開)');
  static final _timerCue = RegExp(r'(スタート|開始|タイマー|計測|勉強開始)');
  static final _pomodoroRe = RegExp(r'(ポモドーロ|ポモドロ|ぽもどーろ)');
  static final _pauseRe = RegExp(r'(タイマー(を)?(止め|停止|一時停止)|一時停止)');
  static final _finishTimerRe = RegExp(r'(タイマー(を)?(終了|終わ)|計測(を)?終了|勉強(を)?終了)');
  static final _habitCue = RegExp(r'(やった|できた|済ませ|すませ|完了|習慣|チェック)');
  static final _checkInCue = RegExp(r'(気分|エネルギー|チェックイン|調子)');
  static final _moodRe = RegExp(r'気分(?:は|が)?\s*([1-5１-５])');
  static final _energyRe = RegExp(r'エネルギー(?:は|が)?\s*([1-5１-５])');
  static final _diaryRe = RegExp(r'日記(?:に|を|は)\s*(?:書いて)?(.+)$');
  static final _examRe = RegExp(r'(試験|テスト日|受験)');
  static final _assignmentRe = RegExp(r'(提出物|提出|宿題|課題|レポート)');
  static final _incomeRe = RegExp(r'(入った|収入|仕送り|給料|給与|おこづかい|お小遣い|もらった|振り込|振込)');
  static final _scheduleCue = RegExp(r'(予定|入れる|入れて|追加して)');
  static final _shareRe = RegExp(r'共有');
  static final _shareTargetRe = RegExp(r'(.+?)(?:に|へ|と)共有');
  static final _minutesRe = RegExp(r'(\d+)\s*分');
  static final _monthDayRe = RegExp(r'(\d{1,2})\s*月\s*(\d{1,2})\s*日');
  static final _dayOnlyRe = RegExp(r'(\d{1,2})\s*日');
  static final _jpTimeRe = RegExp(r'(\d{1,2})\s*時(?:(半)|(\d{1,2})\s*分)?');
  static final _hmRe = RegExp(r'(\d{1,2})[:：](\d{2})');
  static final _rangeTimeRe = RegExp(r'(?:から|〜|～|-)\s*(\d{1,2})\s*(?:時(?:(\d{1,2})\s*分)?|[:：](\d{2}))');
  static final _yenChunkRe = RegExp(r'(\d+(?:[,，]\d{3})*\s*万(?:\s*\d+(?:[,，]\d{3})*\s*千)?|\d+(?:[,，]\d{3})*\s*千|\d+(?:[,，]\d{3})*)\s*円?');

  bool _hasYen(String text) => parseYen(text) != null;
  bool _hasShare(String text) => _shareRe.hasMatch(text);

  int? _intAfter(RegExp re, String text) {
    final match = re.firstMatch(text);
    if (match == null) return null;
    return int.tryParse(_zenkakuToAscii(match.group(1) ?? ''));
  }
}

const _lifeTags = ['勉強', '運動', '食事', '友人', '休息', '仕事', '趣味', '外出'];

class _When {
  const _When({required this.day, this.time, this.endTime, this.allDay = false});

  final DateTime day;
  final _Clock? time;
  final _Clock? endTime;
  final bool allDay;
}

class _Clock {
  const _Clock(this.hour, this.minute);
  final int hour;
  final int minute;
}

int? parseYen(String text) {
  final t = _zenkakuToAscii(text).replaceAll('，', ',');
  final manSen = RegExp(r'(\d+(?:,\d{3})*)\s*万\s*(?:(\d+(?:,\d{3})*)\s*千)?').firstMatch(t);
  if (manSen != null) {
    final man = _toInt(manSen.group(1));
    final sen = _toInt(manSen.group(2));
    return man * 10000 + sen * 1000;
  }
  if (RegExp(r'(?:^|[^\d])万\s*円').hasMatch(t) || t.contains('万円')) {
    final onlyMan = RegExp(r'(?:^|[^\d])万円').hasMatch(t);
    if (onlyMan) return 10000;
  }
  final sen = RegExp(r'(\d+(?:,\d{3})*)\s*千').firstMatch(t);
  if (sen != null) {
    return _toInt(sen.group(1)) * 1000;
  }
  if (RegExp(r'(?:^|[^\d])千円').hasMatch(t)) return 1000;
  final yen = RegExp(r'(\d+(?:,\d{3})*)\s*円').firstMatch(t);
  if (yen != null) return _toInt(yen.group(1));
  return null;
}

int _toInt(String? raw) {
  if (raw == null || raw.isEmpty) return 0;
  return int.tryParse(raw.replaceAll(',', '')) ?? 0;
}

String _normalize(String raw) {
  return _zenkakuToAscii(raw).replaceAll(RegExp(r'\s+'), '').trim();
}

String _compact(String raw) => _normalize(raw);

String _zenkakuToAscii(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    if (rune >= 0xFF10 && rune <= 0xFF19) {
      buffer.writeCharCode(rune - 0xFF10 + 0x30);
    } else if (rune == 0x3000) {
      buffer.write(' ');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

bool _containsAny(String text, List<String> needles) {
  for (final n in needles) {
    if (text.toLowerCase().contains(n.toLowerCase())) return true;
  }
  return false;
}
