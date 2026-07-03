import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stylist_service_summary.dart';

class StylistServicesService {
  const StylistServicesService();

  Future<List<StylistServiceSummary>> getStylistServicesSummary() async {
    final response = await Supabase.instance.client
        .rpc('get_stylist_services_summary');

    return response
        .map<StylistServiceSummary>(
          (item) => StylistServiceSummary.fromMap(item),
        )
        .toList();
  }
}
