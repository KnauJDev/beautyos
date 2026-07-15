import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tenant_user.dart';

class TenantUsersService {
  const TenantUsersService();

  Future<List<TenantUser>> getTenantUsers() async {
    final response = await Supabase.instance.client.rpc('get_tenant_users');

    return response
        .map<TenantUser>(
          (item) => TenantUser.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<TenantUser> updateTenantUserAccess({
    required String profileId,
    required String role,
    required bool active,
  }) async {
    final response = await Supabase.instance.client
        .rpc(
          'update_tenant_user_access',
          params: {
            'p_profile_id': profileId,
            'p_role': role,
            'p_active': active,
          },
        )
        .single();

    return TenantUser.fromMap(Map<String, dynamic>.from(response));
  }
}
