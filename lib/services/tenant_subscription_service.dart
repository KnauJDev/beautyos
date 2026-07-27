import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tenant_subscription_status.dart';

class TenantSubscriptionService {
  const TenantSubscriptionService();

  Future<TenantSubscriptionStatus?> getMySubscription() async {
    final response = await Supabase.instance.client.rpc(
      'get_my_tenant_subscription',
    );

    final rows = response as List<dynamic>;

    if (rows.isEmpty) {
      return null;
    }

    return TenantSubscriptionStatus.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }
}
