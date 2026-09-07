import 'package:flutter/material.dart';

import '../app/motion.dart';
import '../app/theme.dart';
import '../core/format.dart';
import '../data/app_store.dart';

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

int reelMinuteStepOf(BuildContext context) {
  try {
    return AppScope.of(context).settings.reelMinuteStep;
  } catch (_) {
    return 1;
  }
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
  var _step = 1;
  var _ready = false;

  int get _maxHours => widget.maxMinutes ~/ 60;
  int get _hourMod => _maxHours + 1;
  int get _minMod => reelMinuteCount(_step);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final step = reelMinuteStepOf(context);
    final total = widget.minutes.clamp(widget.minMinutes, widget.maxMinutes);
    if (!_ready) {
      _step = step;
      _hours = FixedExtentScrollController(initialItem: loopingIndex(total ~/ 60, _hourMod));
      _mins = FixedExtentScrollController(
        initialItem: loopingIndex(minuteIndexForReel(total % 60, _step), _minMod),
      );
      _ready = true;
      return;
    }
    if (step == _step) return;
    _step = step;
    final old = _mins;
    _mins = FixedExtentScrollController(
      initialItem: loopingIndex(minuteIndexForReel(total % 60, _step), _minMod),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
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
    if (_ready) {
      _hours.dispose();
      _mins.dispose();
    }
    super.dispose();
  }

  void _syncTo(int hours, int minutes) {
    final minMod = _minMod;
    final wantMin = minuteIndexForReel(minutes, _step);
    final currentHours = _hours.hasClients ? loopingValue(_hours.selectedItem, _hourMod) : hours;
    final currentMins = _mins.hasClients ? loopingValue(_mins.selectedItem, minMod) : wantMin;
    if (currentHours == hours && currentMins == wantMin) return;
    _programmatic = true;
    _move(_hours, loopingTarget(_hours.hasClients ? _hours.selectedItem : loopingIndex(hours, _hourMod), hours, _hourMod));
    _move(_mins, loopingTarget(_mins.hasClients ? _mins.selectedItem : loopingIndex(wantMin, minMod), wantMin, minMod));
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
    final nextMins = minuteFromReelIndex(
      minutes ?? loopingValue(_mins.hasClients ? _mins.selectedItem : 0, _minMod),
      _step,
    ).clamp(0, 59);
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
              minuteModulus: _minMod,
              padHours: false,
              minuteLabelOf: (value) => two(minuteFromReelIndex(value, _step)),
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
  var _step = 1;
  var _ready = false;

  int get _minMod => reelMinuteCount(_step);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final step = reelMinuteStepOf(context);
    if (!_ready) {
      _step = step;
      _hours = FixedExtentScrollController(initialItem: loopingIndex(widget.time.hour, 24));
      _mins = FixedExtentScrollController(
        initialItem: loopingIndex(minuteIndexForReel(widget.time.minute, _step), _minMod),
      );
      _ready = true;
      return;
    }
    if (step == _step) return;
    _step = step;
    final old = _mins;
    _mins = FixedExtentScrollController(
      initialItem: loopingIndex(minuteIndexForReel(widget.time.minute, _step), _minMod),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void didUpdateWidget(covariant ClockTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.time == oldWidget.time) return;
    _syncTo(widget.time.hour, widget.time.minute);
  }

  @override
  void dispose() {
    if (_ready) {
      _hours.dispose();
      _mins.dispose();
    }
    super.dispose();
  }

  void _syncTo(int hours, int minutes) {
    final minMod = _minMod;
    final wantMin = minuteIndexForReel(minutes, _step);
    final currentHours = _hours.hasClients ? loopingValue(_hours.selectedItem, 24) : hours;
    final currentMins = _mins.hasClients ? loopingValue(_mins.selectedItem, minMod) : wantMin;
    if (currentHours == hours && currentMins == wantMin) return;
    _move(_hours, loopingTarget(_hours.hasClients ? _hours.selectedItem : loopingIndex(hours, 24), hours, 24));
    _move(_mins, loopingTarget(_mins.hasClients ? _mins.selectedItem : loopingIndex(wantMin, minMod), wantMin, minMod));
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
      minute: minuteFromReelIndex(
        minutes ?? loopingValue(_mins.hasClients ? _mins.selectedItem : 0, _minMod),
        _step,
      ),
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
          minuteModulus: _minMod,
          padHours: true,
          minuteLabelOf: (value) => two(minuteFromReelIndex(value, _step)),
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
    required this.minuteModulus,
    required this.padHours,
    required this.onHours,
    required this.onMinutes,
    this.minuteLabelOf,
  });

  final FixedExtentScrollController hours;
  final FixedExtentScrollController minutes;
  final int hourModulus;
  final int minuteModulus;
  final bool padHours;
  final ValueChanged<int> onHours;
  final ValueChanged<int> onMinutes;
  final String Function(int value)? minuteLabelOf;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: Stack(
        clipBehavior: Clip.hardEdge,
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
                child: NexusReelWheel(
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
                child: NexusReelWheel(
                  controller: minutes,
                  modulus: minuteModulus,
                  pad: true,
                  labelOf: minuteLabelOf,
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

class NexusReelWheel extends StatefulWidget {
  const NexusReelWheel({
    super.key,
    required this.controller,
    required this.modulus,
    required this.onChanged,
    this.pad = false,
    this.labelOf,
  });

  final FixedExtentScrollController controller;
  final int modulus;
  final ValueChanged<int> onChanged;
  final bool pad;
  final String Function(int value)? labelOf;

  @override
  State<NexusReelWheel> createState() => _NexusReelWheelState();
}

class _NexusReelWheelState extends State<NexusReelWheel> {
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
            final label = widget.labelOf?.call(value) ?? (widget.pad ? two(value) : '$value');
            return Align(
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: selected ? 22 : 16,
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

class DateReelPicker extends StatefulWidget {
  const DateReelPicker({
    super.key,
    required this.day,
    required this.onChanged,
  });

  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  @override
  State<DateReelPicker> createState() => _DateReelPickerState();
}

class _DateReelPickerState extends State<DateReelPicker> {
  late final int _minYear;
  late final int _yearMod;
  late FixedExtentScrollController _years;
  late FixedExtentScrollController _months;
  late FixedExtentScrollController _days;
  late int _year;
  late int _month;
  late int _day;

  @override
  void initState() {
    super.initState();
    final initial = dateOnly(widget.day);
    _minYear = initial.year - 6;
    _yearMod = 13;
    _year = initial.year.clamp(_minYear, _minYear + _yearMod - 1);
    _month = initial.month;
    _day = initial.day.clamp(1, _daysInMonth);
    _years = FixedExtentScrollController(initialItem: loopingIndex(_year - _minYear, _yearMod));
    _months = FixedExtentScrollController(initialItem: loopingIndex(_month - 1, 12));
    _days = FixedExtentScrollController(initialItem: loopingIndex(_day - 1, 31));
  }

  @override
  void dispose() {
    _years.dispose();
    _months.dispose();
    _days.dispose();
    super.dispose();
  }

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  void _emit() {
    final dim = _daysInMonth;
    if (_day > dim) {
      _day = dim;
      if (_days.hasClients) {
        _days.jumpToItem(loopingTarget(_days.selectedItem, _day - 1, 31));
      }
    }
    widget.onChanged(DateTime(_year, _month, _day));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: Stack(
            clipBehavior: Clip.hardEdge,
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
                    flex: 5,
                    child: NexusReelWheel(
                      controller: _years,
                      modulus: _yearMod,
                      labelOf: (value) => '${_minYear + value}',
                      onChanged: (value) {
                        _year = _minYear + value;
                        _emit();
                      },
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: NexusReelWheel(
                      controller: _months,
                      modulus: 12,
                      labelOf: (value) => '${value + 1}',
                      onChanged: (value) {
                        _month = value + 1;
                        _emit();
                      },
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: NexusReelWheel(
                      controller: _days,
                      modulus: 31,
                      labelOf: (value) => '${value + 1}',
                      onChanged: (value) {
                        _day = value + 1;
                        _emit();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                '年',
                textAlign: TextAlign.center,
                style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                '月',
                textAlign: TextAlign.center,
                style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                '日',
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
