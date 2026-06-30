import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_metrics.dart';

class DashboardService {
  const DashboardService();

  Future<DashboardMetrics> getMetrics() async {
    final response = await Supabase.instance.client
        .rpc('get_dashboard_metrics')
        .single();

    return DashboardMetrics.fromMap(Map<String, dynamic>.from(response));
  }
}
