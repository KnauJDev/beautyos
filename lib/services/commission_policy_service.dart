import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/commission_policy.dart';

class CommissionPolicyService {
  const CommissionPolicyService({required this.branchId});

  final String branchId;

  Future<CommissionPolicy> getCommissionPolicy() async {
    final response = await Supabase.instance.client
        .rpc('get_commission_policy')
        .single();

    return CommissionPolicy.fromMap(
      Map<String, dynamic>.from(response),
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
