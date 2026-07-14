import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/commission_summary.dart';
import '../models/daily_close_summary.dart';

class DailyCloseService {
  const DailyCloseService();

  Future<DailyCloseSummary> getDailyClose(DateTime businessDate) async {
    final start = DateTime(
      businessDate.year,
      businessDate.month,
      businessDate.day,
    );
    final end = start.add(const Duration(days: 1));

    final response = await Supabase.instance.client
        .rpc(
          'get_daily_close',
          params: {
            'p_business_date': _dateParameter(businessDate),
            'p_start_at': start.toUtc().toIso8601String(),
            'p_end_at': end.toUtc().toIso8601String(),
          },
        )
        .single();

    return DailyCloseSummary.fromMap(Map<String, dynamic>.from(response));
  }

  Future<List<CommissionSummary>> getCommissionSummary(
    DateTime businessDate,
  ) async {
    final start = DateTime(
      businessDate.year,
      businessDate.month,
      businessDate.day,
    );
    final end = start.add(const Duration(days: 1));

    final response = await Supabase.instance.client.rpc(
      'get_commission_summary',
      params: {
        'p_start_at': start.toUtc().toIso8601String(),
        'p_end_at': end.toUtc().toIso8601String(),
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
