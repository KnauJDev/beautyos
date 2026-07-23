import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business_hour.dart';

class BusinessHoursService {
  const BusinessHoursService({required this.branchId});

  final String branchId;

  Future<List<BusinessHour>> getBusinessHours() async {
    final response = await Supabase.instance.client.rpc(
      'get_business_hours_v2',
      params: {'p_branch_id': branchId},
    );

    return response
        .map<BusinessHour>((item) => BusinessHour.fromMap(item))
        .toList();
  }

  Future<void> updateBusinessHours(List<BusinessHour> hours) async {
    await Supabase.instance.client.rpc(
      'update_business_hours',
      params: {
        'p_branch_id': branchId,
        'p_hours': hours
            .map(
              (hour) => {
                'day_of_week': hour.dayOfWeek,
                'opens_at': hour.opensAt,
                'closes_at': hour.closesAt,
                'is_open': hour.isOpen,
              },
            )
            .toList(),
      },
    );
  }
}
