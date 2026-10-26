import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../domain/report_builder.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_bits.dart';

class ReportVaultPage extends StatelessWidget {
  const ReportVaultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final day = store.focusedDate;
    final prev = DateTime(day.year, day.month - 1, 1);
    final thisMinutes = store.sessions
        .where((s) => s.at.year == day.year && s.at.month == day.month)
        .fold<int>(0, (sum, s) => sum + s.minutes);
    final prevMinutes = store.sessions
        .where((s) => s.at.year == prev.year && s.at.month == prev.month)
        .fold<int>(0, (sum, s) => sum + s.minutes);

    return Scaffold(
      backgroundColor: NexusColors.background,
      appBar: AppBar(title: Text('レポート保管庫')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Study / Life / Money の振り返り。AIは使いません。', style: TextStyle(color: NexusColors.textSecondary)),
          const SizedBox(height: 12),
          GlassCard(
            fill: NexusColors.sky,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${jpMonth(day)} と前月', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _Compare(label: '学習', now: '${(thisMinutes / 60).toStringAsFixed(1)}h', then: '${(prevMinutes / 60).toStringAsFixed(1)}h'),
                _Compare(label: '収入', now: yen(store.incomeForMonth(day)), then: yen(store.incomeForMonth(prev))),
                _Compare(label: '未振り分け', now: yen(store.unallocatedForMonth(day)), then: yen(store.unallocatedForMonth(prev))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _create(context, store, weekly: true),
            child: const Text('今週のレポートを作る'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _create(context, store, weekly: false),
            child: const Text('今月のレポートを作る'),
          ),
          const SizedBox(height: 16),
          if (store.reports.isEmpty)
            const EmptyHint(text: '保管されたレポートはまだありません', icon: Icons.insights_outlined)
          else
            for (final report in store.reports)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        jpDate(report.createdAt),
                        style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Text(report.body, style: const TextStyle(height: 1.45, fontSize: 13)),
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ReportPrintPage(report: report),
                              ),
                            ),
                            child: const Text('PDFプレビュー'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: report.body));
                              if (context.mounted) showNexusToast(context, 'レポートをコピーしました');
                            },
                            child: const Text('コピー'),
                          ),
                          TextButton(
                            onPressed: () {
                              store.deleteReport(report.id);
                              showStoreToast(context, store);
                            },
                            child: const Text('削除'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, AppStore store, {required bool weekly}) async {
    final day = store.focusedDate;
    final body = weekly ? ReportBuilder.weekly(store, day) : ReportBuilder.monthly(store, day);
    store.addStoredReport(
      kind: weekly ? 'weekly' : 'monthly',
      periodStart: weekly
          ? dateOnly(day).subtract(Duration(days: mondayIndex(day)))
          : DateTime(day.year, day.month, 1),
      title: weekly ? '週次 ${jpDate(day)}' : '月次 ${jpMonth(day)}',
      body: body,
    );
    if (context.mounted) showStoreToast(context, store);
  }
}

class _Compare extends StatelessWidget {
  const _Compare({required this.label, required this.now, required this.then});

  final String label;
  final String now;
  final String then;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 88, child: Text(label, style: TextStyle(color: NexusColors.textMuted))),
          Expanded(child: Text(now, style: const TextStyle(fontWeight: FontWeight.w800))),
          Text('前月 $then', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class ReportPrintPage extends StatelessWidget {
  const ReportPrintPage({super.key, required this.report});

  final StoredReport report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EE),
      appBar: AppBar(
        title: const Text('PDFプレビュー'),
        actions: [
          IconButton(
            tooltip: 'コピー',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report.body));
              if (context.mounted) showNexusToast(context, 'PDF用テキストをコピーしました');
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8)),
              ],
            ),
            child: ListView(
              children: [
                Text(report.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'NEXUS  •  ${jpDate(report.createdAt)}',
                  style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                ),
                const Divider(height: 28),
                Text(report.body, style: const TextStyle(height: 1.55, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
