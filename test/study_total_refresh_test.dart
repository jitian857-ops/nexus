import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/app/theme.dart';
import 'package:nexus/core/format.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/data/models.dart';
import 'package:nexus/screens/study/study_screen.dart';
import 'package:nexus/widgets/study_week_chart.dart';

void main() {
  testWidgets('Study totals and chart refresh after adding a session', (
    tester,
  ) async {
    final store = AppStore.seed();
    addTearDown(store.dispose);
    final subject = store.addSubject(name: '数学');
    await tester.pumpWidget(
      AppScope(
        store: store,
        child: MaterialApp(
          theme: NexusTheme.dark,
          home: const Scaffold(body: StudyScreen()),
        ),
      ),
    );
    await tester.pump();
    store.addStudySession(
      subjectId: subject.id,
      minutes: 30,
      focus: StudyFocus.three,
      at: store.studyEntryDate,
    );
    await tester.pump();
    expect(store.totalStudyHours, 0.5);
    expect(store.weekStudyHoursFor(store.studyWeek), 0.5);
    // Subject card, weekly total and all-time total must agree immediately.
    expect(find.text(formatStudyHours(0.5)), findsNWidgets(3));
    final chart = tester.widget<StudyWeekChart>(find.byType(StudyWeekChart));
    expect(
      chart.stacks!.expand((row) => row).fold<double>(0, (a, b) => a + b),
      0.5,
    );
    store.updateStudySession(store.sessions.single.copyWith(minutes: 60));
    await tester.pump();
    expect(find.text(formatStudyHours(1)), findsNWidgets(3));
    expect(
      tester
          .widget<StudyWeekChart>(find.byType(StudyWeekChart))
          .stacks!
          .expand((row) => row)
          .fold<double>(0, (a, b) => a + b),
      1,
    );
    store.deleteStudySession(store.sessions.single.id);
    await tester.pump();
    expect(find.text(formatStudyHours(0)), findsNWidgets(3));
    expect(
      tester.widget<StudyWeekChart>(find.byType(StudyWeekChart)).stacks,
      isEmpty,
    );
  });
  test('editing a session invalidates weekly totals and chart caches', () {
    final store = AppStore.seed();
    addTearDown(store.dispose);
    final subject = store.addSubject(name: '数学');
    store.addStudySession(
      subjectId: subject.id,
      minutes: 30,
      focus: StudyFocus.three,
      at: store.studyEntryDate,
    );
    expect(store.weekStudyHoursFor(store.studyWeek), 0.5);
    expect(
      store
          .weekStackedHours()
          .expand((row) => row)
          .fold<double>(0, (a, b) => a + b),
      0.5,
    );
    store.updateStudySession(store.sessions.single.copyWith(minutes: 60));
    expect(store.totalStudyHours, 1);
    expect(store.weekStudyHoursFor(store.studyWeek), 1);
    expect(
      store
          .weekStackedHours()
          .expand((row) => row)
          .fold<double>(0, (a, b) => a + b),
      1,
    );
  });
}
