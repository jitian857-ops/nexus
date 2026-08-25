import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../widgets/ui_bits.dart';

Future<void> openSleepLogger(BuildContext context, AppStore store) async {
  var bed = store.sleepStartedAt ??
      DateTime(
        store.focusedDate.year,
        store.focusedDate.month,
        store.focusedDate.day,
      ).subtract(const Duration(hours: 7, minutes: 30));
  if (bed.hour < 12) {
    bed = DateTime(bed.year, bed.month, bed.day - 1, 23, 30);
  }
  var wake = DateTime(
    store.focusedDate.year,
    store.focusedDate.month,
    store.focusedDate.day,
    7,
    0,
  );
  final latest = store.latestSleepLog;
  if (latest != null && store.sleepStartedAt == null) {
    bed = latest.bedAt;
    wake = latest.wakeAt;
  }
  var quality = latest?.quality ?? 4;

  await showNexusSheet<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          final hours = wake.difference(bed).inMinutes / 60.0;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('睡眠を記録', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  store.isSleeping
                      ? '就寝中です。起きたらボタンを押してください。'
                      : '就寝と起床を分けて記録します。あとから直すこともできます。',
                  style: const TextStyle(color: NexusColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                if (store.isSleeping) ...[
                  Text(
                    '就寝 ${hm(store.sleepStartedAt!)}',
                    style: const TextStyle(color: NexusColors.purple, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () {
                      store.wakeUp(quality: quality);
                      Navigator.pop(context);
                    },
                    child: const Text('起きた'),
                  ),
                  TextButton(
                    onPressed: () {
                      store.cancelSleep();
                      setSheet(() {});
                    },
                    child: const Text('就寝を取り消す'),
                  ),
                ] else ...[
                  FilledButton.tonal(
                    onPressed: () {
                      store.startSleep();
                      Navigator.pop(context);
                    },
                    child: const Text('今から寝る'),
                  ),
                  const SizedBox(height: 12),
                  const Text('あとから記録', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(bed),
                      );
                      if (picked == null) return;
                      setSheet(() {
                        bed = DateTime(bed.year, bed.month, bed.day, picked.hour, picked.minute);
                        if (!wake.isAfter(bed)) {
                          wake = bed.add(const Duration(hours: 8));
                        }
                      });
                    },
                    child: Text('就寝  ${hm(bed)}'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(wake),
                      );
                      if (picked == null) return;
                      setSheet(() {
                        wake = DateTime(wake.year, wake.month, wake.day, picked.hour, picked.minute);
                        if (!wake.isAfter(bed)) {
                          wake = wake.add(const Duration(days: 1));
                        }
                      });
                    },
                    child: Text('起床  ${hm(wake)}'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hours <= 0 ? '時刻を確認してください' : '${hours.toStringAsFixed(1)} 時間',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final h in const [6.0, 7.0, 7.5, 8.0])
                        ActionChip(
                          label: Text('${h}h'),
                          onPressed: () => setSheet(() {
                            wake = DateTime(store.focusedDate.year, store.focusedDate.month, store.focusedDate.day, 7);
                            bed = wake.subtract(Duration(minutes: (h * 60).round()));
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('眠りの質', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
                  Slider(
                    value: quality.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: switch (quality) {
                      1 => '浅い',
                      2 => 'いまいち',
                      3 => '普通',
                      4 => 'よい',
                      _ => 'とてもよい',
                    },
                    onChanged: (v) => setSheet(() => quality = v.round()),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: hours <= 0
                        ? null
                        : () {
                            store.logSleep(bedAt: bed, wakeAt: wake, quality: quality);
                            Navigator.pop(context);
                          },
                    child: const Text('保存'),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}
