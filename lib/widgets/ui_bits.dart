import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/motion.dart';
import '../app/theme.dart';
import '../data/nexus_icons.dart';
import 'aurora_backdrop.dart';

void nexusHaptic() {
  HapticFeedback.lightImpact();
}

Future<void> nexusTimerDoneFeedback() async {
  SystemSound.play(SystemSoundType.alert);
  await HapticFeedback.heavyImpact();
  await Future<void>.delayed(const Duration(milliseconds: 140));
  await HapticFeedback.mediumImpact();
  await Future<void>.delayed(const Duration(milliseconds: 140));
  await HapticFeedback.heavyImpact();
}

class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NexusColors.pageTop, NexusColors.background],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: AuroraBackdrop()),
          SafeArea(bottom: false, child: child),
        ],
      ),
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
      shaderCallback: (rect) {
        return LinearGradient(
          colors: [
            NexusColors.cyan,
            NexusColors.periwinkle,
            NexusColors.purple,
          ],
        ).createShader(rect);
      },
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1.8,
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
    return PressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  NexusColors.cyan.withValues(alpha: 0.22),
                  NexusColors.purple.withValues(alpha: 0.16),
                ],
              ),
              border: Border.all(color: NexusColors.cyan.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: NexusColors.cyan.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 14, color: NexusColors.cyan),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: NexusColors.cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
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
        Container(
          width: 3,
          height: 14,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [NexusColors.cyan, NexusColors.purple],
            ),
          ),
        ),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: NexusColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
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
                  icon: Icon(Icons.close_rounded, size: 20, color: NexusColors.textMuted),
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
      content: Text(message, style: TextStyle(color: NexusColors.text)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: NexusColors.surface,
    ),
  );
}

class ReorderableTapDragListener extends StatefulWidget {
  const ReorderableTapDragListener({
    super.key,
    required this.index,
    required this.onTap,
    required this.child,
    this.enabled = true,
  });

  final int index;
  final VoidCallback onTap;
  final Widget child;
  final bool enabled;

  @override
  State<ReorderableTapDragListener> createState() => _ReorderableTapDragListenerState();
}

class _ReorderableTapDragListenerState extends State<ReorderableTapDragListener> {
  var _moved = false;
  Offset? _origin;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.grab : SystemMouseCursors.click,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          _moved = false;
          _origin = event.position;
          if (!widget.enabled) return;
          final list = SliverReorderableList.maybeOf(context);
          if (list == null) return;
          list.startItemDragReorder(
            index: widget.index,
            event: event,
            recognizer: _MoveToDragGestureRecognizer(
              debugOwner: this,
              onAccepted: () => _moved = true,
            ),
          );
        },
        onPointerMove: (event) {
          final origin = _origin;
          if (origin == null) return;
          if ((event.position - origin).distance > 8) _moved = true;
        },
        onPointerUp: (_) {
          if (!_moved) widget.onTap();
          _origin = null;
        },
        onPointerCancel: (_) => _origin = null,
        child: widget.child,
      ),
    );
  }
}

class _MoveToDragGestureRecognizer extends MultiDragGestureRecognizer {
  _MoveToDragGestureRecognizer({
    super.debugOwner,
    required this.onAccepted,
  });

  final VoidCallback onAccepted;

  @override
  String get debugDescription => 'move to drag';

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    return _MoveToDragPointerState(
      event.position,
      event.kind,
      gestureSettings,
      onAccepted,
    );
  }
}

class _MoveToDragPointerState extends MultiDragPointerState {
  _MoveToDragPointerState(
    super.initialPosition,
    super.kind,
    super.gestureSettings,
    this.onAccepted,
  );

  final VoidCallback onAccepted;

  @override
  void checkForResolutionAfterMove() {
    final delta = pendingDelta;
    if (delta == null) return;
    if (delta.distance > computeHitSlop(kind, gestureSettings)) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    onAccepted();
    starter(initialPosition);
  }
}

class BoxLookPicker extends StatelessWidget {
  const BoxLookPicker({
    super.key,
    required this.icon,
    required this.color,
    required this.onIcon,
    required this.onColor,
    this.icons = kNexusIcons,
    this.choices,
    this.iconAreaHeight = 96,
  });

  final IconData icon;
  final Color color;
  final ValueChanged<IconData> onIcon;
  final ValueChanged<Color> onColor;
  final List<IconData> icons;
  final List<NexusIconChoice>? choices;
  final double iconAreaHeight;

  @override
  Widget build(BuildContext context) {
    final items = choices ?? [for (final i in icons) NexusIconChoice(i)];
    final labeled = choices != null;
    final swatches = [
      ...NexusColors.boxPalette,
      if (NexusColors.boxPalette.every((c) => c != color)) color,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('アイコン', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
        SizedBox(
          height: iconAreaHeight,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: labeled ? 6 : 8,
              runSpacing: labeled ? 8 : 0,
              children: [
                for (final item in items)
                  InkWell(
                    onTap: () => onIcon(item.icon),
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: labeled ? 58 : 40,
                      child: Column(
                        children: [
                          Icon(
                            item.icon,
                            color: item.icon == icon ? color : NexusColors.textMuted,
                          ),
                          if (item.label.isNotEmpty)
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                color: item.icon == icon ? color : NexusColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Text('色', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in swatches)
                GestureDetector(
                  onTap: () => onColor(c),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == color ? NexusColors.text : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
