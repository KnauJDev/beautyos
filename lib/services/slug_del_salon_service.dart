import 'package:supabase_flutter/supabase_flutter.dart';

/// La dirección pública del salón (`tenants.slug`), para que el enlace que se
/// comparte sea `salonymas.com/<nombre-del-salon>` y no el código largo de la
/// sede (D-313, 03-oct).
///
/// **Se pide con la función pública `public_get_salon_slug_by_branch`, a
/// partir de la sede.** La primera versión leía la tabla `tenants` con la
/// sesión de la estilista, contando con su política de seguridad; la lectura
/// del 03-oct mostró que esa política consulta `tenant_memberships`, que nadie
/// con sesión puede leer, y la consulta se negaba. La dirección no es secreta
/// (es la de la página pública del salón), así que una función pública es lo
/// correcto, y sirve con sesión y sin ella.
///
/// **Si no se puede leer devuelve `null` a propósito**, y la tarjeta comparte
/// el enlace de siempre (`?reservar=<sede>`), que funciona igual. Aquí fallar
/// en silencio no oculta nada: lo peor que pasa es un enlace menos bonito.
class SlugDelSalonService {
  const SlugDelSalonService();

  Future<String?> leer(String branchId) async {
    try {
      final respuesta = await Supabase.instance.client.rpc(
        'public_get_salon_slug_by_branch',
        params: {'p_branch_id': branchId},
      );
      final slug = respuesta?.toString().trim();
      return (slug == null || slug.isEmpty) ? null : slug;
    } catch (_) {
      return null;
    }
  }
}
