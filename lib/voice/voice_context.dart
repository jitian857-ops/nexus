import '../core/format.dart';
import '../data/app_store.dart';
import 'voice_intent.dart';

VoiceParseContext voiceContextOf(
  AppStore store, {
  List<VoiceNamed> friends = const [],
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final today = dateOnly(clock);
  return VoiceParseContext(
    now: clock,
    boxes: [for (final box in store.visibleBoxes) VoiceNamed(id: box.id, name: box.name)],
    savingsBoxIds: {
      for (final box in store.visibleBoxes)
        if (box.isSavings) box.id,
    },
    subjects: [for (final subject in store.visibleSubjects) VoiceNamed(id: subject.id, name: subject.name)],
    habits: [for (final habit in store.habits) VoiceNamed(id: habit.id, name: habit.name)],
    habitsDoneToday: {
      for (final habit in store.habits)
        if (habit.doneOn(today)) habit.id,
    },
    friends: friends,
    schedules: [for (final item in store.schedules) VoiceNamed(id: item.id, name: item.title)],
    diaryText: store.diary,
  );
}
