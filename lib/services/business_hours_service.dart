import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business_hour.dart';

class BusinessHoursService {
  const BusinessHoursService();

  Future<List<BusinessHour>> getBusinessHours() async {
    final response = await Supabase.instance.client
        .rpc('get_business_hours');

    return response
        .map<BusinessHour>((item) => BusinessHour.fromMap(item))
        .toList();
  }
}
