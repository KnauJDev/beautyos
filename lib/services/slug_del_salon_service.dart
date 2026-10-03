import 'package:supabase_flutter/supabase_flutter.dart';

/// La dirección pública del salón (`tenants.slug`), para que la estilista
/// comparta `salonymas.com/<nombre-del-salon>` en vez del código largo de la
/// sede. Pedido del propietario el 03-oct, al ver el enlace en WhatsApp.
///
/// Se lee con la sesión de quien la pide: la política
/// `tenant_isolation_select` deja a cada miembro activo leer la fila de su
/// propio negocio, y la dirección no es secreta (es la de la página pública).
///
/// **Si no se puede leer devuelve `null` a propósito**, y la tarjeta comparte
/// el enlace de siempre (`?reservar=<sede>`), que funciona igual. Aquí fallar
/// en silencio no oculta nada: lo peor que pasa es un enlace menos bonito.
class SlugDelSalonService {
  const SlugDelSalonService();

  Future<String?> leer(String tenantId) async {
    try {
      final fila = await Supabase.instance.client
          .from('tenants')
          .select('slug')
          .eq('id', tenantId)
          .maybeSingle();
      final slug = fila?['slug']?.toString().trim();
      return (slug == null || slug.isEmpty) ? null : slug;
    } catch (_) {
      return null;
    }
  }
}
