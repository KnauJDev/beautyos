import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/financial_summary.dart';

class FinancialSummaryService {
  const FinancialSummaryService();

  Future<FinancialSummary> getFinancialSummary() async {
    final response = await Supabase.instance.client
        .rpc('get_financial_summary_v2')
        .single();

    return FinancialSummary.fromMap(Map<String, dynamic>.from(response as Map));
  }
}
