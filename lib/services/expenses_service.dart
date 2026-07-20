import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense_summary.dart';

class ExpensesService {
  const ExpensesService({required this.branchId});

  final String? branchId;

  Future<List<ExpenseSummary>> getExpensesSummary() async {
    final response = await Supabase.instance.client.rpc(
      branchId == null ? 'get_expenses_summary' : 'get_expenses_summary_v2',
      params: {if (branchId != null) 'p_branch_id': branchId},
    );

    return response
        .map<ExpenseSummary>(
          (item) => ExpenseSummary.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
