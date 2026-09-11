import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class CompressedImage {
  const CompressedImage({required this.bytes, required this.mime});

  final Uint8List bytes;
  final String mime;
}

/// Firestore の1件は約1MB。base64化の余裕を見て、写真は約220KB、アイコンは約80KBまで落とす。
/// すでに小さいデータはそのまま返す。
CompressedImage compressForFirestore(
  List<int> raw, {
  bool avatar = false,
  String mime = 'image/jpeg',
}) {
  final maxSide = avatar ? 320 : 960;
  final maxBytes = avatar ? 80 * 1024 : 220 * 1024;
  final source = Uint8List.fromList(raw);
  if (source.isEmpty) return CompressedImage(bytes: source, mime: mime);
  if (source.length <= maxBytes) {
    return CompressedImage(bytes: source, mime: mime);
  }

  final decoded = img.decodeImage(source);
  if (decoded == null) {
    return CompressedImage(bytes: source, mime: mime);
  }

  var side = maxSide;
  var quality = avatar ? 70 : 72;
  var image = _fit(decoded, side);
  var out = Uint8List.fromList(img.encodeJpg(image, quality: quality));

  while (out.length > maxBytes && quality > 32) {
    quality -= 8;
    out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }
  while (out.length > maxBytes && side > 160) {
    side = (side * 0.72).round();
    image = _fit(decoded, side);
    quality = avatar ? 62 : 64;
    out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }
  return CompressedImage(bytes: out, mime: 'image/jpeg');
}

Future<CompressedImage> compressForFirestoreAsync(
  List<int> raw, {
  bool avatar = false,
  String mime = 'image/jpeg',
}) async {
  final copy = Uint8List.fromList(raw);
  final maxBytes = avatar ? 80 * 1024 : 220 * 1024;
  if (copy.isEmpty || copy.length <= maxBytes) {
    return CompressedImage(bytes: copy, mime: mime);
  }
  try {
    final result = await Isolate.run(() {
      final packed = compressForFirestore(copy, avatar: avatar, mime: mime);
      return (packed.bytes, packed.mime);
    });
    return CompressedImage(bytes: result.$1, mime: result.$2);
  } catch (_) {
    return compressForFirestore(copy, avatar: avatar, mime: mime);
  }
}

img.Image _fit(img.Image source, int maxSide) {
  if (source.width <= maxSide && source.height <= maxSide) return source;
  if (source.width >= source.height) {
    return img.copyResize(source, width: maxSide);
  }
  return img.copyResize(source, height: maxSide);
}
