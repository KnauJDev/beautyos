import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/commission_summary.dart';
import '../models/daily_close_summary.dart';

class DailyCloseService {
  const DailyCloseService({required this.branchId});

  final String branchId;

  Future<DailyCloseSummary> getDailyClose(DateTime businessDate) async {
    final response = await Supabase.instance.client
        .rpc(
          'get_daily_close_v2',
          params: {
            'p_branch_id': branchId,
            'p_business_date': _dateParameter(businessDate),
          },
        )
        .single();

    return DailyCloseSummary.fromMap(Map<String, dynamic>.from(response));
  }

  Future<List<CommissionSummary>> getCommissionSummary(
    DateTime businessDate,
  ) async {
    final response = await Supabase.instance.client.rpc(
      'get_commission_summary_v2',
      params: {
        'p_branch_id': branchId,
        'p_business_date': _dateParameter(businessDate),
      },
    );

    return response
        .map<CommissionSummary>(
          (item) =>
              CommissionSummary.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  String _dateParameter(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
