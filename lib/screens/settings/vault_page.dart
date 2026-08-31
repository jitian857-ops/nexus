import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../cloud/cloud_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_bits.dart';

class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  late Future<List<VaultRecord>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = CloudScope.of(context).listVault();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    final store = AppScope.of(context);
    return Scaffold(
      backgroundColor: NexusColors.background,
      body: PageScaffold(
        child: FutureBuilder<List<VaultRecord>>(
          future: _future,
          builder: (context, snap) {
            final items = snap.data ?? const <VaultRecord>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: NexusColors.text),
                    ),
                    const Expanded(
                      child: Text('保管庫', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                Text(
                  'ここへ収めたデータは、アプリの画面からは書き換えも削除もできません。',
                  style: TextStyle(color: NexusColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    await cloud.sealVault('手動保管', store.toCloudMap());
                    if (!context.mounted) return;
                    setState(() => _future = cloud.listVault());
                    showNexusToast(context, '保管庫へ収めました');
                  },
                  child: const Text('今のデータを保管する'),
                ),
                const SizedBox(height: 16),
                if (snap.connectionState != ConnectionState.done)
                  const Center(child: CircularProgressIndicator())
                else if (items.isEmpty)
                  Text('保管はまだありません', style: TextStyle(color: NexusColors.textMuted))
                else
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () async {
                          final full = await cloud.readVault(item.id);
                          if (!context.mounted || full == null) return;
                          await showNexusSheet<void>(
                            context: context,
                            builder: (_) => _VaultDetail(record: full),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: GlassCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.reason, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(jpDate(item.at), style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text('${item.bytes} B', style: TextStyle(color: NexusColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VaultDetail extends StatelessWidget {
  const _VaultDetail({required this.record});

  final VaultRecord record;

  @override
  Widget build(BuildContext context) {
    final data = record.data ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('保管の内容', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(record.reason, style: TextStyle(color: NexusColors.textSecondary)),
        Text(jpDate(record.at), style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        Text('名前  ${data['userName'] ?? '—'}'),
        Text('職業  ${data['occupation'] ?? '—'}'),
        Text('教科  ${((data['subjects'] as List?) ?? const []).length}'),
        Text('学習  ${((data['sessions'] as List?) ?? const []).length}'),
        Text('収入  ${((data['incomes'] as List?) ?? const []).length}'),
        const SizedBox(height: 8),
        Text('この画面から内容を直したり消したりはできません。', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
      ],
    );
  }
}
