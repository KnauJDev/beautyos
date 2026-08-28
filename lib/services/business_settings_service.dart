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

  /// Autoservicio: el owner o admin del propio negocio actualiza el nombre
  /// del titular, tipo de negocio, teléfono, WhatsApp, Instagram, Facebook
  /// y la dirección física de la sede principal (D-166).
  Future<void> updateContactInfo({
    required String fullName,
    String? businessType,
    String? contactPhone,
    String? whatsapp,
    String? instagram,
    String? facebook,
    String? address,
  }) async {
    await Supabase.instance.client.rpc(
      'update_tenant_contact_info',
      params: {
        'p_full_name': fullName,
        'p_business_type': businessType,
        'p_contact_phone': contactPhone,
        'p_whatsapp': whatsapp,
        'p_instagram': instagram,
        'p_facebook': facebook,
        'p_address': address,
      },
    );
  }

  /// `true` si el slug está bien formado, no es una palabra reservada y
  /// nadie más lo tiene (D-164). No lo reserva -- solo consulta.
  Future<bool> checkSlugAvailability(String slug) async {
    final response = await Supabase.instance.client.rpc(
      'check_slug_availability',
      params: {'p_slug': slug},
    );
    return response as bool;
  }

  /// Cambia el enlace público del negocio propio. Solo owner o admin
  /// (D-164). Devuelve el slug normalizado que quedó guardado.
  Future<String> updateTenantSlug(String newSlug) async {
    final response = await Supabase.instance.client.rpc(
      'update_tenant_slug',
      params: {'p_new_slug': newSlug},
    );
    return response as String;
  }
}
