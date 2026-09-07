import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_bits.dart';

class AppCustomizePage extends StatelessWidget {
  const AppCustomizePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final step = store.settings.reelMinuteStep;

    return Scaffold(
      backgroundColor: NexusColors.background,
      body: PageScaffold(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: NexusColors.text),
                ),
                const Expanded(
                  child: Text('アプリをカスタマイズ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('時間リールの刻み', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    '予定の開始・終了や、勉強時間を回すときの分の間隔です。',
                    style: TextStyle(color: NexusColors.textMuted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value in kReelMinuteSteps)
                        ChoiceChip(
                          label: Text('$value分'),
                          selected: step == value,
                          selectedColor: NexusColors.cyan.withValues(alpha: 0.22),
                          labelStyle: TextStyle(
                            color: step == value ? NexusColors.cyan : NexusColors.text,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => store.updateSettings(
                            store.settings.copyWith(reelMinuteStep: value),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Homeのウィジェット', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'Homeには今日の目標、今月の残高、今週の学習時間が出ます。',
                    style: TextStyle(color: NexusColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
