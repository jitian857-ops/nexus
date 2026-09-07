import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus/billing/billing_catalog.dart';
import 'package:nexus/billing/billing_store.dart';
import 'package:nexus/data/app_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final memory = <String, Map<String, dynamic>>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    memory.clear();
    BillingStore.debugLoad = (uid) async => memory[uid];
    BillingStore.debugSave = (uid, bundle) async {
      memory[uid] = bundle;
    };
  });

  tearDown(() {
    BillingStore.debugLoad = null;
    BillingStore.debugSave = null;
  });

  test('指定価格と年額割引がカタログどおり', () {
    expect(BillingCatalog.productionPurchasesEnabled, isFalse);
    expect(BillingCatalog.monthlyYen(PlanId.standard), 500);
    expect(BillingCatalog.monthlyYen(PlanId.pro), 800);
    expect(BillingCatalog.yearlyYen(PlanId.standard), 3900);
    expect(BillingCatalog.yearlyYen(PlanId.pro), 4800);
  });

  test('購入・復元・保留・取消・失効・返金はUID別に分かれ、記録削除は止まらない', () async {
    final a = await BillingStore.testPurchase(
      'uid-a',
      plan: PlanId.standard,
      period: BillingPeriod.monthly,
    );
    expect(a.isPaidActive, isTrue);
    expect(a.productId, BillingCatalog.standardMonthlyProductId);
    expect((await BillingStore.load('uid-b')).isPaidActive, isFalse);

    final pending = await BillingStore.testPending(
      'uid-a',
      plan: PlanId.pro,
      period: BillingPeriod.yearly,
    );
    expect(pending.status, EntitlementStatus.pending);
    expect(pending.plan, PlanId.pro);

    final restored = await BillingStore.restore('uid-a');
    expect(restored.status, EntitlementStatus.active);

    expect((await BillingStore.testCancel('uid-a')).status, EntitlementStatus.cancelled);
    expect((await BillingStore.testExpire('uid-a')).status, EntitlementStatus.expired);

    final refunded = await BillingStore.testRefund('uid-a');
    expect(refunded.status, EntitlementStatus.refunded);
    expect(refunded.plan, PlanId.free);

    final store = AppStore.seed();
    store.addSchedule(title: '予定', startAt: DateTime(2026, 9, 8, 18));
    store.deleteSchedule(store.schedules.single.id);
    expect(store.schedules, isEmpty);
  });
}
