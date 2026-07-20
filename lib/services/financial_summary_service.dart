import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/financial_summary.dart';

class FinancialSummaryService {
  const FinancialSummaryService({required this.branchId});

  final String? branchId;

  Future<FinancialSummary> getFinancialSummary() async {
    final response = await Supabase.instance.client
        .rpc(
          branchId == null
              ? 'get_financial_summary_v2'
              : 'get_branch_financial_summary_v2',
          params: {if (branchId != null) 'p_branch_id': branchId},
        )
        .single();

    return FinancialSummary.fromMap(Map<String, dynamic>.from(response as Map));
  }
}
