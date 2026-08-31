String yen(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}¥$buffer';
}

String two(int n) => n.toString().padLeft(2, '0');

String jpDate(DateTime d) => '${d.year}年 ${d.month}月 ${d.day}日';

String jpMonth(DateTime d) => '${d.year}年${d.month}月';

String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String mmss(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final hours = s ~/ 3600;
  final minutes = (s % 3600) ~/ 60;
  final rest = s % 60;
  if (hours > 0) return '$hours:${two(minutes)}:${two(rest)}';
  return '${two(minutes)}:${two(rest)}';
}

/// 残りの勉強時間。60分以上は時間、未満は分数で出す。
String remainingStudyLabel(int remainingMinutes) {
  if (remainingMinutes <= 0) return '達成';
  if (remainingMinutes >= 60) {
    final hours = remainingMinutes ~/ 60;
    final minutes = remainingMinutes % 60;
    if (minutes == 0) return '$hours時間';
    return '$hours時間$minutes分';
  }
  return '$remainingMinutes分';
}

/// 入金日の翌月を、使う月の初期値にする。
({int year, int month}) nextUseMonth(DateTime deposited) {
  if (deposited.month == 12) return (year: deposited.year + 1, month: 1);
  return (year: deposited.year, month: deposited.month + 1);
}

bool queryMatches(String query, Iterable<String> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return fields.any((field) => field.toLowerCase().contains(q));
}

/// 時と分で表示。秒の端数は繰り上げ。
String formatStudyHours(double hours) {
  if (hours <= 0) return '0分';
  final minutes = (hours * 60).ceil();
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h <= 0) return '$m分';
  if (m == 0) return '$h時間';
  return '$h時間$m分';
}

/// グラフの上限と横線。切りのいい数字に合わせる。
({double max, List<double> ticks}) niceStudyAxis(double dataMax) {
  if (dataMax <= 0) {
    return (max: 1, ticks: const [0.25, 0.5, 0.75, 1]);
  }
  const candidates = [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 12.0, 15.0, 20.0, 24.0, 30.0, 40.0, 50.0];
  var max = candidates.last;
  for (final candidate in candidates) {
    if (dataMax <= candidate) {
      max = candidate;
      break;
    }
  }
  if (dataMax > candidates.last) {
    max = (dataMax / 10).ceil() * 10;
  }
  return (
    max: max,
    ticks: [for (var i = 1; i <= 4; i++) max * i / 4],
  );
}

String studyGoalLabel(int minutes) {
  if (minutes >= 60) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '$hours時間';
    return '$hours時間$rest分';
  }
  return '$minutes分';
}

const weekLabels = ['月', '火', '水', '木', '金', '土', '日'];

int mondayIndex(DateTime d) => (d.weekday + 6) % 7;

DateTime weekMonday(DateTime day) {
  final d = dateOnly(day);
  return d.subtract(Duration(days: mondayIndex(d)));
}

String weekDaySpan(DateTime day) {
  final monday = weekMonday(day);
  final sunday = monday.add(const Duration(days: 6));
  return '${monday.month}月${monday.day}日ー${sunday.month}月${sunday.day}日';
}

String weekdayLabelOf(DateTime d) => weekLabels[mondayIndex(d)];

String daysLeftLabel(DateTime due, DateTime today) {
  final days = dateOnly(due).difference(dateOnly(today)).inDays;
  if (days < 0) return '期限切れ ${-days}日';
  if (days == 0) return '今日まで';
  if (days == 1) return 'あと1日';
  return 'あと$days日';
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime monthStart(DateTime d) => DateTime(d.year, d.month, 1);

String monthKey(DateTime d) => '${d.year}-${two(d.month)}';

bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

String dateKey(DateTime d) {
  final day = dateOnly(d);
  return '${day.year}-${two(day.month)}-${two(day.day)}';
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
