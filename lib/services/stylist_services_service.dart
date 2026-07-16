import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stylist_service_option.dart';
import '../models/stylist_service_summary.dart';

class StylistServicesService {
  const StylistServicesService();

  Future<List<StylistServiceSummary>> getStylistServicesSummary() async {
    final response = await Supabase.instance.client.rpc(
      'get_stylist_services_summary',
    );

    return response
        .map<StylistServiceSummary>(
          (item) => StylistServiceSummary.fromMap(item),
        )
        .toList();
  }

  Future<List<StylistServiceOption>> getStylistServiceOptions(
    String stylistId,
  ) async {
    final response = await Supabase.instance.client.rpc(
      'get_stylist_service_options',
      params: {'p_stylist_id': stylistId},
    );

    return response
        .map<StylistServiceOption>(
          (item) => StylistServiceOption.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<StylistServiceOption>> setStylistServices({
    required String stylistId,
    required List<String> serviceIds,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'set_stylist_services',
      params: {'p_stylist_id': stylistId, 'p_service_ids': serviceIds},
    );

    return response
        .map<StylistServiceOption>(
          (item) => StylistServiceOption.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
