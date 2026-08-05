import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business_settings.dart';

class BusinessSettingsService {
  const BusinessSettingsService();

  Future<BusinessSettings> getBusinessSettings() async {
    final response = await Supabase.instance.client
        .rpc('get_business_settings')
        .single();

    return BusinessSettings.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> updateTenantLogo(String logoUrl) async {
    await Supabase.instance.client.rpc(
      'update_tenant_logo',
      params: {'p_logo_url': logoUrl},
    );
  }

  Future<void> updateTenantCoverPhoto(String coverPhotoUrl) async {
    await Supabase.instance.client.rpc(
      'update_tenant_cover_photo',
      params: {'p_cover_photo_url': coverPhotoUrl},
    );
  }
}
