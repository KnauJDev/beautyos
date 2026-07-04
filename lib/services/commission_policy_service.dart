import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/commission_policy.dart';

class CommissionPolicyService {
  const CommissionPolicyService();

  Future<CommissionPolicy> getCommissionPolicy() async {
    final response = await Supabase.instance.client
        .rpc('get_commission_policy')
        .single();

    return CommissionPolicy.fromMap(
      Map<String, dynamic>.from(response),
    );
  }
}
