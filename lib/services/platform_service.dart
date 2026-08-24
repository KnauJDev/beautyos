import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/platform_tenant_summary.dart';
import '../models/tenant_subscription_history_entry.dart';

class PlatformService {
  const PlatformService();

  Future<String?> getMyPlatformRole() async {
    final response = await Supabase.instance.client.rpc(
      'get_my_platform_role',
    );
    return response as String?;
  }

  Future<List<PlatformTenantSummary>> listTenants() async {
    final response = await Supabase.instance.client.rpc(
      'platform_list_tenants',
    );

    return (response as List)
        .map(
          (item) => PlatformTenantSummary.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> approveTenant({
    required String tenantId,
    String planCode = 'profesional',
    bool isFounder = false,
    int? priceCop,
    double? discountPercent,
    DateTime? discountEndsAt,
    String? priceReason,
    int trialDays = 21,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_approve_tenant',
      params: {
        'p_tenant_id': tenantId,
        'p_plan_code': planCode,
        'p_is_founder': isFounder,
        'p_price_cop': priceCop,
        'p_discount_percent': discountPercent,
        'p_discount_ends_at': discountEndsAt?.toUtc().toIso8601String(),
        'p_price_reason': priceReason,
        'p_trial_days': trialDays,
      },
    );
  }

  Future<void> rejectTenant({
    required String tenantId,
    required String reason,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_reject_tenant',
      params: {
        'p_tenant_id': tenantId,
        'p_reason': reason,
      },
    );
  }

  Future<void> suspendTenant({
    required String tenantId,
    required String reason,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_suspend_tenant',
      params: {'p_tenant_id': tenantId, 'p_reason': reason},
    );
  }

  Future<void> reactivateTenant({
    required String tenantId,
    required String reason,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_reactivate_tenant',
      params: {'p_tenant_id': tenantId, 'p_reason': reason},
    );
  }

  Future<void> extendTrial({
    required String tenantId,
    required DateTime newTrialEndsAt,
    required String reason,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_extend_trial',
      params: {
        'p_tenant_id': tenantId,
        'p_new_trial_ends_at': newTrialEndsAt.toUtc().toIso8601String(),
        'p_reason': reason,
      },
    );
  }

  Future<void> updateTenantPricing({
    required String tenantId,
    required String planCode,
    required bool isFounder,
    int? priceCop,
    double? discountPercent,
    String? priceReason,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_update_tenant_pricing',
      params: {
        'p_tenant_id': tenantId,
        'p_plan_code': planCode,
        'p_is_founder': isFounder,
        'p_price_cop': priceCop,
        'p_discount_percent': discountPercent,
        'p_price_reason': priceReason,
      },
    );
  }

  Future<List<TenantSubscriptionHistoryEntry>> getTenantSubscriptionHistory(String tenantId) async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_tenant_subscription_history',
      params: {'p_tenant_id': tenantId},
    );
    return (response as List)
        .map(
          (item) => TenantSubscriptionHistoryEntry.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> updateTenantContact({
    required String tenantId,
    required String contactName,
    required String contactEmail,
    String? whatsapp,
    String? businessType,
    String? city,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_update_tenant_contact',
      params: {
        'p_tenant_id': tenantId,
        'p_contact_name': contactName,
        'p_contact_email': contactEmail,
        'p_whatsapp': whatsapp,
        'p_business_type': businessType,
        'p_city': city,
      },
    );
  }
}

