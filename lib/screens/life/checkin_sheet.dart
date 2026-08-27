import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/app_store.dart';
import '../../domain/report_builder.dart';
import '../../widgets/ui_bits.dart';

Future<void> openCheckIn(BuildContext context, AppStore store) async {
  var mood = store.mood == 0 ? 3 : store.mood;
  var energy = store.energy == 0 ? 3 : store.energy;
  final tags = [...store.checkInOn(store.lifeDate).tags];
  final diary = TextEditingController(text: store.diary);
  var showMore = store.diary.isNotEmpty;

  final saved = await showNexusSheet<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('10秒チェックイン', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('気分、エネルギー、いましたこと', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              const Text('気分', style: TextStyle(fontWeight: FontWeight.w600)),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    Expanded(
                      child: IconButton(
                        onPressed: () => setSheet(() => mood = i),
                        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                        icon: Icon(
                          i <= mood ? Icons.sentiment_satisfied_alt : Icons.sentiment_neutral,
                          color: i <= mood ? NexusColors.green : NexusColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
              const Text('エネルギー', style: TextStyle(fontWeight: FontWeight.w600)),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    Expanded(
                      child: IconButton(
                        onPressed: () => setSheet(() => energy = i),
                        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                        icon: Icon(
                          Icons.bolt_rounded,
                          color: i <= energy ? NexusColors.green : NexusColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in kLifeActivityTags)
                    FilterChip(
                      label: Text(tag),
                      selected: tags.contains(tag),
                      onSelected: (v) => setSheet(() {
                        if (v) {
                          tags.add(tag);
                        } else {
                          tags.remove(tag);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (!showMore)
                TextButton(
                  onPressed: () => setSheet(() => showMore = true),
                  child: const Text('詳細を追加'),
                )
              else
                TextField(
                  controller: diary,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'ひとこと（任意）'),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('今日を記録'),
                ),
              ),
            ],
          );
        },
      );
    },
  );
  if (saved == true) {
    store.setCheckIn(mood: mood, energy: energy, tags: tags, diary: diary.text.trim());
    if (context.mounted) showStoreToast(context, store);
  }
  diary.dispose();
}
