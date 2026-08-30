import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/platform_partner.dart';
import '../models/platform_saas_metrics.dart';
import '../models/platform_tenant_feature_override.dart';
import '../models/platform_tenant_summary.dart';
import '../models/tenant_subscription_history_entry.dart';

class PlatformService {
  const PlatformService();

  Future<String?> getMyPlatformRole() async {
    final response = await Supabase.instance.client.rpc('get_my_platform_role');
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
      params: {'p_tenant_id': tenantId, 'p_reason': reason},
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

  Future<List<TenantSubscriptionHistoryEntry>> getTenantSubscriptionHistory(
    String tenantId,
  ) async {
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

  Future<PlatformSaasMetrics> getSaasMetrics() async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_saas_metrics',
    );
    return PlatformSaasMetrics.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<List<PlatformTenantFeatureOverride>> getTenantFeatureOverrides(
    String tenantId,
  ) async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_tenant_feature_overrides',
      params: {'p_tenant_id': tenantId},
    );
    return (response as List)
        .map(
          (item) => PlatformTenantFeatureOverride.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> setTenantFeatureOverride({
    required String tenantId,
    required String featureKey,
    required bool enabled,
    int? limitValue,
    required String reason,
    DateTime? endsAt,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_set_tenant_feature_override',
      params: {
        'p_tenant_id': tenantId,
        'p_feature_key': featureKey,
        'p_enabled': enabled,
        'p_limit_value': limitValue,
        'p_reason': reason,
        'p_ends_at': endsAt?.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> deleteTenantFeatureOverride(String overrideId) async {
    await Supabase.instance.client.rpc(
      'platform_delete_tenant_feature_override',
      params: {'p_override_id': overrideId},
    );
  }

  Future<PlatformPartnersSummary> getPartnersSummary() async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_partners_summary',
    );
    return PlatformPartnersSummary.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<List<PlatformPartner>> listPartners() async {
    final response = await Supabase.instance.client.rpc(
      'platform_list_partners',
    );
    return (response as List)
        .map(
          (item) =>
              PlatformPartner.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<String> createPartner({
    required String fullName,
    required String referralCode,
    required String payoutChannel,
    required String payoutAccount,
    String? documentId,
    String? phone,
    String? whatsapp,
    String? email,
    String commissionType = 'percentage',
    double commissionValue = 15.0,
    String commissionDuration = 'first_payment_only',
    int? durationMonths,
    String? notes,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'platform_create_partner',
      params: {
        'p_full_name': fullName,
        'p_referral_code': referralCode,
        'p_payout_channel': payoutChannel,
        'p_payout_account': payoutAccount,
        'p_document_id': documentId,
        'p_phone': phone,
        'p_whatsapp': whatsapp,
        'p_email': email,
        'p_commission_type': commissionType,
        'p_commission_value': commissionValue,
        'p_commission_duration': commissionDuration,
        'p_duration_months': durationMonths,
        'p_notes': notes,
      },
    );
    final rows = response as List;
    return Map<String, dynamic>.from(
      rows.first as Map,
    )['partner_id'].toString();
  }

  Future<void> updatePartner({
    required String partnerId,
    required String fullName,
    String? documentId,
    String? phone,
    String? whatsapp,
    String? email,
    required String payoutChannel,
    required String payoutAccount,
    required String commissionType,
    required double commissionValue,
    required String commissionDuration,
    int? durationMonths,
    required bool active,
    String? notes,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_update_partner',
      params: {
        'p_partner_id': partnerId,
        'p_full_name': fullName,
        'p_document_id': documentId,
        'p_phone': phone,
        'p_whatsapp': whatsapp,
        'p_email': email,
        'p_payout_channel': payoutChannel,
        'p_payout_account': payoutAccount,
        'p_commission_type': commissionType,
        'p_commission_value': commissionValue,
        'p_commission_duration': commissionDuration,
        'p_duration_months': durationMonths,
        'p_active': active,
        'p_notes': notes,
      },
    );
  }

  Future<PlatformPartnerDetail> getPartnerDetail(String partnerId) async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_partner_detail',
      params: {'p_partner_id': partnerId},
    );
    return PlatformPartnerDetail.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<void> setTenantPartner({
    required String tenantId,
    String? partnerId,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_set_tenant_partner',
      params: {'p_tenant_id': tenantId, 'p_partner_id': partnerId},
    );
  }

  Future<PlatformPartnerSettlementResult> settlePartnerCommissions({
    required String partnerId,
    required String payoutMethod,
    String? payoutReference,
    String? notes,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'platform_settle_partner_commissions',
      params: {
        'p_partner_id': partnerId,
        'p_payout_method': payoutMethod,
        'p_payout_reference': payoutReference,
        'p_notes': notes,
      },
    );
    final rows = response as List;
    return PlatformPartnerSettlementResult.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }
}
