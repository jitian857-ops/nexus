import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../cloud/cloud_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../core/format.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_bits.dart';

class MailboxPage extends StatefulWidget {
  const MailboxPage({super.key});

  @override
  State<MailboxPage> createState() => _MailboxPageState();
}

class _MailboxPageState extends State<MailboxPage> {
  late Future<List<MailItem>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = CloudScope.of(context).listMail();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    return Scaffold(
      backgroundColor: NexusColors.background,
      body: PageScaffold(
        child: FutureBuilder<List<MailItem>>(
          future: _future,
          builder: (context, snap) {
            final items = snap.data ?? const <MailItem>[];
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
                      child: Text('メールボックス', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                if (snap.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('メールはまだありません', style: TextStyle(color: NexusColors.textMuted)),
                  )
                else
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () async {
                          await cloud.markMailRead(item.id);
                          setState(() => _future = cloud.listMail());
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (!item.read)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: NexusColors.cyan,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(item.body, style: TextStyle(color: NexusColors.textSecondary, height: 1.4)),
                              const SizedBox(height: 6),
                              Text(jpDate(item.at), style: TextStyle(color: NexusColors.textMuted, fontSize: 11)),
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
