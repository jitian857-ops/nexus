import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../billing/billing_catalog.dart';
import '../../billing/billing_store.dart';
import '../../cloud/nexus_cloud.dart';
import '../../core/format.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_bits.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  BillingEntitlement _entitlement = const BillingEntitlement();
  var _loading = true;

  String get _uid => CloudScope.of(context).uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final next = await BillingStore.load(_uid);
    if (!mounted) return;
    setState(() {
      _entitlement = next;
      _loading = false;
    });
  }

  Future<void> _run(Future<BillingEntitlement> Function() task) async {
    setState(() => _loading = true);
    try {
      final next = await task();
      if (!mounted) return;
      setState(() {
        _entitlement = next;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNexusToast(context, '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(_entitlement);
    return Scaffold(
      backgroundColor: NexusColors.background,
      appBar: AppBar(
        title: const Text('NEXUS+'),
        backgroundColor: NexusColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          GlassCard(
            glowColor: NexusColors.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('プラン', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'いまの権利: ${BillingCatalog.planLabel(_entitlement.plan)}（$status）',
                  style: TextStyle(color: NexusColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  '記録の閲覧・削除と、購入の復元は課金の状態に関係なく使えます。定期購入の解約とアカウント削除は別です。',
                  style: TextStyle(color: NexusColors.textMuted, height: 1.4, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _PlanCard(
            plan: PlanId.standard,
            blurb: '月額 ${yen(BillingCatalog.standardMonthlyYen)}。年額は35%オフの ${yen(BillingCatalog.yearlyYen(PlanId.standard))}。',
            selected: _entitlement.plan == PlanId.standard && _entitlement.isPaidActive,
          ),
          const SizedBox(height: 10),
          _PlanCard(
            plan: PlanId.pro,
            blurb: '月額 ${yen(BillingCatalog.proMonthlyYen)}。年額は50%オフの ${yen(BillingCatalog.yearlyYen(PlanId.pro))}。',
            selected: _entitlement.plan == PlanId.pro && _entitlement.isPaidActive,
          ),
          const SizedBox(height: 16),
          Text(
            BillingCatalog.productionPurchasesEnabled
                ? 'ストアの商品情報を確認してから購入できます。'
                : '本番の購入・ストア申請はまだ行いません。価格は表示のみです。',
            style: TextStyle(color: NexusColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading
                ? null
                : () => _run(() async {
                      final restored = await BillingStore.restore(_uid);
                      if (context.mounted) {
                        showNexusToast(
                          context,
                          restored.isPaidActive ? '権利を復元しました' : '復元できる購入はありません',
                        );
                      }
                      return restored;
                    }),
            child: const Text('購入を復元'),
          ),
          if (kDebugMode || !BillingCatalog.productionPurchasesEnabled) ...[
            const SizedBox(height: 24),
            Text('テスト用の権利', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => _run(
                            () => BillingStore.testPurchase(
                              _uid,
                              plan: PlanId.standard,
                              period: BillingPeriod.monthly,
                            ),
                          ),
                  child: const Text('Standard 月額'),
                ),
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => _run(
                            () => BillingStore.testPurchase(
                              _uid,
                              plan: PlanId.pro,
                              period: BillingPeriod.yearly,
                            ),
                          ),
                  child: const Text('Pro 年額'),
                ),
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => _run(
                            () => BillingStore.testPending(
                              _uid,
                              plan: PlanId.standard,
                              period: BillingPeriod.monthly,
                            ),
                          ),
                  child: const Text('保留'),
                ),
                OutlinedButton(
                  onPressed: _loading ? null : () => _run(() => BillingStore.testCancel(_uid)),
                  child: const Text('取消'),
                ),
                OutlinedButton(
                  onPressed: _loading ? null : () => _run(() => BillingStore.testExpire(_uid)),
                  child: const Text('失効'),
                ),
                OutlinedButton(
                  onPressed: _loading ? null : () => _run(() => BillingStore.testRefund(_uid)),
                  child: const Text('返金'),
                ),
                OutlinedButton(
                  onPressed: _loading ? null : () => _run(() => BillingStore.clear(_uid)),
                  child: const Text('無料に戻す'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'テスト権利は端末のUID別に保存します。既存の学習・お金・予定の閲覧と削除は止めません。',
              style: TextStyle(color: NexusColors.textMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(BillingEntitlement e) {
    return switch (e.status) {
      EntitlementStatus.none => '未購入',
      EntitlementStatus.pending => '保留',
      EntitlementStatus.active => '有効',
      EntitlementStatus.cancelled => '取消',
      EntitlementStatus.expired => '失効',
      EntitlementStatus.refunded => '返金',
    };
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.blurb,
    required this.selected,
  });

  final PlanId plan;
  final String blurb;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: selected ? NexusColors.cyan : null,
      borderColor: selected ? NexusColors.cyan : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(BillingCatalog.planLabel(plan), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(blurb, style: TextStyle(color: NexusColors.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}
