import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense_summary.dart';

class ExpensesService {
  const ExpensesService();

  Future<List<ExpenseSummary>> getExpensesSummary() async {
    final response = await Supabase.instance.client.rpc('get_expenses_summary');

    return response
        .map<ExpenseSummary>(
          (item) => ExpenseSummary.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
