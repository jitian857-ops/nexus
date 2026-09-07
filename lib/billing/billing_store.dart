import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'billing_catalog.dart';

/// UID 別の権利。本番購入は [BillingCatalog.productionPurchasesEnabled] が false の間は動かない。
class BillingStore {
  BillingStore._();

  static const _prefix = 'nexus_billing_v1_';

  static Future<Map<String, dynamic>?> Function(String uid)? debugLoad;
  static Future<void> Function(String uid, Map<String, dynamic> bundle)? debugSave;

  static String keyFor(String uid) => '$_prefix$uid';

  static Future<BillingEntitlement> load(String uid) async {
    if (uid.isEmpty) return const BillingEntitlement();
    try {
      Map<String, dynamic>? data;
      if (debugLoad != null) {
        data = await debugLoad!(uid);
      } else {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(keyFor(uid));
        if (raw != null && raw.isNotEmpty) {
          data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        }
      }
      return BillingEntitlement.fromJson(data);
    } catch (_) {
      return const BillingEntitlement();
    }
  }

  static Future<void> _persist(String uid, BillingEntitlement entitlement) async {
    if (uid.isEmpty) return;
    final bundle = entitlement.toJson();
    if (debugSave != null) {
      await debugSave!(uid, bundle);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFor(uid), jsonEncode(bundle));
  }

  static Future<BillingEntitlement> _set(
    String uid,
    BillingEntitlement next,
  ) async {
    final entitlement = next.copyWith(updatedAt: DateTime.now());
    await _persist(uid, entitlement);
    return entitlement;
  }

  static Future<BillingEntitlement> restore(String uid) async {
    final current = await load(uid);
    if (current.plan == PlanId.free || current.status == EntitlementStatus.none) {
      return current;
    }
    if (current.status == EntitlementStatus.expired ||
        current.status == EntitlementStatus.refunded) {
      return current;
    }
    return _set(
      uid,
      current.copyWith(status: EntitlementStatus.active),
    );
  }

  /// テスト環境専用。本番フラグが落ちているときは購入APIへ進まない。
  static Future<BillingEntitlement> testPurchase(
    String uid, {
    required PlanId plan,
    required BillingPeriod period,
  }) async {
    if (plan == PlanId.free) return load(uid);
    if (BillingCatalog.productionPurchasesEnabled && !kDebugMode) {
      throw StateError('本番購入はまだ有効化していません');
    }
    return _set(
      uid,
      BillingEntitlement(
        plan: plan,
        period: period,
        status: EntitlementStatus.active,
        productId: BillingCatalog.productId(plan, period),
        testOnly: true,
      ),
    );
  }

  static Future<BillingEntitlement> testPending(
    String uid, {
    required PlanId plan,
    required BillingPeriod period,
  }) {
    return _set(
      uid,
      BillingEntitlement(
        plan: plan,
        period: period,
        status: EntitlementStatus.pending,
        productId: BillingCatalog.productId(plan, period),
        testOnly: true,
      ),
    );
  }

  static Future<BillingEntitlement> testCancel(String uid) async {
    final current = await load(uid);
    return _set(uid, current.copyWith(status: EntitlementStatus.cancelled));
  }

  static Future<BillingEntitlement> testExpire(String uid) async {
    final current = await load(uid);
    return _set(uid, current.copyWith(status: EntitlementStatus.expired));
  }

  static Future<BillingEntitlement> testRefund(String uid) async {
    final current = await load(uid);
    return _set(
      uid,
      current.copyWith(
        plan: PlanId.free,
        clearPeriod: true,
        status: EntitlementStatus.refunded,
        productId: '',
      ),
    );
  }

  static Future<BillingEntitlement> clear(String uid) {
    return _set(uid, const BillingEntitlement());
  }
}
