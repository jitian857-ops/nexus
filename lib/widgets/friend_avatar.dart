import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/theme.dart';
import '../cloud/cloud_models.dart';
import '../cloud/nexus_cloud.dart';
import 'ui_bits.dart';

Uint8List? decodeDataUrl(String src) {
  final marker = src.indexOf('base64,');
  if (marker < 0) return null;
  try {
    return base64Decode(src.substring(marker + 7));
  } catch (_) {
    return null;
  }
}

const _maxDataUrlCache = 48;
final Map<String, Uint8List> _dataUrlBytes = {};
final List<String> _dataUrlOrder = [];

Uint8List? cachedDecodeDataUrl(String src) {
  final hit = _dataUrlBytes[src];
  if (hit != null) {
    _dataUrlOrder.remove(src);
    _dataUrlOrder.add(src);
    return hit;
  }
  final bytes = decodeDataUrl(src);
  if (bytes == null) return null;
  _dataUrlBytes[src] = bytes;
  _dataUrlOrder.add(src);
  while (_dataUrlOrder.length > _maxDataUrlCache) {
    _dataUrlBytes.remove(_dataUrlOrder.removeAt(0));
  }
  return bytes;
}

int imageCachePx(BuildContext context, double logical) {
  return (logical * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 4096);
}

class NexusImage extends StatefulWidget {
  const NexusImage({
    super.key,
    required this.src,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String src;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<NexusImage> createState() => _NexusImageState();
}

class _NexusImageState extends State<NexusImage> {
  Future<String>? _resolve;
  String? _resolveSrc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureResolve();
  }

  @override
  void didUpdateWidget(covariant NexusImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) {
      _resolve = null;
      _resolveSrc = null;
      _ensureResolve();
    }
  }

  void _ensureResolve() {
    final src = widget.src;
    if (src.isEmpty ||
        src.startsWith('data:') ||
        src.startsWith('http://') ||
        src.startsWith('https://')) {
      return;
    }
    final cloud = CloudScope.maybeOf(context);
    if (cloud == null) return;
    if (_resolveSrc == src && _resolve != null) return;
    _resolveSrc = src;
    _resolve = cloud.resolveMedia(src);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.src.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: ColoredBox(color: NexusColors.surface),
      );
    }
    if (widget.src.startsWith('data:') ||
        widget.src.startsWith('http://') ||
        widget.src.startsWith('https://')) {
      return _pixels(context, widget.src);
    }
    final pending = _resolve;
    if (pending == null) return _pixels(context, widget.src);
    return FutureBuilder<String>(
      future: pending,
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved == null || resolved.isEmpty) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: ColoredBox(color: NexusColors.surface),
          );
        }
        return _pixels(context, resolved);
      },
    );
  }

  Widget _pixels(BuildContext context, String value) {
    final cacheW = widget.width == null ? null : imageCachePx(context, widget.width!);
    final cacheH = widget.height == null ? null : imageCachePx(context, widget.height!);
    if (value.startsWith('data:')) {
      final bytes = cachedDecodeDataUrl(value);
      if (bytes == null) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(child: Text('画像なし')),
        );
      }
      return Image.memory(
        bytes,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ColoredBox(color: NexusColors.surface),
    );
  }
}

class FriendAvatar extends StatelessWidget {
  const FriendAvatar({
    super.key,
    required this.name,
    this.photoUrl = '',
    this.radius = 20,
  });

  final String name;
  final String photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final child = photoUrl.isEmpty
        ? Center(
            child: Text(
              _initial(name),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.85,
                color: NexusColors.text,
              ),
            ),
          )
        : ClipOval(child: NexusImage(src: photoUrl, width: size, height: size));
    return CircleAvatar(
      radius: radius,
      backgroundColor: NexusColors.surface,
      child: child,
    );
  }
}

String _initial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCodes(trimmed.runes.take(1));
}

Future<ImageSource?> pickImageSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('アルバムから選ぶ'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('カメラで撮る'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
}

Future<String?> pickAndUploadMedia(
  BuildContext context, {
  ImageSource? source,
  bool avatar = false,
}) async {
  final urls = await pickAndUploadMediaList(context, source: source, avatar: avatar, multiple: false);
  if (urls.isEmpty) return null;
  return urls.first;
}

Future<List<String>> pickAndUploadMediaList(
  BuildContext context, {
  ImageSource? source,
  bool avatar = false,
  bool multiple = true,
}) async {
  final pickedSource = source ?? await pickImageSource(context);
  if (pickedSource == null || !context.mounted) return const [];
  final files = <XFile>[];
  if (multiple && !avatar && pickedSource == ImageSource.gallery) {
    files.addAll(await ImagePicker().pickMultiImage());
  } else {
    final file = await ImagePicker().pickImage(source: pickedSource);
    if (file != null) files.add(file);
  }
  if (files.isEmpty || !context.mounted) return const [];
  final urls = <String>[];
  final cloud = CloudScope.of(context);
  for (final file in files) {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      urls.add(
        await cloud.uploadMedia(
          bytes,
          mime: file.mimeType ?? 'image/jpeg',
          avatar: avatar,
        ),
      );
    } catch (error) {
      if (context.mounted) showNexusToast(context, cloudErrorMessage(error));
    }
  }
  return urls;
}
