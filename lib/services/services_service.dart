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
}
