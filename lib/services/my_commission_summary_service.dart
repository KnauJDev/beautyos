import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/my_commission_summary_item.dart';

class MyCommissionSummaryService {
  const MyCommissionSummaryService({required this.branchId});

  final String branchId;

  Future<List<MyCommissionSummaryItem>> getMySummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'get_my_commission_summary',
      params: {
        'p_branch_id': branchId,
        'p_start_date': _formatDate(startDate),
        'p_end_date': _formatDate(endDate),
      },
    );

    final rows = response as List<dynamic>;

    return rows
        .map(
          (row) => MyCommissionSummaryItem.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
