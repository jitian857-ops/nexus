import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../voice/speech_service.dart';
import 'ui_bits.dart';

Future<String?> captureVoiceText(BuildContext context) async {
  final speech = SpeechService.instance;
  final ready = await speech.ensureReady();
  if (!context.mounted) return null;
  if (!ready) {
    return showVoiceTextFallback(context, message: speech.lastError);
  }
  return showVoiceListenSheet(context);
}

Future<String?> showVoiceTextFallback(BuildContext context, {String message = ''}) {
  final input = TextEditingController();
  return showNexusSheet<String>(
    context: context,
    builder: (sheet) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('文字で指示', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(message, style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: input,
            autofocus: true,
            decoration: const InputDecoration(hintText: '例: 明日18時にバイト'),
            onSubmitted: (value) => Navigator.pop(sheet, value.trim()),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(sheet, input.text.trim()),
            child: const Text('実行'),
          ),
        ],
      );
    },
  ).whenComplete(input.dispose);
}

Future<String?> showVoiceListenSheet(BuildContext context) {
  return showNexusSheet<String>(
    context: context,
    builder: (_) => const _VoiceListenBody(),
  );
}

class VoiceFillButton extends StatelessWidget {
  const VoiceFillButton({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '声で入力',
      onPressed: () async {
        final text = await captureVoiceText(context);
        if (text == null || text.trim().isEmpty) return;
        controller.text = text.trim();
        controller.selection = TextSelection.collapsed(offset: controller.text.length);
      },
      icon: Icon(Icons.mic_none_rounded, color: NexusColors.cyan),
    );
  }
}

class _VoiceListenBody extends StatefulWidget {
  const _VoiceListenBody();

  @override
  State<_VoiceListenBody> createState() => _VoiceListenBodyState();
}

class _VoiceListenBodyState extends State<_VoiceListenBody> {
  var _partial = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  Future<void> _listen() async {
    try {
      final text = await SpeechService.instance.listenOnce(
        onPartial: (value) {
          if (mounted) setState(() => _partial = value);
        },
      );
      if (!mounted) return;
      Navigator.pop(context, text);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    SpeechService.instance.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('聞いています', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          _partial.isEmpty ? '予定やお金、勉強のことを話してください' : _partial,
          style: TextStyle(color: _partial.isEmpty ? NexusColors.textMuted : NexusColors.text),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: LinearProgressIndicator(),
        ),
        TextButton(
          onPressed: () async {
            await SpeechService.instance.cancel();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () async {
            await SpeechService.instance.cancel();
            if (!context.mounted) return;
            final text = await showVoiceTextFallback(context);
            if (context.mounted) Navigator.pop(context, text);
          },
          child: const Text('文字で入力'),
        ),
      ],
    );
  }
}
