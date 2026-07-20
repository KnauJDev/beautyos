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
}
