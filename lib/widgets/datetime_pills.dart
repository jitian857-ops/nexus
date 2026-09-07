import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/format.dart';
import 'duration_picker.dart';
import 'ui_bits.dart';

String hmOfDay(TimeOfDay time) => '${two(time.hour)}:${two(time.minute)}';

Future<DateTime?> showDateReelSheet(
  BuildContext context, {
  required DateTime initial,
}) {
  var day = dateOnly(initial);
  return showNexusSheet<DateTime>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) {
      return StatefulBuilder(
        builder: (sheet, setSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '日付',
                style: TextStyle(
                  color: NexusColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                jpDateWeekday(day),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NexusColors.cyan,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DateReelPicker(
                day: day,
                onChanged: (next) => setSheet(() => day = next),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(sheet, day),
                child: const Text('決定'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<TimeOfDay?> showTimeReelSheet(
  BuildContext context, {
  required TimeOfDay initial,
}) {
  var time = initial;
  return showNexusSheet<TimeOfDay>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) {
      return StatefulBuilder(
        builder: (sheet, setSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '時間',
                style: TextStyle(
                  color: NexusColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ClockTimePicker(
                time: time,
                onChanged: (next) => setSheet(() => time = next),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(sheet, time),
                child: const Text('決定'),
              ),
            ],
          );
        },
      );
    },
  );
}

class CompactGrayPill extends StatelessWidget {
  const CompactGrayPill({
    super.key,
    required this.label,
    required this.onTap,
    this.muted = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool muted;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final pill = Material(
      color: NexusColors.cardTop,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted ? NexusColors.textMuted : NexusColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
    if (!expand) return pill;
    return Expanded(child: pill);
  }
}

class CompactDateTimeRow extends StatelessWidget {
  const CompactDateTimeRow({
    super.key,
    required this.label,
    required this.day,
    this.time,
    required this.onPickDate,
    this.onPickTime,
  });

  final String label;
  final DateTime day;
  final TimeOfDay? time;
  final VoidCallback onPickDate;
  final VoidCallback? onPickTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              color: NexusColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        CompactGrayPill(
          label: jpDateWeekday(day),
          onTap: onPickDate,
        ),
        if (time != null && onPickTime != null) ...[
          const SizedBox(width: 8),
          CompactGrayPill(
            label: hmOfDay(time!),
            onTap: onPickTime!,
            expand: false,
          ),
        ],
      ],
    );
  }
}
