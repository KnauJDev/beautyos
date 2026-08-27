import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/public_salon_profile.dart';

/// Llama a la RPC pública (rol "anon", sin sesión) que resuelve la página de
/// un negocio por su slug (D-098, D-164).
class PublicSalonService {
  const PublicSalonService();

  /// `null` si el slug no existe o el negocio no está activo.
  Future<PublicSalonProfile?> getSalonBySlug(String slug) async {
    final response = await Supabase.instance.client.rpc(
      'get_public_salon_by_slug',
      params: {'p_slug': slug},
    );

    final rows = response as List;
    if (rows.isEmpty) return null;

    return PublicSalonProfile.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }
}
