import 'package:flutter/material.dart';

import '../app/motion.dart';
import '../app/theme.dart';
import '../core/format.dart';

const kMinStudyDurationMinutes = 0;
const kMaxStudyDurationMinutes = 12 * 60 + 59;
const _kLoopCount = 10000;

int loopingIndex(int value, int modulus) {
  final center = (_kLoopCount ~/ 2) ~/ modulus * modulus;
  return center + (value % modulus);
}

int loopingValue(int index, int modulus) => index % modulus;

int loopingTarget(int currentIndex, int targetValue, int modulus) {
  final current = loopingValue(currentIndex, modulus);
  final want = targetValue % modulus;
  var delta = want - current;
  final half = modulus / 2;
  if (delta > half) delta -= modulus;
  if (delta < -half) delta += modulus;
  return currentIndex + delta;
}

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
  var _programmatic = false;

  int get _maxHours => widget.maxMinutes ~/ 60;
  int get _hourMod => _maxHours + 1;

  @override
  void initState() {
    super.initState();
    final total = widget.minutes.clamp(widget.minMinutes, widget.maxMinutes);
    _hours = FixedExtentScrollController(initialItem: loopingIndex(total ~/ 60, _hourMod));
    _mins = FixedExtentScrollController(initialItem: loopingIndex(total % 60, 60));
  }

  @override
  void didUpdateWidget(covariant DurationMinutesPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.minutes == oldWidget.minutes) return;
    final total = widget.minutes.clamp(widget.minMinutes, widget.maxMinutes);
    _syncTo(total ~/ 60, total % 60);
  }

  @override
  void dispose() {
    _hours.dispose();
    _mins.dispose();
    super.dispose();
  }

  void _syncTo(int hours, int minutes) {
    final currentHours = _hours.hasClients ? loopingValue(_hours.selectedItem, _hourMod) : hours;
    final currentMins = _mins.hasClients ? loopingValue(_mins.selectedItem, 60) : minutes;
    if (currentHours == hours && currentMins == minutes) return;
    _programmatic = true;
    _move(_hours, loopingTarget(_hours.hasClients ? _hours.selectedItem : loopingIndex(hours, _hourMod), hours, _hourMod));
    _move(_mins, loopingTarget(_mins.hasClients ? _mins.selectedItem : loopingIndex(minutes, 60), minutes, 60));
    if (NexusMotion.inWidgetTest) {
      _programmatic = false;
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _programmatic = false;
    });
  }

  void _move(FixedExtentScrollController controller, int item) {
    if (!controller.hasClients || controller.selectedItem == item) return;
    if (NexusMotion.inWidgetTest) {
      controller.jumpToItem(item);
      return;
    }
    controller.animateToItem(
      item,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _emit({int? hours, int? minutes}) {
    if (!widget.enabled || _programmatic) return;
    final nextHours = (hours ?? loopingValue(_hours.hasClients ? _hours.selectedItem : 0, _hourMod))
        .clamp(0, _maxHours);
    final nextMins = (minutes ?? loopingValue(_mins.hasClients ? _mins.selectedItem : 0, 60))
        .clamp(0, 59);
    final total = (nextHours * 60 + nextMins).clamp(widget.minMinutes, widget.maxMinutes);
    if (total == widget.minutes) return;
    widget.onChanged(total);
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
              style: TextStyle(
                color: NexusColors.cyan,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _ClockReels(
              hours: _hours,
              minutes: _mins,
              hourModulus: _hourMod,
              padHours: false,
              onHours: (value) => _emit(hours: value),
              onMinutes: (value) => _emit(minutes: value),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '時間',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 12),
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

class ClockTimePicker extends StatefulWidget {
  const ClockTimePicker({
    super.key,
    required this.time,
    required this.onChanged,
  });

  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  State<ClockTimePicker> createState() => _ClockTimePickerState();
}

class _ClockTimePickerState extends State<ClockTimePicker> {
  late FixedExtentScrollController _hours;
  late FixedExtentScrollController _mins;

  @override
  void initState() {
    super.initState();
    _hours = FixedExtentScrollController(initialItem: loopingIndex(widget.time.hour, 24));
    _mins = FixedExtentScrollController(initialItem: loopingIndex(widget.time.minute, 60));
  }

  @override
  void didUpdateWidget(covariant ClockTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.time == oldWidget.time) return;
    _syncTo(widget.time.hour, widget.time.minute);
  }

  @override
  void dispose() {
    _hours.dispose();
    _mins.dispose();
    super.dispose();
  }

  void _syncTo(int hours, int minutes) {
    final currentHours = _hours.hasClients ? loopingValue(_hours.selectedItem, 24) : hours;
    final currentMins = _mins.hasClients ? loopingValue(_mins.selectedItem, 60) : minutes;
    if (currentHours == hours && currentMins == minutes) return;
    _move(_hours, loopingTarget(_hours.hasClients ? _hours.selectedItem : loopingIndex(hours, 24), hours, 24));
    _move(_mins, loopingTarget(_mins.hasClients ? _mins.selectedItem : loopingIndex(minutes, 60), minutes, 60));
  }

  void _move(FixedExtentScrollController controller, int item) {
    if (!controller.hasClients || controller.selectedItem == item) return;
    if (NexusMotion.inWidgetTest) {
      controller.jumpToItem(item);
      return;
    }
    controller.animateToItem(
      item,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _emit({int? hours, int? minutes}) {
    final next = TimeOfDay(
      hour: hours ?? loopingValue(_hours.hasClients ? _hours.selectedItem : 0, 24),
      minute: minutes ?? loopingValue(_mins.hasClients ? _mins.selectedItem : 0, 60),
    );
    if (next == widget.time) return;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${two(widget.time.hour)}:${two(widget.time.minute)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: NexusColors.cyan,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _ClockReels(
          hours: _hours,
          minutes: _mins,
          hourModulus: 24,
          padHours: true,
          onHours: (value) => _emit(hours: value),
          onMinutes: (value) => _emit(minutes: value),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '時',
                textAlign: TextAlign.center,
                style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
              ),
            ),
            const SizedBox(width: 12),
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
    );
  }
}

class _ClockReels extends StatelessWidget {
  const _ClockReels({
    required this.hours,
    required this.minutes,
    required this.hourModulus,
    required this.padHours,
    required this.onHours,
    required this.onMinutes,
  });

  final FixedExtentScrollController hours;
  final FixedExtentScrollController minutes;
  final int hourModulus;
  final bool padHours;
  final ValueChanged<int> onHours;
  final ValueChanged<int> onMinutes;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
                child: _LoopingWheel(
                  controller: hours,
                  modulus: hourModulus,
                  pad: padHours,
                  onChanged: onHours,
                ),
              ),
              Text(
                ':',
                style: TextStyle(
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: NexusColors.textMuted,
                ),
              ),
              Expanded(
                child: _LoopingWheel(
                  controller: minutes,
                  modulus: 60,
                  pad: true,
                  onChanged: onMinutes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoopingWheel extends StatefulWidget {
  const _LoopingWheel({
    required this.controller,
    required this.modulus,
    required this.onChanged,
    this.pad = false,
  });

  final FixedExtentScrollController controller;
  final int modulus;
  final ValueChanged<int> onChanged;
  final bool pad;

  @override
  State<_LoopingWheel> createState() => _LoopingWheelState();
}

class _LoopingWheelState extends State<_LoopingWheel> {
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
          widget.onChanged(loopingValue(index, widget.modulus));
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: _kLoopCount,
          builder: (context, index) {
            final selected =
                widget.controller.hasClients && widget.controller.selectedItem == index;
            final value = loopingValue(index, widget.modulus);
            final label = widget.pad ? two(value) : '$value';
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
