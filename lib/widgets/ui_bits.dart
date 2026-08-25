import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';

void nexusHaptic() {
  HapticFeedback.lightImpact();
}

class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C1018), NexusColors.background],
        ),
      ),
      child: SafeArea(bottom: false, child: child),
    );
  }
}

class GradientTitle extends StatelessWidget {
  const GradientTitle(this.text, {super.key, this.size = 32});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        colors: [
          NexusColors.cyan.withValues(alpha: 0.92),
          NexusColors.purple.withValues(alpha: 0.88),
        ],
      ).createShader(rect),
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class AddChip extends StatelessWidget {
  const AddChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NexusColors.cyanMuted.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14, color: NexusColors.cyanMuted.withValues(alpha: 0.95)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: NexusColors.cyanMuted.withValues(alpha: 0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionRow extends StatelessWidget {
  const SectionRow({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: NexusColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

Future<T?> showNexusSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: true,
    useRootNavigator: useRootNavigator,
    backgroundColor: NexusColors.card,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final maxBody = (media.size.height * 0.82 - media.viewInsets.bottom).clamp(160.0, 720.0);
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 8, media.viewInsets.bottom + 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxBody),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              ListView(
                shrinkWrap: true,
                primary: false,
                padding: const EdgeInsets.only(top: 4, right: 40, left: 0, bottom: 8),
                children: [builder(sheetContext)],
              ),
              Positioned(
                top: -8,
                right: 0,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '閉じる',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close_rounded, size: 20, color: NexusColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void showNexusToast(BuildContext context, String message) {
  if (message.isEmpty) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: NexusColors.text)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: NexusColors.surface,
    ),
  );
}
