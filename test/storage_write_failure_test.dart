import 'package:flutter/material.dart';
import 'package:nexus/widgets/save_status_banner.dart';
import 'dart:async';
import 'dart:convert';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:nexus/data/nexus_prefs.dart';
import 'package:nexus/cloud/nexus_cloud.dart';

class RejectingPreferences extends InMemorySharedPreferencesStore {
  RejectingPreferences() : super.empty();
  bool reject = false;
  String? onlyKey;
  Completer<void>? gate;
  Completer<void>? started;
  bool throwsError = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.endsWith('nexus_user_data_v2_guest') && gate != null) {
      final pending = gate!;
      gate = null;
      started?.complete();
      await pending.future;
    }
    if (reject && (onlyKey == null || key.endsWith(onlyKey!))) {
      if (throwsError) throw StateError('synthetic write failure');
      return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final destination in ['live', 'device']) {
    test('stalled $destination of old UID does not block new UID', () async {
      final previous = SharedPreferencesStorePlatform.instance;
      final platform = RejectingPreferences();
      SharedPreferencesStorePlatform.instance = platform;
      SharedPreferences.resetStatic();
      final old = NexusCloud();
      await old.enterGuestSession();
      final next = NexusCloud();
      await next.signUp(
        email: 'independent@example.test',
        password: 'secret123',
        displayName: 'Next',
        occupation: '',
      );
      await next.confirmVerification();
      final store = AppStore.seed();
      await store.attachCloud(old);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final gate = Completer<void>();
      final started = Completer<void>();
      if (destination == 'live') {
        old.debugStallPush = () {
          if (!started.isCompleted) started.complete();
          return gate.future;
        };
      } else {
        platform.gate = gate;
        platform.started = started;
      }
      addTearDown(() async {
        if (!gate.isCompleted) gate.complete();
        old.debugStallPush = null;
        store.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        old.dispose();
        next.dispose();
        SharedPreferencesStorePlatform.instance = previous;
        SharedPreferences.resetStatic();
      });
      store.addSubject(name: 'old pending');
      await started.future;
      await store.attachCloud(next);
      store.addSubject(name: 'new account update');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      // The old UID remains blocked throughout these assertions.
      final disk = await platform.getAll();
      expect(disk['flutter.nexus_user_data_v2_${next.uid}'], isNotNull);
      final device = jsonDecode(
        disk['flutter.nexus_user_data_v2_${next.uid}'] as String,
      );
      expect((device['subjects'] as List).single['name'], 'new account update');
      final newLive = await next.pullLive();
      expect(newLive, isNotNull);
      expect(
        (newLive!['subjects'] as List).single['name'],
        'new account update',
      );
      expect(store.hasUnsavedChanges, false);
      await store.retrySave().timeout(const Duration(seconds: 1));
      expect(store.saveFailed, false);
    });
    test(
      'same UID reattach retains $destination ordering without waiting to attach',
      () async {
        final previous = SharedPreferencesStorePlatform.instance;
        final platform = RejectingPreferences();
        SharedPreferencesStorePlatform.instance = platform;
        SharedPreferences.resetStatic();
        final cloud = NexusCloud();
        await cloud.enterGuestSession();
        final store = AppStore.seed();
        await store.attachCloud(cloud);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final gate = Completer<void>();
        final started = Completer<void>();
        if (destination == 'live') {
          cloud.debugStallPush = () {
            if (!started.isCompleted) started.complete();
            return gate.future;
          };
        } else {
          platform.gate = gate;
          platform.started = started;
        }
        addTearDown(() async {
          if (!gate.isCompleted) gate.complete();
          cloud.debugStallPush = null;
          store.dispose();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          cloud.dispose();
          SharedPreferencesStorePlatform.instance = previous;
          SharedPreferences.resetStatic();
        });
        store.addSubject(name: 'before reattach');
        await started.future;
        await store.attachCloud(cloud).timeout(const Duration(seconds: 1));
        store.addSubject(name: 'after reattach');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(store.hasUnsavedChanges, true);
        gate.complete();
        cloud.debugStallPush = null;
        await store.retrySave();
        final disk = await platform.getAll();
        final device = jsonDecode(
          disk['flutter.nexus_user_data_v2_guest'] as String,
        );
        final live = jsonDecode(
          disk['flutter.nexus_cloud_v1'] as String,
        )['live']['guest'];
        expect((device['subjects'] as List).map((x) => x['name']), [
          'before reattach',
          'after reattach',
        ]);
        expect((live['subjects'] as List).map((x) => x['name']), [
          'before reattach',
          'after reattach',
        ]);
        expect(store.hasUnsavedChanges, false);
      },
    );
  }
  test('stalled live backup does not block newer device saves', () async {
    final previous = SharedPreferencesStorePlatform.instance;
    final platform = RejectingPreferences();
    SharedPreferencesStorePlatform.instance = platform;
    SharedPreferences.resetStatic();
    final cloud = NexusCloud();
    await cloud.enterGuestSession();
    final store = AppStore.seed();
    await store.attachCloud(cloud);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final gate = Completer<void>();
    cloud.debugStallPush = () => gate.future;
    addTearDown(() async {
      if (!gate.isCompleted) gate.complete();
      cloud.debugStallPush = null;
      store.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      cloud.dispose();
      SharedPreferencesStorePlatform.instance = previous;
      SharedPreferences.resetStatic();
    });
    store.addSubject(name: 'first');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    store.addSubject(name: 'second');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final disk = await platform.getAll();
    expect(
      (jsonDecode(
                disk['flutter.nexus_user_data_v2_guest'] as String,
              )['subjects']
              as List)
          .length,
      2,
    );
    expect(store.hasUnsavedChanges, true);
    gate.complete();
    cloud.debugStallPush = null;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.hasUnsavedChanges, false);
  });
  testWidgets(
    'persistent failure banner retries and disappears only after save',
    (tester) async {
      final previous = SharedPreferencesStorePlatform.instance;
      final platform = RejectingPreferences();
      SharedPreferencesStorePlatform.instance = platform;
      SharedPreferences.resetStatic();
      final cloud = NexusCloud();
      await cloud.enterGuestSession();
      final store = AppStore.seed();
      await store.attachCloud(cloud);
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SaveStatusBanner(store: store)),
        ),
      );
      expect(find.text('再試行'), findsNothing);
      platform.reject = true;
      store.addSubject(name: 'visible failure');
      await tester.pump();
      expect(find.textContaining('保存中'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.textContaining('保存できません'), findsOneWidget);
      await tester.tap(find.text('再試行'));
      await tester.pump();
      await tester.pump();
      expect(find.text('再試行'), findsOneWidget);
      platform.reject = false;
      await tester.tap(find.text('再試行'));
      await tester.pump();
      await tester.pump();
      expect(find.text('再試行'), findsNothing);
      expect(store.hasUnsavedChanges, false);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      await tester.pump();
      cloud.dispose();
      SharedPreferencesStorePlatform.instance = previous;
      SharedPreferences.resetStatic();
    },
  );
  test(
    'old guest write completion cannot mark a newly bound user as failed',
    () async {
      final previous = SharedPreferencesStorePlatform.instance;
      final platform = RejectingPreferences();
      SharedPreferencesStorePlatform.instance = platform;
      SharedPreferences.resetStatic();
      final guest = NexusCloud();
      await guest.enterGuestSession();
      final account = NexusCloud();
      await account.signUp(
        email: 'storage@example.test',
        password: 'secret123',
        displayName: 'New user',
        occupation: '',
      );
      await account.confirmVerification();
      final store = AppStore.seed();
      await store.attachCloud(guest);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final gate = Completer<void>();
      platform.gate = gate;
      platform.started = Completer<void>();
      store.addSubject(name: 'old guest');
      await platform.started!.future;
      await store.attachCloud(account);
      store.addSubject(name: 'new user');
      platform.reject = true;
      platform.onlyKey = 'nexus_user_data_v2_guest';
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(store.dataUid, account.uid);
      expect(store.saveFailed, false);
      expect(store.hasUnsavedChanges, false);
      expect(store.subjects.single.name, 'new user');
      final disk = await platform.getAll();
      final saved = jsonDecode(
        disk['flutter.nexus_user_data_v2_${account.uid}'] as String,
      );
      expect((saved['subjects'] as List).single['name'], 'new user');
      store.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      guest.dispose();
      account.dispose();
      SharedPreferencesStorePlatform.instance = previous;
      SharedPreferences.resetStatic();
    },
  );
  for (final onlyKey in [null, 'nexus_user_data_v2_guest', 'nexus_cloud_v1']) {
    test(
      'failure stays visible until retry durably saves both paths: $onlyKey',
      () async {
        final previous = SharedPreferencesStorePlatform.instance;
        final platform = RejectingPreferences();
        SharedPreferencesStorePlatform.instance = platform;
        SharedPreferences.resetStatic();
        final cloud = NexusCloud();
        await cloud.enterGuestSession();
        final store = AppStore.seed();
        await store.attachCloud(cloud);
        final subject = store.addSubject(name: 'storage test');
        await Future<void>.delayed(const Duration(milliseconds: 600));
        addTearDown(() async {
          store.dispose();
          await Future<void>.delayed(const Duration(milliseconds: 20));
          cloud.dispose();
          SharedPreferencesStorePlatform.instance = previous;
          SharedPreferences.resetStatic();
        });
        platform.reject = true;
        platform.onlyKey = onlyKey;
        store.addStudySession(
          subjectId: subject.id,
          minutes: 17,
          focus: StudyFocus.three,
        );
        expect(store.lastToast, contains('未保存'));
        await Future<void>.delayed(const Duration(milliseconds: 600));
        expect(store.lastToast, contains('保存できません'));
        final state = store;
        expect(state.hasUnsavedChanges, true);
        expect(state.saveFailed, true);
        expect(store.sessions.single.minutes, 17);
        platform.reject = false;
        await state.retrySave();
        expect(state.hasUnsavedChanges, false);
        expect(state.saveFailed, false);
        SharedPreferences.resetStatic();
        final coldCloud = NexusCloud();
        await coldCloud.enterGuestSession();
        final coldStore = AppStore.seed();
        await coldStore.attachCloud(coldCloud);
        expect(coldStore.sessions.single.minutes, 17);
        coldStore.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        coldCloud.dispose();
      },
    );
  }
  test('slow old snapshot cannot overwrite the newest update', () async {
    final previous = SharedPreferencesStorePlatform.instance;
    final platform = RejectingPreferences();
    SharedPreferencesStorePlatform.instance = platform;
    SharedPreferences.resetStatic();
    final cloud = NexusCloud();
    await cloud.enterGuestSession();
    final store = AppStore.seed();
    await store.attachCloud(cloud);
    final subject = store.addSubject(name: 'ordered');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final gate = Completer<void>();
    platform.gate = gate;
    platform.started = Completer<void>();
    store.addStudySession(
      subjectId: subject.id,
      minutes: 17,
      focus: StudyFocus.three,
    );
    await platform.started!.future;
    store.addStudySession(
      subjectId: subject.id,
      minutes: 23,
      focus: StudyFocus.three,
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final disk = await platform.getAll();
    expect(
      (jsonDecode(
                disk['flutter.nexus_user_data_v2_guest'] as String,
              )['sessions']
              as List)
          .length,
      2,
    );
    final state = store;
    expect(state.hasUnsavedChanges, false);
    store.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    cloud.dispose();
    SharedPreferencesStorePlatform.instance = previous;
    SharedPreferences.resetStatic();
  });
  test('old session failure does not leak into a detached store', () async {
    final previous = SharedPreferencesStorePlatform.instance;
    final platform = RejectingPreferences();
    SharedPreferencesStorePlatform.instance = platform;
    SharedPreferences.resetStatic();
    final cloud = NexusCloud();
    await cloud.enterGuestSession();
    final store = AppStore.seed();
    await store.attachCloud(cloud);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final gate = Completer<void>();
    platform.gate = gate;
    platform.started = Completer<void>();
    store.addSubject(name: 'old session');
    await platform.started!.future;
    store.detachCloud();
    platform.reject = true;
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final state = store;
    expect(state.saveFailed, false);
    expect(state.hasUnsavedChanges, false);
    expect(store.dataUid, isNull);
    store.dispose();
    cloud.dispose();
    SharedPreferencesStorePlatform.instance = previous;
    SharedPreferences.resetStatic();
  });
  for (final throwsError in [false, true]) {
    test(
      'both save APIs report rejected writes (exception=$throwsError)',
      () async {
        final previous = SharedPreferencesStorePlatform.instance;
        final platform = RejectingPreferences();
        SharedPreferencesStorePlatform.instance = platform;
        SharedPreferences.resetStatic();
        final cloud = NexusCloud();
        addTearDown(() {
          cloud.dispose();
          SharedPreferencesStorePlatform.instance = previous;
          SharedPreferences.resetStatic();
        });
        await cloud.enterGuestSession();
        platform.reject = true;
        platform.throwsError = throwsError;
        final prefsWrite = NexusPrefs.saveBundle;
        final liveWrite = cloud.pushLive;
        expect(
          await prefsWrite('guest', <String, dynamic>{'uid': 'guest'}),
          false,
        );
        expect(await liveWrite(<String, dynamic>{'uid': 'guest'}), false);
      },
    );
  }
}
