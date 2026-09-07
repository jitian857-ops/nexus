enum PlanId { free, standard, pro }

enum BillingPeriod { monthly, yearly }

enum EntitlementStatus { none, pending, active, cancelled, expired, refunded }

/// 価格は指定どおり。未確定の特典やストア商品は売らない。
class BillingCatalog {
  BillingCatalog._();

  /// 本番の IAP / ストア課金は、販売対象と検証先が決まるまで無効。
  static const productionPurchasesEnabled = false;

  static const standardMonthlyYen = 500;
  static const proMonthlyYen = 800;
  static const standardYearlyOffRate = 0.35;
  static const proYearlyOffRate = 0.50;

  static const standardMonthlyProductId = 'nexus.standard.monthly';
  static const standardYearlyProductId = 'nexus.standard.yearly';
  static const proMonthlyProductId = 'nexus.pro.monthly';
  static const proYearlyProductId = 'nexus.pro.yearly';

  static int yearlyYen(PlanId plan) {
    switch (plan) {
      case PlanId.standard:
        return (standardMonthlyYen * 12 * (1 - standardYearlyOffRate)).round();
      case PlanId.pro:
        return (proMonthlyYen * 12 * (1 - proYearlyOffRate)).round();
      case PlanId.free:
        return 0;
    }
  }

  static int monthlyYen(PlanId plan) {
    switch (plan) {
      case PlanId.standard:
        return standardMonthlyYen;
      case PlanId.pro:
        return proMonthlyYen;
      case PlanId.free:
        return 0;
    }
  }

  static String productId(PlanId plan, BillingPeriod period) {
    return switch ((plan, period)) {
      (PlanId.standard, BillingPeriod.monthly) => standardMonthlyProductId,
      (PlanId.standard, BillingPeriod.yearly) => standardYearlyProductId,
      (PlanId.pro, BillingPeriod.monthly) => proMonthlyProductId,
      (PlanId.pro, BillingPeriod.yearly) => proYearlyProductId,
      _ => '',
    };
  }

  static String planLabel(PlanId plan) {
    return switch (plan) {
      PlanId.free => '無料',
      PlanId.standard => 'Standard',
      PlanId.pro => 'Pro',
    };
  }

  static String periodLabel(BillingPeriod period) {
    return period == BillingPeriod.yearly ? '年額' : '月額';
  }
}

class BillingEntitlement {
  const BillingEntitlement({
    this.plan = PlanId.free,
    this.period,
    this.status = EntitlementStatus.none,
    this.productId = '',
    this.updatedAt,
    this.testOnly = true,
  });

  final PlanId plan;
  final BillingPeriod? period;
  final EntitlementStatus status;
  final String productId;
  final DateTime? updatedAt;
  final bool testOnly;

  bool get isPaidActive =>
      (plan == PlanId.standard || plan == PlanId.pro) &&
      status == EntitlementStatus.active;

  BillingEntitlement copyWith({
    PlanId? plan,
    BillingPeriod? period,
    bool clearPeriod = false,
    EntitlementStatus? status,
    String? productId,
    DateTime? updatedAt,
    bool? testOnly,
  }) {
    return BillingEntitlement(
      plan: plan ?? this.plan,
      period: clearPeriod ? null : (period ?? this.period),
      status: status ?? this.status,
      productId: productId ?? this.productId,
      updatedAt: updatedAt ?? this.updatedAt,
      testOnly: testOnly ?? this.testOnly,
    );
  }

  Map<String, dynamic> toJson() => {
        'plan': plan.name,
        'period': period?.name,
        'status': status.name,
        'productId': productId,
        'updatedAt': updatedAt?.toIso8601String(),
        'testOnly': testOnly,
      };

  factory BillingEntitlement.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const BillingEntitlement();
    return BillingEntitlement(
      plan: PlanId.values.firstWhere(
        (v) => v.name == json['plan'],
        orElse: () => PlanId.free,
      ),
      period: BillingPeriod.values.where((v) => v.name == json['period']).firstOrNull,
      status: EntitlementStatus.values.firstWhere(
        (v) => v.name == json['status'],
        orElse: () => EntitlementStatus.none,
      ),
      productId: json['productId'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      testOnly: json['testOnly'] as bool? ?? true,
    );
  }
}
