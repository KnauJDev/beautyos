import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/commission_policy.dart';
import '../models/stylist_commission_override.dart';
import 'monitoreo_service.dart';

class CommissionPolicyService {
  const CommissionPolicyService({required this.branchId});

  final String branchId;

  Future<CommissionPolicy> getCommissionPolicy() async {
    return MonitoreoService.capturar(
      () async {
        final response = await Supabase.instance.client
            .rpc('get_commission_policy')
            .single();

        return CommissionPolicy.fromMap(
          Map<String, dynamic>.from(response),
        );
      },
      motivo: 'Fallo al consultar get_commission_policy()',
    );
  }

  Future<List<StylistCommissionOverride>> getStylistCommissionOverrides(
    String stylistId,
  ) async {
    final response = await Supabase.instance.client.rpc(
      'get_stylist_commission_overrides',
      params: {'p_branch_id': branchId, 'p_stylist_id': stylistId},
    );

    return (response as List)
        .map(
          (item) => StylistCommissionOverride.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> setStylistServiceCommission({
    required String stylistId,
    required String serviceId,
    required String commissionType,
    required num commissionPercentage,
    required num fixedCommissionAmount,
  }) async {
    await Supabase.instance.client.rpc(
      'set_stylist_service_commission',
      params: {
        'p_branch_id': branchId,
        'p_stylist_id': stylistId,
        'p_service_id': serviceId,
        'p_commission_type': commissionType,
        'p_commission_percentage': commissionPercentage,
        'p_fixed_commission_amount': fixedCommissionAmount,
      },
    );
  }

  Future<void> removeStylistServiceCommissionOverride({
    required String stylistId,
    required String serviceId,
  }) async {
    await Supabase.instance.client.rpc(
      'remove_stylist_service_commission_override',
      params: {
        'p_branch_id': branchId,
        'p_stylist_id': stylistId,
        'p_service_id': serviceId,
      },
    );
  }

  Future<void> updateCommissionPolicy({
    required String commissionType,
    required num commissionPercentage,
    required num fixedCommissionAmount,
    required bool appliesAfterDiscount,
    String? notes,
  }) async {
    await Supabase.instance.client.rpc(
      'update_commission_policy',
      params: {
        'p_branch_id': branchId,
        'p_commission_type': commissionType,
        'p_commission_percentage': commissionPercentage,
        'p_fixed_commission_amount': fixedCommissionAmount,
        'p_applies_after_discount': appliesAfterDiscount,
        'p_notes': notes,
      },
    );
  }
}
