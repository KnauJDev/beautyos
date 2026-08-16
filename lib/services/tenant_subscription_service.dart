import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tenant_subscription_status.dart';

class TenantSubscriptionService {
  const TenantSubscriptionService();

  Future<TenantSubscriptionStatus?> getMyTenantSubscriptionStatus() async {
    final response = await Supabase.instance.client.rpc(
      'get_my_tenant_subscription_status',
    );

    if (response == null) {
      return null;
    }

    if (response is List) {
      if (response.isEmpty) {
        return null;
      }
      final first = response.first;
      if (first is Map) {
        return TenantSubscriptionStatus.fromMap(
          Map<String, dynamic>.from(first),
        );
      }
    }

    if (response is Map) {
      return TenantSubscriptionStatus.fromMap(
        Map<String, dynamic>.from(response),
      );
    }

    return null;
  }

  /// Alias compatible con el banner de prueba existente (_TrialBanner).
  Future<TenantSubscriptionStatus?> getMySubscription() async {
    return getMyTenantSubscriptionStatus();
  }
}
