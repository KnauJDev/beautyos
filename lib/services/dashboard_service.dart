import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_metrics.dart';

class DashboardService {
  const DashboardService({required this.branchId});

  final String branchId;

  Future<DashboardMetrics> getMetrics() async {
    final response = await Supabase.instance.client
        .rpc('get_dashboard_metrics_v2', params: {'p_branch_id': branchId})
        .single();

    return DashboardMetrics.fromMap(Map<String, dynamic>.from(response));
  }
}
