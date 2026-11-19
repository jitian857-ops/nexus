import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus/cloud/nexus_cloud.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/data/nexus_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final moveDate in [false, true]) {
    test(
      'schedule deletion persists and retains others (date edited: $moveDate)',
      () async {
        final cloud = NexusCloud();
        await cloud.enterGuestSession();
        final store = AppStore.seed();
        await store.attachCloud(cloud);
        addTearDown(() {
          store.dispose();
          cloud.dispose();
        });
        store.addSchedule(title: 'remove', startAt: DateTime(2026, 12, 31, 9));
        final removed = store.schedules.single;
        store.addSchedule(title: 'keep', startAt: DateTime(2026, 12, 31, 12));
        final kept = store.schedules.last;
        if (moveDate) {
          store.updateSchedule(
            removed.copyWith(startAt: DateTime(2027, 1, 1, 9)),
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 800));
        expect(
          (await NexusPrefs.loadBundle('guest')).data!['schedules'],
          hasLength(2),
        );
        expect((await cloud.pullLive())!['schedules'], hasLength(2));
        store.deleteSchedule(removed.id);
        expect(store.schedules.single.id, kept.id);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        final disk = (await NexusPrefs.loadBundle('guest')).data!;
        final live = (await cloud.pullLive())!;
        for (final bundle in [disk, live]) {
          final schedules = bundle['schedules'] as List;
          expect(schedules, hasLength(1));
          expect(schedules.single['id'], kept.id);
          expect(schedules.single['title'], kept.title);
          expect(schedules.single['startAt'], kept.startAt.toIso8601String());
        }
        // Do not dispose/flush the original Store before restoring.
        final nextCloud = NexusCloud();
        await nextCloud.enterGuestSession();
        final restored = AppStore.seed();
        await restored.attachCloud(nextCloud);
        addTearDown(() {
          restored.dispose();
          nextCloud.dispose();
        });
        expect(restored.schedules.single.id, kept.id);
      },
    );
  }
  test('deleting an absent ID does not notify or schedule a write', () async {
    final cloud = NexusCloud();
    await cloud.enterGuestSession();
    final store = AppStore.seed();
    await store.attachCloud(cloud);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    var notifications = 0;
    var writes = 0;
    store.addListener(() => notifications++);
    NexusPrefs.debugSave = (_, _) async {
      writes++;
    };
    addTearDown(() {
      NexusPrefs.debugSave = null;
      store.dispose();
      cloud.dispose();
    });
    final before = store.lastToast;
    store.deleteSchedule('absent');
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(store.schedules, isEmpty);
    expect(notifications, 0);
    expect(writes, 0);
    expect(store.lastToast, before);
  });
}
