import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/format.dart';

const kMinStudyDurationMinutes = 1;
const kMaxStudyDurationMinutes = 12 * 60;

class DurationMinutesPicker extends StatefulWidget {
  const DurationMinutesPicker({
    super.key,
    required this.minutes,
    required this.onChanged,
    this.enabled = true,
    this.minMinutes = kMinStudyDurationMinutes,
    this.maxMinutes = kMaxStudyDurationMinutes,
  });

  final int minutes;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final int minMinutes;
  final int maxMinutes;

  @override
  State<DurationMinutesPicker> createState() => _DurationMinutesPickerState();
}

class _DurationMinutesPickerState extends State<DurationMinutesPicker> {
  late FixedExtentScrollController _hours;
  late FixedExtentScrollController _mins;
  var _syncing = false;

  int get _maxHours => widget.maxMinutes ~/ 60;

  @override
  void initState() {
    super.initState();
    final total = widget.minutes.clamp(widget.minMinutes, widget.maxMinutes);
    _hours = FixedExtentScrollController(initialItem: total ~/ 60);
    _mins = FixedExtentScrollController(initialItem: total % 60);
  }

  @override
  void didUpdateWidget(covariant DurationMinutesPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_syncing || widget.minutes == oldWidget.minutes) return;
    final total = widget.minutes.clamp(widget.minMinutes, widget.maxMinutes);
    _jump(_hours, total ~/ 60);
    _jump(_mins, total % 60);
  }

  @override
  void dispose() {
    _hours.dispose();
    _mins.dispose();
    super.dispose();
  }

  void _jump(FixedExtentScrollController controller, int item) {
    if (!controller.hasClients || controller.selectedItem == item) return;
    controller.jumpToItem(item);
  }

  void _emit({int? hours, int? minutes}) {
    if (!widget.enabled) return;
    final nextHours = (hours ?? (_hours.hasClients ? _hours.selectedItem : widget.minutes ~/ 60))
        .clamp(0, _maxHours);
    final nextMins = (minutes ?? (_mins.hasClients ? _mins.selectedItem : widget.minutes % 60))
        .clamp(0, 59);
    final total = (nextHours * 60 + nextMins).clamp(widget.minMinutes, widget.maxMinutes);
    if (total == widget.minutes) return;
    _syncing = true;
    widget.onChanged(total);
    _syncing = false;
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '時間  ${studyGoalLabel(widget.minutes)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NexusColors.cyan,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 168,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IgnorePointer(
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: NexusColors.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: NexusColors.cyan.withValues(alpha: 0.28)),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _DurationWheel(
                          controller: _hours,
                          itemCount: _maxHours + 1,
                          onChanged: (value) => _emit(hours: value),
                        ),
                      ),
                      const Text(
                        ':',
                        style: TextStyle(
                          fontSize: 26,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          color: NexusColors.textMuted,
                        ),
                      ),
                      Expanded(
                        child: _DurationWheel(
                          controller: _mins,
                          itemCount: 60,
                          pad: true,
                          onChanged: (value) => _emit(minutes: value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Row(
              children: [
                Expanded(
                  child: Text(
                    '時間',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '分',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationWheel extends StatefulWidget {
  const _DurationWheel({
    required this.controller,
    required this.itemCount,
    required this.onChanged,
    this.pad = false,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final ValueChanged<int> onChanged;
  final bool pad;

  @override
  State<_DurationWheel> createState() => _DurationWheelState();
}

class _DurationWheelState extends State<_DurationWheel> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) => notification.depth == 0,
      child: ListWheelScrollView.useDelegate(
        controller: widget.controller,
        itemExtent: 44,
        perspective: 0.003,
        diameterRatio: 1.2,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          setState(() {});
          widget.onChanged(index);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: widget.itemCount,
          builder: (context, index) {
            final selected =
                widget.controller.hasClients && widget.controller.selectedItem == index;
            final label = widget.pad ? two(index) : '$index';
            return Align(
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: selected ? 26 : 18,
                  height: 1,
                  leadingDistribution: TextLeadingDistribution.even,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? NexusColors.text : NexusColors.textMuted,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
