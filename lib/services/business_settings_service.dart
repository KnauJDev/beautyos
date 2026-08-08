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

  /// Cambia el tema de marca blanca del negocio (D-093, D-109).
  ///
  /// [brandColorHex] solo se manda con `personalizado`; en los cinco temas
  /// predefinidos la base de datos lo descarta a proposito, para no revivir un
  /// color viejo si el negocio vuelve al tema personalizado mas adelante.
  Future<void> updateTenantTheme(
    String themeKey, {
    String? brandColorHex,
  }) async {
    await Supabase.instance.client.rpc(
      'update_tenant_theme',
      params: {'p_theme_key': themeKey, 'p_brand_color': brandColorHex},
    );
  }

  Future<void> updateTenantCoverPhoto(String coverPhotoUrl) async {
    await Supabase.instance.client.rpc(
      'update_tenant_cover_photo',
      params: {'p_cover_photo_url': coverPhotoUrl},
    );
  }
}
