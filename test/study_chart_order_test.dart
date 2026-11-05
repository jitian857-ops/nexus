import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/data/models.dart';

void main() {
  for (final archivedMiddle in [false, true]) {
    test(
      'chart columns follow both reorder directions; archived=$archivedMiddle',
      () {
        final s = AppStore.seed();
        addTearDown(s.dispose);
        final a = s.addSubject(name: 'A');
        final hidden = archivedMiddle ? s.addSubject(name: 'Hidden') : null;
        final b = s.addSubject(name: 'B');
        final day = s.studyWeekMonday;
        for (final (id, minutes) in [
          (a.id, 30),
          if (hidden != null) (hidden.id, 90),
          (b.id, 60),
        ]) {
          s.addStudySession(
            subjectId: id,
            minutes: minutes,
            focus: StudyFocus.three,
            at: day,
          );
        }
        if (hidden != null) s.deleteSubject(hidden.id);
        void check(List<String> ids, List<double> hours) {
          expect(s.weekChartSubjects().map((e) => e.id), ids);
          expect(s.weekStackedHours().first, hours);
          expect(s.weekStudyHoursFor(s.studyWeek), archivedMiddle ? 3 : 1.5);
        }

        check(
          [a.id, if (hidden != null) hidden.id, b.id],
          [0.5, if (hidden != null) 1.5, 1],
        );
        s.reorderSubjects(0, 1);
        check(
          [b.id, if (hidden != null) hidden.id, a.id],
          [1, if (hidden != null) 1.5, 0.5],
        );
        s.reorderSubjects(1, 0);
        check(
          [a.id, if (hidden != null) hidden.id, b.id],
          [0.5, if (hidden != null) 1.5, 1],
        );
        s.reorderSubjects(0, 1);
        final restored = AppStore.seed()
          ..applyCloudMap(
            jsonDecode(jsonEncode(s.toCloudMap())) as Map<String, dynamic>,
          );
        addTearDown(restored.dispose);
        expect(restored.weekChartSubjects().map((e) => e.id), [
          b.id,
          if (hidden != null) hidden.id,
          a.id,
        ]);
        expect(restored.weekStackedHours().first, [
          1,
          if (hidden != null) 1.5,
          0.5,
        ]);
        restored.reorderSubjects(1, 0);
        expect(restored.weekChartSubjects().map((e) => e.id), [
          a.id,
          if (hidden != null) hidden.id,
          b.id,
        ]);
        expect(restored.weekStackedHours().first, [
          0.5,
          if (hidden != null) 1.5,
          1,
        ]);
      },
    );
  }
}
