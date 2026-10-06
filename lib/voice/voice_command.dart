import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../cloud/nexus_cloud.dart';
import '../data/app_store.dart';
import '../screens/study/focus_timer_page.dart';
import '../widgets/ui_bits.dart';
import '../widgets/voice_confirm_sheet.dart';
import '../widgets/voice_listen_button.dart';
import 'intent_parser.dart';
import 'voice_context.dart';
import 'voice_dispatcher.dart';
import 'voice_intent.dart';

Future<void> runVoiceCommand(BuildContext context, {String? transcript}) async {
  final store = AppScope.of(context);
  final text = transcript ?? await captureVoiceText(context);
  if (!context.mounted) return;
  if (text == null || text.trim().isEmpty) return;
  await applyVoiceTranscript(context, store, text.trim());
}

Future<void> applyVoiceTranscript(BuildContext context, AppStore store, String text) async {
  final friends = await _friendNames(context);
  if (!context.mounted) return;
  final parsed = const IntentParser().parse(text, voiceContextOf(store, friends: friends));
  if (parsed is VoiceUnknown) {
    showNexusToast(context, '聞き取れませんでした。${parsed.hint}');
    return;
  }

  var intent = parsed;
  if (intent.needsConfirm) {
    final confirmed = await confirmVoiceIntent(context: context, intent: intent, store: store);
    if (!context.mounted) return;
    if (confirmed == null) return;
    intent = confirmed;
  }

  if (intent is ShareItemIntent) {
    if (intent.viewerId.isEmpty) {
      showNexusToast(context, '共有する相手が見つかりません。表示名と完全に一致する名前を言ってください');
      return;
    }
    final ok = await confirmShareVoice(context: context, intent: intent);
    if (!context.mounted || !ok) return;
  }

  final dispatcher = VoiceDispatcher(store, cloud: CloudScope.maybeOf(context));
  final result = await dispatcher.dispatch(intent);
  if (!context.mounted) return;
  if (result.message.isNotEmpty) showNexusToast(context, result.message);
  if (result.ok && intent is StartTimerIntent) {
    await openFocusTimer(context);
  }
}

Future<List<VoiceNamed>> _friendNames(BuildContext context) async {
  final cloud = CloudScope.maybeOf(context);
  if (cloud == null || !cloud.isSignedIn || cloud.isGuest) return const [];
  try {
    final friends = await cloud.listFriends();
    return [for (final friend in friends) VoiceNamed(id: friend.uid, name: friend.displayName)];
  } catch (_) {
    return const [];
  }
}

class VoiceListenButton extends StatelessWidget {
  const VoiceListenButton({
    super.key,
    this.tooltip = '声で追加',
    this.compact = false,
  });

  final String tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        tooltip: tooltip,
        onPressed: () => runVoiceCommand(context),
        icon: Icon(Icons.mic_rounded, color: NexusColors.cyan),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('voice-command'),
        onTap: () => runVoiceCommand(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                NexusColors.cyan.withValues(alpha: 0.24),
                NexusColors.cyan.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NexusColors.cyan.withValues(alpha: 0.5)),
          ),
          child: Icon(Icons.mic_rounded, size: 16, color: NexusColors.cyan),
        ),
      ),
    );
  }
}
