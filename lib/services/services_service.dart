import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/beauty_service.dart';

class ServicesService {
  const ServicesService();

  Future<List<BeautyService>> getActiveVisibleServices() async {
    final response = await Supabase.instance.client
        .from('services')
        .select('id, name, category, duration_minutes, price')
        .eq('active', true)
        .eq('visible_to_customer', true)
        .order('name');

    return response
        .map<BeautyService>((item) => BeautyService.fromMap(item))
        .toList();
  }

  Future<void> createService({
    required String branchId,
    required String name,
    required String category,
    required int durationMinutes,
    required num price,
    bool visibleToCustomer = true,
  }) async {
    await Supabase.instance.client.rpc(
      'create_service',
      params: {
        'p_branch_id': branchId,
        'p_name': name,
        'p_category': category,
        'p_duration_minutes': durationMinutes,
        'p_price': price,
        'p_visible_to_customer': visibleToCustomer,
      },
    );
  }
}
