import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stylist_time_off.dart';

class StylistTimeOffService {
  const StylistTimeOffService({required this.branchId});

  final String branchId;

  Future<List<StylistTimeOff>> getMyTimeOff() async {
    final response = await Supabase.instance.client.rpc(
      'get_my_stylist_time_off',
      params: {'p_branch_id': branchId},
    );

    final rows = response as List<dynamic>;

    return rows
        .map(
          (row) => StylistTimeOff.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> createTimeOff({
    required DateTime startsAt,
    required DateTime endsAt,
    String? reason,
    String? repeatFrequency,
    DateTime? repeatUntil,
  }) async {
    await Supabase.instance.client.rpc(
      'create_stylist_time_off',
      params: {
        'p_branch_id': branchId,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_reason': reason,
        'p_repeat_frequency': repeatFrequency,
        'p_repeat_until': repeatUntil == null
            ? null
            : '${repeatUntil.year.toString().padLeft(4, '0')}-'
                  '${repeatUntil.month.toString().padLeft(2, '0')}-'
                  '${repeatUntil.day.toString().padLeft(2, '0')}',
      },
    );
  }

  Future<void> cancelTimeOff(String timeOffId) async {
    await Supabase.instance.client.rpc(
      'cancel_stylist_time_off',
      params: {'p_branch_id': branchId, 'p_time_off_id': timeOffId},
    );
  }

  Future<void> cancelTimeOffSeries(String recurrenceGroupId) async {
    await Supabase.instance.client.rpc(
      'cancel_stylist_time_off_series',
      params: {
        'p_branch_id': branchId,
        'p_recurrence_group_id': recurrenceGroupId,
      },
    );
  }
}
