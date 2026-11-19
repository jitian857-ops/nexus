import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:nexus/app/app.dart';
import 'package:nexus/cloud/nexus_cloud.dart';
import 'package:nexus/data/app_store.dart';
import 'package:nexus/widgets/nexus_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

// Synthetic 1x1 PNG; only the OS image-picker boundary is replaced.
final photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1kAAAAASUVORK5CYII=',
);

class SyntheticPicker extends ImagePickerPlatform {
  SyntheticPicker(this.bytes);
  final Uint8List? bytes;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => bytes == null
      ? null
      : XFile.fromData(bytes!, mimeType: 'image/png', name: 'synthetic.png');
}

void main() {
  for (final action in ['save', 'cancel', 'no_photo']) {
    testWidgets('problem photo $action survives sheet exit and cold restore', (
      tester,
    ) async {
      final oldPicker = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = SyntheticPicker(
        action == 'no_photo' ? null : photo,
      );
      final previous = SharedPreferencesStorePlatform.instance;
      final disk = InMemorySharedPreferencesStore.empty();
      SharedPreferencesStorePlatform.instance = disk;
      SharedPreferences.resetStatic();
      addTearDown(() {
        ImagePickerPlatform.instance = oldPicker;
        SharedPreferencesStorePlatform.instance = previous;
        SharedPreferences.resetStatic();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const NexusApp());
      final nav = find.byType(NexusNavBar);
      for (var i = 0; i < 40 && nav.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await CloudScope.read(tester.element(nav)).enterGuestSession();
      await tester.pumpAndSettle();
      final store = AppScope.read(tester.element(nav));
      final subject = store.addSubject(name: '合成教科');
      // Let prior subject writes finish so they cannot accidentally save the problem.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.tap(find.descendant(of: nav, matching: find.text('Study')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('問題を記録'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('問題を記録'));
      await tester.pumpAndSettle();
      if (action != 'no_photo') {
        Future<void> input(String label, String value) async {
          final field = find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == label,
          );
          await tester.ensureVisible(field);
          await tester.enterText(field, value);
        }

        await input('問題名（任意）', '合成問題');
        await input('解答（任意）', '合成解答');
        if (action == 'save') {
          await tester.ensureVisible(find.widgetWithText(FilledButton, '保存'));
          await tester.tap(find.widgetWithText(FilledButton, '保存'));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNothing);
      final saved = action == 'save';
      expect(store.problems.length, saved ? 1 : 0);
      expect(store.reviewCards.length, saved ? 2 : 0);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      void check(Map<String, dynamic> bundle) {
        final problems = bundle['problems'] as List;
        final reviews = bundle['reviewCards'] as List;
        expect(problems.length, saved ? 1 : 0);
        expect(reviews.length, saved ? 2 : 0);
        if (saved) {
          final item = problems.single;
          expect(item['title'], '合成問題');
          expect(item['answer'], '合成解答');
          expect(item['subjectId'], subject.id);
          expect(item['photo'], base64Encode(photo));
          expect(item['id'], store.problems.single.id);
          expect(reviews.map((r) => r['problemId']), [item['id'], item['id']]);
          expect(reviews.map((r) => r['intervalStep']), [1, 5]);
        }
      }

      final data = await disk.getAll();
      final device = jsonDecode(
        data['flutter.nexus_user_data_v2_guest'] as String,
      );
      final live = jsonDecode(
        data['flutter.nexus_cloud_v1'] as String,
      )['live']['guest'];
      check(Map<String, dynamic>.from(device));
      check(Map<String, dynamic>.from(live));
      SharedPreferences.resetStatic();
      final cloud = NexusCloud();
      await cloud.enterGuestSession();
      final restored = AppStore.seed();
      await restored.attachCloud(cloud);
      check(restored.toCloudMap());
      if (saved) expect(restored.problems.single.photoBytes, photo);
      restored.dispose();
      cloud.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
