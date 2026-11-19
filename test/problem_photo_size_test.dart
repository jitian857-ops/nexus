import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
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
final tinyPhoto = Uint8List.fromList(
  img.encodePng(img.Image(width: 1, height: 1)),
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
  final canvas = img.Image(width: 1200, height: 900);
  final random = Random(20261119);
  for (final pixel in canvas) {
    pixel.setRgb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
  }
  final images = <String, Uint8List>{
    '1200x900 PNG': Uint8List.fromList(img.encodePng(canvas)),
    '1200x900 JPEG quality70': Uint8List.fromList(
      img.encodeJpg(canvas, quality: 70),
    ),
    for (final size in [179999, 180000, 180001])
      'PNG boundary $size': Uint8List(size)
        ..setRange(0, tinyPhoto.length, tinyPhoto),
  };
  images['cancel compressed JPEG'] = images['1200x900 JPEG quality70']!;
  images['undecodable oversized'] = Uint8List(180001);
  for (final entry in images.entries) {
    final photo = entry.value;
    final action = entry.key == 'undecodable oversized'
        ? 'rejected'
        : entry.key == 'cancel compressed JPEG'
        ? 'cancel'
        : 'save';
    testWidgets('problem photo ${entry.key} persists within limit', (
      tester,
    ) async {
      final oldPicker = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = SyntheticPicker(photo);
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
      for (
        var i = 0;
        i < 400 &&
            find.byType(TextField).evaluate().isEmpty &&
            find.textContaining('別の写真').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      if (action == 'rejected') {
        expect(find.textContaining('別の写真'), findsOneWidget);
      } else {
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
          expect(
            item['photo'],
            isNotNull,
            reason: 'photo must not disappear during serialization',
          );
          final storedPhoto = base64Decode(item['photo'] as String);
          expect(storedPhoto.length, lessThanOrEqualTo(180000));
          expect(img.decodeImage(storedPhoto), isNotNull);
          expect(storedPhoto, store.problems.single.photoBytes);
          if (photo.length <= 180000) expect(storedPhoto, photo);
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
      if (saved) {
        expect(
          restored.problems.single.photoBytes,
          store.problems.single.photoBytes,
        );
        debugPrint(
          '${entry.key}: input=${photo.length} restored=${restored.problems.single.photoBytes!.length}',
        );
      }
      restored.dispose();
      cloud.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
