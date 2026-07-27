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
  }) async {
    await Supabase.instance.client.rpc(
      'create_stylist_time_off',
      params: {
        'p_branch_id': branchId,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_reason': reason,
      },
    );
  }

  Future<void> cancelTimeOff(String timeOffId) async {
    await Supabase.instance.client.rpc(
      'cancel_stylist_time_off',
      params: {'p_branch_id': branchId, 'p_time_off_id': timeOffId},
    );
  }
}
