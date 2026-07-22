import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/platform_tenant_summary.dart';

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
}
